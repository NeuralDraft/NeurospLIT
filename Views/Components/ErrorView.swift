import SwiftUI

// MARK: - Error View
struct ErrorView: View {
    let error: Error
    let retry: (() -> Void)?
    let dismiss: (() -> Void)?
    
    @State private var isExpanded = false
    @Environment(\.colorScheme) var colorScheme
    
    init(error: Error, retry: (() -> Void)? = nil, dismiss: (() -> Void)? = nil) {
        self.error = error
        self.retry = retry
        self.dismiss = dismiss
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Error Icon
            errorIcon
            
            // Error Title
            Text("Something went wrong")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            // Error Message
            Text(errorMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Detailed Error (Expandable)
            if isExpanded {
                detailedErrorView
            }
            
            // Action Buttons
            actionButtons
            
            // Toggle Details Button
            toggleDetailsButton
        }
        .padding()
        .background(backgroundView)
    }
    
    // MARK: - Components
    
    private var errorIcon: some View {
        ZStack {
            Circle()
                .fill(Color.orange.opacity(0.1))
                .frame(width: 80, height: 80)
            
            Image(systemName: iconName)
                .font(.system(size: 40))
                .foregroundColor(.orange)
        }
    }
    
    private var iconName: String {
        if let apiError = error as? APIError {
            switch apiError {
            case .noInternetConnection:
                return "wifi.slash"
            case .requestTimeout:
                return "clock.arrow.circlepath"
            case .serverError:
                return "exclamationmark.icloud"
            case .missingCredentials:
                return "key.slash"
            default:
                return "exclamationmark.triangle.fill"
            }
        }
        return "exclamationmark.triangle.fill"
    }
    
    private var errorMessage: String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }
        return error.localizedDescription
    }
    
    private var detailedErrorView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Error Details")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Text(String(describing: error))
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(10)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
        .padding(.horizontal)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 15) {
            if let retry = retry {
                Button(action: retry) {
                    Label("Try Again", systemImage: "arrow.clockwise")
                        .font(.body.weight(.medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.purple)
                        .cornerRadius(10)
                }
            }
            
            if let dismiss = dismiss {
                Button(action: dismiss) {
                    Text("Dismiss")
                        .font(.body.weight(.medium))
                        .foregroundColor(.purple)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.purple, lineWidth: 1)
                        )
                }
            }
        }
    }
    
    private var toggleDetailsButton: some View {
        Button(action: { withAnimation { isExpanded.toggle() } }) {
            HStack(spacing: 5) {
                Text(isExpanded ? "Hide Details" : "Show Details")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white)
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Loading View
struct LoadingView: View {
    let message: String
    @State private var isAnimating = false
    @State private var rotation: Double = 0
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.purple.opacity(0.2), lineWidth: 4)
                    .frame(width: 50, height: 50)
                
                // Animated arc
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(rotation))
                    .animation(
                        .linear(duration: 1)
                        .repeatForever(autoreverses: false),
                        value: rotation
                    )
            }
            .onAppear {
                rotation = 360
            }
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String
    let action: (() -> Void)?
    let actionLabel: String?
    
    init(
        title: String,
        message: String,
        systemImage: String,
        action: (() -> Void)? = nil,
        actionLabel: String? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.action = action
        self.actionLabel = actionLabel
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: systemImage)
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            VStack(spacing: 10) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if let action = action, let actionLabel = actionLabel {
                Button(action: action) {
                    Text(actionLabel)
                        .font(.body.weight(.medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(10)
                }
                .padding(.top, 10)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Network Status Banner
struct NetworkStatusBanner: View {
    @ObservedObject var monitor = NetworkMonitor.shared
    @State private var showBanner = false
    
    var body: some View {
        VStack {
            if !monitor.isConnected && showBanner {
                HStack {
                    Image(systemName: "wifi.slash")
                        .font(.body)
                    
                    Text("No Internet Connection")
                        .font(.body.weight(.medium))
                    
                    Spacer()
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.orange)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .networkStatusChanged)) { _ in
            withAnimation {
                showBanner = !monitor.isConnected
            }
            
            if monitor.isConnected && showBanner {
                // Hide banner after 2 seconds when reconnected
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        showBanner = false
                    }
                }
            }
        }
        .onAppear {
            showBanner = !monitor.isConnected
        }
    }
}

// MARK: - Retry View Modifier
struct RetryOnError: ViewModifier {
    let action: () async throws -> Void
    @State private var error: Error?
    @State private var isLoading = false
    @State private var showError = false
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if isLoading {
                        LoadingView(message: "Loading...")
                            .background(Color.black.opacity(0.3))
                    }
                    
                    if showError, let error = error {
                        ErrorView(
                            error: error,
                            retry: {
                                Task {
                                    await retry()
                                }
                            },
                            dismiss: {
                                showError = false
                            }
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            )
            .task {
                await retry()
            }
    }
    
    private func retry() async {
        isLoading = true
        showError = false
        
        do {
            try await action()
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
            withAnimation {
                showError = true
            }
        }
    }
}

extension View {
    func retryOnError(perform action: @escaping () async throws -> Void) -> some View {
        modifier(RetryOnError(action: action))
    }
}

// MARK: - Alert Helper
struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let primaryButton: Alert.Button
    let secondaryButton: Alert.Button?
    
    var alert: Alert {
        if let secondaryButton = secondaryButton {
            return Alert(
                title: Text(title),
                message: Text(message),
                primaryButton: primaryButton,
                secondaryButton: secondaryButton
            )
        } else {
            return Alert(
                title: Text(title),
                message: Text(message),
                dismissButton: primaryButton
            )
        }
    }
}

// MARK: - Preview Provider
struct ErrorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ErrorView(
                error: APIError.noInternetConnection,
                retry: { print("Retry tapped") },
                dismiss: { print("Dismiss tapped") }
            )
            .previewDisplayName("Network Error")
            
            LoadingView(message: "Loading your data...")
                .previewDisplayName("Loading View")
            
            EmptyStateView(
                title: "No Templates",
                message: "You haven't created any templates yet",
                systemImage: "doc.text",
                action: { print("Create tapped") },
                actionLabel: "Create Template"
            )
            .previewDisplayName("Empty State")
            
            NetworkStatusBanner()
                .previewDisplayName("Network Banner")
        }
    }
}
