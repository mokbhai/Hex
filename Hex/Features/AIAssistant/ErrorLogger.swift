import Foundation
import ComposableArchitecture
import os.log

/// Comprehensive error logging system for all AI Assistant features
/// Provides structured error tracking with context, severity levels, and analytics
enum ErrorSeverity: Int, Codable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case critical = 4
    
    var description: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .critical: return "CRITICAL"
        }
    }
}

/// Structured error log entry with contextual information
struct ErrorLogEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let severity: ErrorSeverity
    let category: String // e.g., "AIAssistant", "Search", "Timer", "Calculator", "Note", "Todo"
    let message: String
    let errorCode: String?
    let stackTrace: String?
    let context: [String: String]? // Additional contextual key-value pairs
    let userId: String?
    let sessionId: UUID
    
    init(
        severity: ErrorSeverity,
        category: String,
        message: String,
        errorCode: String? = nil,
        stackTrace: String? = nil,
        context: [String: String]? = nil,
        userId: String? = nil,
        sessionId: UUID
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.severity = severity
        self.category = category
        self.message = message
        self.errorCode = errorCode
        self.stackTrace = stackTrace
        self.context = context
        self.userId = userId
        self.sessionId = sessionId
    }
}

/// Error logger with persistent storage and analytics capabilities
actor ErrorLogger {
    static let shared = ErrorLogger()
    
    private let osLog = OSLog(subsystem: "com.hex.ai-assistant", category: "ErrorLogging")
    private var entries: [ErrorLogEntry] = []
    private let sessionId: UUID = UUID()
    private let fileManager = FileManager.default
    private let logDirectory: URL
    private var errorCounts: [String: Int] = [:] // category -> count
    private var lastErrors: [String: ErrorLogEntry] = [:] // category -> last error
    private var errorThresholdAlerts: [String: Int] = [:]
    
    /// Configuration for error logging behavior
    struct Configuration {
        let maxEntriesInMemory: Int = 1000
        let enablePersistence: Bool = true
        let persistenceInterval: TimeInterval = 5 // seconds
        let enableOSLog: Bool = true
        let errorThreshold: Int = 10 // Alert after N errors in a category
        let retentionDays: Int = 30
    }
    
    private let config: Configuration
    private var persistenceTask: Task<Void, Never>?
    
    nonisolated private init() {
        self.config = Configuration()
        
        // Setup log directory
        let appSupportDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        self.logDirectory = appSupportDirectory.appendingPathComponent("HexLogs", isDirectory: true)
        
        Task {
            try? FileManager.default.createDirectory(
                at: self.logDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            await self.setupPersistenceTask()
            await self.loadPersistentLogs()
        }
    }
    
    // MARK: - Core Logging
    
    /// Log an error with full context
    func log(
        _ error: Error,
        severity: ErrorSeverity = .error,
        category: String,
        context: [String: String]? = nil,
        userId: String? = nil
    ) {
        let entry = ErrorLogEntry(
            severity: severity,
            category: category,
            message: error.localizedDescription,
            errorCode: (error as NSError).code.description,
            stackTrace: captureStackTrace(),
            context: context,
            userId: userId,
            sessionId: sessionId
        )
        
        processLogEntry(entry)
    }
    
    /// Log a message with structured data
    func log(
        severity: ErrorSeverity = .info,
        category: String,
        message: String,
        errorCode: String? = nil,
        context: [String: String]? = nil,
        userId: String? = nil
    ) {
        let entry = ErrorLogEntry(
            severity: severity,
            category: category,
            message: message,
            errorCode: errorCode,
            context: context,
            userId: userId,
            sessionId: sessionId
        )
        
        processLogEntry(entry)
    }
    
    // MARK: - Private Methods
    
    private func processLogEntry(_ entry: ErrorLogEntry) {
        // Add to in-memory storage
        entries.append(entry)
        
        // Maintain size limit
        if entries.count > config.maxEntriesInMemory {
            entries.removeFirst(entries.count - config.maxEntriesInMemory)
        }
        
        // Update statistics
        errorCounts[entry.category, default: 0] += 1
        lastErrors[entry.category] = entry
        
        // Check thresholds
        if errorCounts[entry.category] ?? 0 >= config.errorThreshold {
            if errorThresholdAlerts[entry.category] == nil {
                errorThresholdAlerts[entry.category] = entry.severity.rawValue
            }
        }
        
        // OS Logging
        if config.enableOSLog {
            let logType: OSLogType = {
                switch entry.severity {
                case .debug: return .debug
                case .info: return .info
                case .warning: return .default
                case .error: return .error
                case .critical: return .fault
                }
            }()
            
            os_log(
                "%{public}@[%{public}@] %{public}@",
                log: osLog,
                type: logType,
                entry.category,
                entry.severity.description,
                entry.message
            )
        }
    }
    
    private func captureStackTrace() -> String? {
        let stackSymbols = Thread.callStackSymbols
        // Return top 5 stack frames (skip first 2 which are logging infrastructure)
        return stackSymbols.dropFirst(2).prefix(5).joined(separator: "\n")
    }
    
    // MARK: - Persistence
    
    private func setupPersistenceTask() {
        persistenceTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(config.persistenceInterval * 1_000_000_000))
                if !Task.isCancelled {
                    await persistLogs()
                }
            }
        }
    }
    
    private func persistLogs() async {
        guard config.enablePersistence else { return }
        
        let dateFormatter = ISO8601DateFormatter()
        let filename = "error-log-\(dateFormatter.string(from: Date())).json"
        let fileURL = logDirectory.appendingPathComponent(filename)
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(entries)
            try data.write(to: fileURL)
        } catch {
            os_log(
                "Failed to persist error logs: %{public}@",
                log: osLog,
                type: .error,
                error.localizedDescription
            )
        }
    }
    
    private func loadPersistentLogs() async {
        guard config.enablePersistence else { return }
        
        do {
            let logFiles = try fileManager.contentsOfDirectory(
                at: logDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey]
            ).filter { $0.pathExtension == "json" }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            for file in logFiles.sorted(by: { $0.lastPathComponent > $1.lastPathComponent }).prefix(5) {
                let data = try Data(contentsOf: file)
                let loadedEntries = try decoder.decode([ErrorLogEntry].self, from: data)
                entries.append(contentsOf: loadedEntries)
            }
            
            // Maintain size limit after loading
            if entries.count > config.maxEntriesInMemory {
                entries.removeFirst(entries.count - config.maxEntriesInMemory)
            }
        } catch {
            os_log(
                "Failed to load persistent error logs: %{public}@",
                log: osLog,
                type: .error,
                error.localizedDescription
            )
        }
    }
    
    // MARK: - Query & Analytics
    
    /// Fetch all logged errors with optional filtering
    func getEntries(
        category: String? = nil,
        severity: ErrorSeverity? = nil,
        limit: Int = 100
    ) -> [ErrorLogEntry] {
        var filtered = entries
        
        if let category = category {
            filtered = filtered.filter { $0.category == category }
        }
        
        if let severity = severity {
            filtered = filtered.filter { $0.severity.rawValue >= severity.rawValue }
        }
        
        return Array(filtered.suffix(limit))
    }
    
    /// Get error statistics
    func getStatistics() -> [String: Any] {
        let totalErrors = entries.count
        let errorBySeverity = Dictionary(
            grouping: entries,
            by: { $0.severity.description }
        ).mapValues { $0.count }
        
        let errorByCategory = Dictionary(
            grouping: entries,
            by: { $0.category }
        ).mapValues { $0.count }
        
        return [
            "totalErrors": totalErrors,
            "bySeverity": errorBySeverity,
            "byCategory": errorByCategory,
            "sessionId": sessionId.uuidString,
            "lastEntry": entries.last?.timestamp ?? Date()
        ]
    }
    
    /// Get errors for a specific category
    func getCategoryErrors(_ category: String) -> [ErrorLogEntry] {
        entries.filter { $0.category == category }
    }
    
    /// Get recent errors (last N hours)
    func getRecentErrors(hours: Int = 1) -> [ErrorLogEntry] {
        let cutoffDate = Date().addingTimeInterval(-Double(hours) * 3600)
        return entries.filter { $0.timestamp >= cutoffDate }
    }
    
    /// Check if category has exceeded error threshold
    func hasExceededThreshold(_ category: String) -> Bool {
        (errorCounts[category] ?? 0) >= config.errorThreshold
    }
    
    /// Get threshold alerts
    func getThresholdAlerts() -> [String: Int] {
        errorThresholdAlerts
    }
    
    // MARK: - Cleanup
    
    /// Clear all logs (typically for testing or user request)
    func clearLogs() {
        entries.removeAll()
        errorCounts.removeAll()
        lastErrors.removeAll()
        errorThresholdAlerts.removeAll()
    }
    
    /// Clear logs older than specified days
    func clearOldLogs() {
        let cutoffDate = Date().addingTimeInterval(-Double(config.retentionDays) * 86400)
        entries.removeAll { $0.timestamp < cutoffDate }
    }
    
    /// Export logs as JSON string
    func exportLogs() throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(entries)
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    /// Deinitialize and cleanup
    deinit {
        persistenceTask?.cancel()
    }
}

