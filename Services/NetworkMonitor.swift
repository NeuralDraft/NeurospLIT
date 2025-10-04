import Foundation
import Network
import Combine

// MARK: - Network Monitor
@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor", qos: .background)
    private var cancellables = Set<AnyCancellable>()
    
    @Published var isConnected = true
    @Published var isExpensive = false
    @Published var connectionType: ConnectionType = .unknown
    @Published var lastConnectionChange: Date?
    
    enum ConnectionType: String, CaseIterable {
        case wifi = "Wi-Fi"
        case cellular = "Cellular"
        case wired = "Wired"
        case loopback = "Loopback"
        case other = "Other"
        case unknown = "Unknown"
        
        var icon: String {
            switch self {
            case .wifi: return "wifi"
            case .cellular: return "antenna.radiowaves.left.and.right"
            case .wired: return "cable.connector"
            case .loopback: return "arrow.triangle.2.circlepath"
            case .other: return "network"
            case .unknown: return "questionmark.circle"
            }
        }
    }
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        monitor.cancel()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.updateConnectionStatus(path)
            }
        }
        monitor.start(queue: queue)
        
        AppLogger.info("Network monitoring started")
    }
    
    @MainActor
    private func updateConnectionStatus(_ path: NWPath) {
        let wasConnected = isConnected
        
        isConnected = path.status == .satisfied
        isExpensive = path.isExpensive
        connectionType = getConnectionType(from: path)
        lastConnectionChange = Date()
        
        if wasConnected != isConnected {
            AppLogger.info("Network status changed: \(isConnected ? "Connected" : "Disconnected") via \(connectionType.rawValue)")
            
            // Post notification for other parts of the app
            NotificationCenter.default.post(
                name: .networkStatusChanged,
                object: nil,
                userInfo: ["isConnected": isConnected]
            )
        }
    }
    
    private func getConnectionType(from path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .wired
        } else if path.usesInterfaceType(.loopback) {
            return .loopback
        } else if path.usesInterfaceType(.other) {
            return .other
        } else {
            return .unknown
        }
    }
    
    // MARK: - Public Methods
    
    func checkConnectivity() -> Bool {
        return isConnected
    }
    
    func requiresWiFi() -> Bool {
        return connectionType != .wifi && isExpensive
    }
    
    func waitForConnection() async -> Bool {
        if isConnected { return true }
        
        // Wait up to 10 seconds for connection
        for _ in 0..<20 {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            if isConnected { return true }
        }
        
        return false
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let networkStatusChanged = Notification.Name("networkStatusChanged")
}

// MARK: - Retry Policy
struct RetryPolicy {
    let maxAttempts: Int
    let initialDelay: TimeInterval
    let maxDelay: TimeInterval
    let multiplier: Double
    
    static let standard = RetryPolicy(
        maxAttempts: 3,
        initialDelay: 1.0,
        maxDelay: 30.0,
        multiplier: 2.0
    )
    
    static let aggressive = RetryPolicy(
        maxAttempts: 5,
        initialDelay: 0.5,
        maxDelay: 10.0,
        multiplier: 1.5
    )
    
    static let conservative = RetryPolicy(
        maxAttempts: 2,
        initialDelay: 2.0,
        maxDelay: 60.0,
        multiplier: 3.0
    )
    
    func delay(for attempt: Int) -> TimeInterval {
        guard attempt > 0 else { return 0 }
        
        let exponentialDelay = initialDelay * pow(multiplier, Double(attempt - 1))
        return min(exponentialDelay, maxDelay)
    }
}

// MARK: - Network Request Extension
extension URLSession {
    
    func dataWithRetry(
        from url: URL,
        policy: RetryPolicy = .standard
    ) async throws -> (Data, URLResponse) {
        var lastError: Error?
        
        for attempt in 1...policy.maxAttempts {
            // Check network connectivity before attempting
            if !NetworkMonitor.shared.isConnected {
                lastError = APIError.noInternetConnection
                
                // Wait for connection if not on last attempt
                if attempt < policy.maxAttempts {
                    _ = await NetworkMonitor.shared.waitForConnection()
                }
                continue
            }
            
            do {
                return try await data(from: url)
            } catch {
                lastError = error
                AppLogger.warning("Network request failed (attempt \(attempt)/\(policy.maxAttempts)): \(error)")
                
                // Don't retry on last attempt
                if attempt < policy.maxAttempts {
                    let delay = policy.delay(for: attempt)
                    AppLogger.debug("Retrying after \(delay) seconds...")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? APIError.unknown(NSError(domain: "NetworkError", code: -1))
    }
    
    func dataWithRetry(
        for request: URLRequest,
        policy: RetryPolicy = .standard
    ) async throws -> (Data, URLResponse) {
        var lastError: Error?
        
        for attempt in 1...policy.maxAttempts {
            // Check network connectivity before attempting
            if !NetworkMonitor.shared.isConnected {
                lastError = APIError.noInternetConnection
                
                // Wait for connection if not on last attempt
                if attempt < policy.maxAttempts {
                    _ = await NetworkMonitor.shared.waitForConnection()
                }
                continue
            }
            
            do {
                return try await data(for: request)
            } catch let error as URLError {
                // Handle specific URL errors
                switch error.code {
                case .notConnectedToInternet, .networkConnectionLost:
                    lastError = APIError.noInternetConnection
                case .timedOut:
                    lastError = APIError.requestTimeout
                case .cannotFindHost, .cannotConnectToHost:
                    lastError = APIError.invalidURL
                default:
                    lastError = error
                }
                
                AppLogger.warning("Network request failed (attempt \(attempt)/\(policy.maxAttempts)): \(error)")
                
                // Don't retry on last attempt or for certain errors
                if attempt < policy.maxAttempts && shouldRetry(error: error) {
                    let delay = policy.delay(for: attempt)
                    AppLogger.debug("Retrying after \(delay) seconds...")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    break
                }
            } catch {
                lastError = error
                AppLogger.warning("Network request failed (attempt \(attempt)/\(policy.maxAttempts)): \(error)")
                
                if attempt < policy.maxAttempts {
                    let delay = policy.delay(for: attempt)
                    AppLogger.debug("Retrying after \(delay) seconds...")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? APIError.unknown(NSError(domain: "NetworkError", code: -1))
    }
    
    private func shouldRetry(error: URLError) -> Bool {
        switch error.code {
        case .notConnectedToInternet,
             .networkConnectionLost,
             .timedOut,
             .cannotFindHost,
             .cannotConnectToHost,
             .dnsLookupFailed:
            return true
        default:
            return false
        }
    }
}
