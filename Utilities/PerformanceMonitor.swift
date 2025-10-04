import Foundation
import os.log
import UIKit

// MARK: - Performance Monitor
final class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    
    private let signpostLog = OSLog(subsystem: "com.neurosplit.app", category: "Performance")
    private let metricsLog = OSLog(subsystem: "com.neurosplit.app", category: "Metrics")
    
    private var launchStartTime: CFAbsoluteTime?
    private var memoryWarningCount = 0
    
    private init() {
        setupMemoryWarningObserver()
    }
    
    // MARK: - Launch Performance
    
    func markLaunchStart() {
        launchStartTime = CFAbsoluteTimeGetCurrent()
        os_signpost(.event, log: signpostLog, name: "App Launch", "Launch started")
    }
    
    func markLaunchEnd() {
        guard let startTime = launchStartTime else { return }
        
        let launchTime = CFAbsoluteTimeGetCurrent() - startTime
        os_signpost(.event, log: signpostLog, name: "App Launch", "Launch completed in %.2f seconds", launchTime)
        
        AppLogger.info("App launch time: \(String(format: "%.2f", launchTime)) seconds")
        
        // Log warning if launch time exceeds threshold
        if launchTime > 0.4 {
            AppLogger.warning("Launch time exceeded 400ms threshold: \(launchTime)s")
        }
        
        launchStartTime = nil
    }
    
    // MARK: - Operation Timing
    
    func measureTime<T>(
        operation: String,
        warningThreshold: TimeInterval = 0.5,
        block: () throws -> T
    ) rethrows -> T {
        let signpostID = OSSignpostID(log: signpostLog)
        
        os_signpost(.begin, log: signpostLog, name: "Operation", signpostID: signpostID, "%s", operation)
        let startTime = CFAbsoluteTimeGetCurrent()
        
        defer {
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            os_signpost(.end, log: signpostLog, name: "Operation", signpostID: signpostID, "Completed in %.3f seconds", elapsed)
            
            if elapsed > warningThreshold {
                AppLogger.warning("Slow operation '\(operation)': \(String(format: "%.3f", elapsed))s")
            } else {
                AppLogger.debug("Operation '\(operation)': \(String(format: "%.3f", elapsed))s")
            }
        }
        
        return try block()
    }
    
    func measureTimeAsync<T>(
        operation: String,
        warningThreshold: TimeInterval = 0.5,
        block: () async throws -> T
    ) async rethrows -> T {
        let signpostID = OSSignpostID(log: signpostLog)
        
        os_signpost(.begin, log: signpostLog, name: "Async Operation", signpostID: signpostID, "%s", operation)
        let startTime = CFAbsoluteTimeGetCurrent()
        
        defer {
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            os_signpost(.end, log: signpostLog, name: "Async Operation", signpostID: signpostID, "Completed in %.3f seconds", elapsed)
            
            if elapsed > warningThreshold {
                AppLogger.warning("Slow async operation '\(operation)': \(String(format: "%.3f", elapsed))s")
            } else {
                AppLogger.debug("Async operation '\(operation)': \(String(format: "%.3f", elapsed))s")
            }
        }
        
        return try await block()
    }
    
    // MARK: - Memory Monitoring
    
    func trackMemoryUsage() -> MemoryUsage {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            return MemoryUsage(used: 0, peak: 0, available: 0)
        }
        
        let usedMemoryMB = Float(info.resident_size) / 1024 / 1024
        let availableMemoryMB = Float(ProcessInfo.processInfo.physicalMemory) / 1024 / 1024
        
        let usage = MemoryUsage(
            used: usedMemoryMB,
            peak: max(usedMemoryMB, lastPeakMemory),
            available: availableMemoryMB
        )
        
        lastPeakMemory = usage.peak
        
        // Log warning if memory usage is high
        if usedMemoryMB > 100 {
            AppLogger.warning("High memory usage: \(String(format: "%.1f", usedMemoryMB)) MB")
        }
        
        os_signpost(.event, log: metricsLog, name: "Memory", "Used: %.1f MB", usedMemoryMB)
        
        return usage
    }
    
    private var lastPeakMemory: Float = 0
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func handleMemoryWarning() {
        memoryWarningCount += 1
        let currentUsage = trackMemoryUsage()
        
        AppLogger.error("Memory warning #\(memoryWarningCount) - Current usage: \(currentUsage.used) MB")
        os_signpost(.event, log: signpostLog, name: "Memory Warning", "Warning #%d - Usage: %.1f MB", memoryWarningCount, currentUsage.used)
    }
    
    // MARK: - Network Performance
    
    func trackNetworkRequest(
        url: URL,
        startTime: CFAbsoluteTime,
        endTime: CFAbsoluteTime,
        responseSize: Int?,
        error: Error?
    ) {
        let duration = endTime - startTime
        let sizeKB = responseSize.map { Float($0) / 1024 } ?? 0
        
        if let error = error {
            os_signpost(.event, log: metricsLog, name: "Network Request",
                       "Failed: %s - Duration: %.2fs - Error: %s",
                       url.absoluteString, duration, error.localizedDescription)
            AppLogger.error("Network request failed: \(url.absoluteString) - \(error)")
        } else {
            os_signpost(.event, log: metricsLog, name: "Network Request",
                       "Success: %s - Duration: %.2fs - Size: %.1f KB",
                       url.absoluteString, duration, sizeKB)
            
            if duration > 2.0 {
                AppLogger.warning("Slow network request (\(String(format: "%.2f", duration))s): \(url.absoluteString)")
            }
        }
    }
    
    // MARK: - UI Performance
    
    func trackViewAppear(_ viewName: String) {
        os_signpost(.event, log: signpostLog, name: "View Lifecycle", "View appeared: %s", viewName)
        AppLogger.debug("View appeared: \(viewName)")
    }
    
    func trackViewDisappear(_ viewName: String) {
        os_signpost(.event, log: signpostLog, name: "View Lifecycle", "View disappeared: %s", viewName)
    }
    
    func trackUserAction(_ action: String, metadata: [String: Any]? = nil) {
        var metadataString = ""
        if let metadata = metadata {
            metadataString = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        }
        
        os_signpost(.event, log: signpostLog, name: "User Action", "%s - %s", action, metadataString)
        AppLogger.debug("User action: \(action) \(metadataString.isEmpty ? "" : "[\(metadataString)]")")
    }
    
    // MARK: - Performance Report
    
    func generatePerformanceReport() -> PerformanceReport {
        let memory = trackMemoryUsage()
        
        return PerformanceReport(
            memoryUsageMB: memory.used,
            peakMemoryMB: memory.peak,
            memoryWarnings: memoryWarningCount,
            timestamp: Date()
        )
    }
}

