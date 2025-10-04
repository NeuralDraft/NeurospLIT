import Foundation

// MARK: - App Configuration
struct AppConfig {
    static let isProduction: Bool = {
        #if DEBUG
        return false
        #else
        return true
        #endif
    }()
    
    static let environment: String = {
        #if DEBUG
        return "development"
        #else
        return "production"
        #endif
    }()
    
    static let enableDetailedLogging: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()
}

// MARK: - Logger
struct AppLogger {
    enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }
    
    static func log(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let filename = URL(fileURLWithPath: file).lastPathComponent
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [\(level.rawValue)] [\(filename):\(line)] \(function) - \(message)")
        #endif
    }
    
    static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, file: file, function: function, line: line)
    }
    
    static func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, file: file, function: function, line: line)
    }
    
    static func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, file: file, function: function, line: line)
    }
    
    static func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, file: file, function: function, line: line)
    }
}