// MARK: - Convenience Extensions

extension ErrorLogger {
    func logAIError(_ error: Error, context: [String: String]? = nil) {
        Task {
            await log(error, category: "AIAssistant", context: context)
        }
    }
    
    func logSearchError(_ error: Error, query: String? = nil) {
        Task {
            var context = [String: String]()
            if let query = query {
                context["query"] = query
            }
            await log(error, category: "Search", context: context)
        }
    }
    
    func logTimerError(_ error: Error, timerId: String? = nil) {
        Task {
            var context = [String: String]()
            if let timerId = timerId {
                context["timerId"] = timerId
            }
            await log(error, category: "Timer", context: context)
        }
    }
    
    func logCalculatorError(_ error: Error, expression: String? = nil) {
        Task {
            var context = [String: String]()
            if let expression = expression {
                context["expression"] = expression
            }
            await log(error, category: "Calculator", context: context)
        }
    }
    
    func logNoteError(_ error: Error, noteId: String? = nil) {
        Task {
            var context = [String: String]()
            if let noteId = noteId {
                context["noteId"] = noteId
            }
            await log(error, category: "Note", context: context)
        }
    }
    
    func logTodoError(_ error: Error, todoId: String? = nil) {
        Task {
            var context = [String: String]()
            if let todoId = todoId {
                context["todoId"] = todoId
            }
            await log(error, category: "Todo", context: context)
        }
    }
}

// MARK: - TCA Integration

extension DependencyValues {
    var errorLogger: ErrorLogger {
        get { self[ErrorLoggerKey.self] }
        set { self[ErrorLoggerKey.self] = newValue }
    }
}

private struct ErrorLoggerKey: DependencyKey {
    static let liveValue = ErrorLogger.shared
    static let testValue = ErrorLogger.shared
}