// MARK: - Data Models

struct MemoryUsage {
    let used: Float      // MB
    let peak: Float      // MB
    let available: Float // MB
    
    var usagePercentage: Float {
        guard available > 0 else { return 0 }
        return (used / available) * 100
    }
    
    var isHighUsage: Bool {
        return used > 100 // MB threshold
    }
}

struct PerformanceReport {
    let memoryUsageMB: Float
    let peakMemoryMB: Float
    let memoryWarnings: Int
    let timestamp: Date
    
    var summary: String {
        """
        Performance Report - \(timestamp.formatted())
        Memory: \(String(format: "%.1f", memoryUsageMB)) MB (Peak: \(String(format: "%.1f", peakMemoryMB)) MB)
        Memory Warnings: \(memoryWarnings)
        """
    }
}

// MARK: - SwiftUI View Modifier

import SwiftUI

struct PerformanceTracking: ViewModifier {
    let viewName: String
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                PerformanceMonitor.shared.trackViewAppear(viewName)
            }
            .onDisappear {
                PerformanceMonitor.shared.trackViewDisappear(viewName)
            }
    }
}

extension View {
    func trackPerformance(_ viewName: String) -> some View {
        modifier(PerformanceTracking(viewName: viewName))
    }
}

// MARK: - Debug Overlay

#if DEBUG
struct PerformanceOverlay: View {
    @State private var memoryUsage = PerformanceMonitor.shared.trackMemoryUsage()
    @State private var isExpanded = false
    
    let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack {
            HStack {
                if isExpanded {
                    expandedView
                } else {
                    collapsedView
                }
                
                Spacer()
            }
            
            Spacer()
        }
        .onReceive(timer) { _ in
            memoryUsage = PerformanceMonitor.shared.trackMemoryUsage()
        }
    }
    
    private var collapsedView: some View {
        Button(action: { isExpanded.toggle() }) {
            HStack(spacing: 4) {
                Image(systemName: "speedometer")
                    .font(.caption)
                Text("\(String(format: "%.0f", memoryUsage.used))MB")
                    .font(.caption)
            }
            .padding(4)
            .background(memoryUsage.isHighUsage ? Color.orange : Color.green)
            .foregroundColor(.white)
            .cornerRadius(4)
        }
    }
    
    private var expandedView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Performance")
                    .font(.caption.bold())
                Spacer()
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Memory:")
                    Text("\(String(format: "%.1f", memoryUsage.used)) MB")
                        .foregroundColor(memoryUsage.isHighUsage ? .orange : .green)
                }
                .font(.caption2)
                
                HStack {
                    Text("Peak:")
                    Text("\(String(format: "%.1f", memoryUsage.peak)) MB")
                }
                .font(.caption2)
                
                HStack {
                    Text("Usage:")
                    Text("\(String(format: "%.1f", memoryUsage.usagePercentage))%")
                }
                .font(.caption2)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.8))
        .foregroundColor(.white)
        .cornerRadius(8)
    }
}
#endif
