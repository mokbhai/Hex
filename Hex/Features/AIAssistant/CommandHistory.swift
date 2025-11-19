import Foundation
import ComposableArchitecture

/// Represents a single command execution in the history
struct CommandHistoryEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let command: String
    let input: String
    let result: String?
    let executionTime: TimeInterval // in seconds
    let success: Bool
    let category: String // e.g., "SystemCommand", "Search", "Timer", "Calculator", "Note", "Todo"
    let userId: String?
    let sessionId: UUID
    let tags: [String]? // For filtering and organization
    let metadata: [String: String]? // Additional execution context
    
    init(
        command: String,
        input: String,
        result: String? = nil,
        executionTime: TimeInterval,
        success: Bool,
        category: String,
        userId: String? = nil,
        sessionId: UUID,
        tags: [String]? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.command = command
        self.input = input
        self.result = result
        self.executionTime = executionTime
        self.success = success
        self.category = category
        self.userId = userId
        self.sessionId = sessionId
        self.tags = tags
        self.metadata = metadata
    }
}

/// Command execution pattern for analytics and suggestions
struct CommandPattern: Codable, Identifiable {
    let id: UUID
    let pattern: String // normalized command pattern
    var frequency: Int
    var successRate: Double
    var averageExecutionTime: TimeInterval
    var lastUsed: Date
    let relatedCommands: [String]
    
    init(pattern: String) {
        self.id = UUID()
        self.pattern = pattern
        self.frequency = 0
        self.successRate = 0.0
        self.averageExecutionTime = 0.0
        self.lastUsed = Date()
        self.relatedCommands = []
    }
}

/// Comprehensive command history tracker with analytics
actor CommandHistory {
    static let shared = CommandHistory()
    
    private var entries: [CommandHistoryEntry] = []
    private var patterns: [String: CommandPattern] = [:]
    private let sessionId: UUID = UUID()
    private let fileManager = FileManager.default
    private let historyDirectory: URL
    private var frequentCommands: [String: Int] = [:]
    private var categoryStats: [String: CategoryStatistics] = [:]
    private var userPatterns: [String: UserPattern] = [:]
    
    /// Statistics for a command category
    struct CategoryStatistics: Codable {
        var totalExecutions: Int = 0
        var successfulExecutions: Int = 0
        var failedExecutions: Int = 0
        var totalExecutionTime: TimeInterval = 0
        var averageExecutionTime: TimeInterval = 0
        var lastExecuted: Date? = nil
    }
    
    /// User behavior pattern
    struct UserPattern: Codable {
        var commandSequence: [String] = []
        var timeOfDayDistribution: [Int: Int] = [:] // hour -> count
        var dayOfWeekDistribution: [Int: Int] = [:] // 0-6 (Sun-Sat) -> count
        var frequencyTrend: [FrequencyData] = []
        
        struct FrequencyData: Codable {
            let date: Date
            let count: Int
        }
    }
    
    /// Configuration for history tracking
    struct Configuration {
        let maxEntriesInMemory: Int = 5000
        let enablePersistence: Bool = true
        let persistenceInterval: TimeInterval = 10 // seconds
        let retentionDays: Int = 90
        let maxPatternLength: Int = 10 // For pattern matching
    }
    
    private let config: Configuration
    private var persistenceTask: Task<Void, Never>?
    
    private init() {
        self.config = Configuration()
        
        // Setup history directory
        let appSupportDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        self.historyDirectory = appSupportDirectory.appendingPathComponent("HexHistory", isDirectory: true)
        
        Task {
            try? FileManager.default.createDirectory(
                at: self.historyDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            await self.setupPersistenceTask()
            await self.loadPersistentHistory()
        }
    }
    
    // MARK: - Recording Commands
    
    /// Record a command execution
    func record(
        command: String,
        input: String,
        result: String? = nil,
        executionTime: TimeInterval,
        success: Bool,
        category: String,
        userId: String? = nil,
        tags: [String]? = nil,
        metadata: [String: String]? = nil
    ) {
        let entry = CommandHistoryEntry(
            command: command,
            input: input,
            result: result,
            executionTime: executionTime,
            success: success,
            category: category,
            userId: userId,
            sessionId: sessionId,
            tags: tags,
            metadata: metadata
        )
        
        processEntry(entry)
    }
    
    private func processEntry(_ entry: CommandHistoryEntry) {
        // Add to entries
        entries.append(entry)
        
        // Maintain size limit
        if entries.count > config.maxEntriesInMemory {
            entries.removeFirst(entries.count - config.maxEntriesInMemory)
        }
        
        // Update statistics
        updateCategoryStats(entry)
        updateUserPatterns(entry)
        updateFrequentCommands(entry)
        updateCommandPatterns(entry)
    }
    
    // MARK: - Analytics
    
    private func updateCategoryStats(_ entry: CommandHistoryEntry) {
        var stats = categoryStats[entry.category] ?? CategoryStatistics()
        stats.totalExecutions += 1
        if entry.success {
            stats.successfulExecutions += 1
        } else {
            stats.failedExecutions += 1
        }
        stats.totalExecutionTime += entry.executionTime
        stats.averageExecutionTime = stats.totalExecutionTime / Double(stats.totalExecutions)
        stats.lastExecuted = entry.timestamp
        categoryStats[entry.category] = stats
    }
    
    private func updateUserPatterns(_ entry: CommandHistoryEntry) {
        var pattern = userPatterns["default"] ?? UserPattern()
        
        // Update command sequence
        pattern.commandSequence.append(entry.command)
        if pattern.commandSequence.count > config.maxPatternLength {
            pattern.commandSequence.removeFirst()
        }
        
        // Update time of day distribution
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: entry.timestamp)
        pattern.timeOfDayDistribution[hour, default: 0] += 1
        
        // Update day of week distribution
        let dayOfWeek = calendar.component(.weekday, from: entry.timestamp) - 1 // 0-6
        pattern.dayOfWeekDistribution[dayOfWeek, default: 0] += 1
        
        userPatterns["default"] = pattern
    }
    
    private func updateFrequentCommands(_ entry: CommandHistoryEntry) {
        frequentCommands[entry.command, default: 0] += 1
    }
    
    private func updateCommandPatterns(_ entry: CommandHistoryEntry) {
        let pattern = entry.command.lowercased()
        var cmdPattern = patterns[pattern] ?? CommandPattern(pattern: pattern)
        
        cmdPattern.frequency += 1
        let successCount = entries.filter {
            $0.command.lowercased() == pattern && $0.success
        }.count
        cmdPattern.successRate = Double(successCount) / Double(cmdPattern.frequency)
        cmdPattern.lastUsed = entry.timestamp
        
        patterns[pattern] = cmdPattern
    }
    
    // MARK: - Querying History
    
    /// Get all history entries
    func getEntries(limit: Int = 100) -> [CommandHistoryEntry] {
        Array(entries.suffix(limit))
    }
    
    /// Get entries for a specific category
    func getEntriesByCategory(_ category: String, limit: Int = 100) -> [CommandHistoryEntry] {
        entries.filter { $0.category == category }.suffix(limit).reversed()
    }
    
    /// Get successful command executions
    func getSuccessfulEntries(limit: Int = 100) -> [CommandHistoryEntry] {
        entries.filter { $0.success }.suffix(limit).reversed()
    }
    
    /// Get failed command executions
    func getFailedEntries(limit: Int = 100) -> [CommandHistoryEntry] {
        entries.filter { !$0.success }.suffix(limit).reversed()
    }
    
    /// Get entries matching a search term
    func search(term: String, limit: Int = 100) -> [CommandHistoryEntry] {
        let lowerTerm = term.lowercased()
        return entries.filter {
            $0.command.lowercased().contains(lowerTerm) ||
            $0.input.lowercased().contains(lowerTerm) ||
            $0.result?.lowercased().contains(lowerTerm) ?? false
        }.suffix(limit).reversed()
    }
    
    /// Get entries within a date range
    func getEntriesByDateRange(from: Date, to: Date, limit: Int = 1000) -> [CommandHistoryEntry] {
        entries.filter { $0.timestamp >= from && $0.timestamp <= to }.suffix(limit).reversed()
    }
    
    /// Get entries with specific tags
    func getEntriesByTags(_ tags: [String], limit: Int = 100) -> [CommandHistoryEntry] {
        entries.filter { entry in
            guard let entryTags = entry.tags else { return false }
            return tags.allSatisfy { entryTags.contains($0) }
        }.suffix(limit).reversed()
    }
    
    // MARK: - Statistics
    
    /// Get comprehensive statistics
    func getStatistics() -> [String: Any] {
        let totalCommands = entries.count
        let successfulCommands = entries.filter { $0.success }.count
        let failedCommands = entries.filter { !$0.success }.count
        let successRate = totalCommands > 0 ? Double(successfulCommands) / Double(totalCommands) : 0.0
        let totalTime = entries.reduce(0) { $0 + $1.executionTime }
        let averageTime = totalCommands > 0 ? totalTime / Double(totalCommands) : 0.0
        
        let topCommands = frequentCommands.sorted { $0.value > $1.value }
            .prefix(10)
            .map { ["command": $0.key, "count": $0.value] }
        
        return [
            "totalCommands": totalCommands,
            "successfulCommands": successfulCommands,
            "failedCommands": failedCommands,
            "successRate": successRate,
            "totalExecutionTime": totalTime,
            "averageExecutionTime": averageTime,
            "topCommands": topCommands,
            "categoryCounts": categoryStats.mapValues { ["total": $0.totalExecutions, "successful": $0.successfulExecutions] },
            "sessionId": sessionId.uuidString
        ]
    }
    
    /// Get category-specific statistics
    func getCategoryStatistics(_ category: String) -> CategoryStatistics? {
        categoryStats[category]
    }
    
    /// Get most frequently used commands
    func getTopCommands(limit: Int = 10) -> [(command: String, count: Int)] {
        frequentCommands.sorted { $0.value > $1.value }
            .prefix(limit)
            .map { ($0.key, $0.value) }
    }
    
    /// Get command patterns and their performance
    func getCommandPatterns() -> [CommandPattern] {
        patterns.values.sorted { $0.frequency > $1.frequency }
    }
    
    /// Get user behavior patterns
    func getUserPatterns() -> UserPattern? {
        userPatterns["default"]
    }
    
    /// Get slowest commands
    func getSlowestCommands(limit: Int = 10) -> [(command: String, time: TimeInterval)] {
        let commandTimes = Dictionary(grouping: entries, by: { $0.command })
            .mapValues { commands in
                commands.reduce(0) { $0 + $1.executionTime } / Double(commands.count)
            }
        
        return commandTimes.sorted { $0.value > $1.value }
            .prefix(limit)
            .map { ($0.key, $0.value) }
    }
    
    /// Get suggested commands based on usage patterns
    func getSuggestedCommands(limit: Int = 5) -> [String] {
        frequentCommands.sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
    }
    
    // MARK: - Persistence
    
    private func setupPersistenceTask() {
        persistenceTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(config.persistenceInterval * 1_000_000_000))
                if !Task.isCancelled {
                    await persistHistory()
                }
            }
        }
    }
    
    private func persistHistory() async {
        guard config.enablePersistence else { return }
        
        let dateFormatter = ISO8601DateFormatter()
        let filename = "command-history-\(dateFormatter.string(from: Date())).json"
        let fileURL = historyDirectory.appendingPathComponent(filename)
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(entries)
            try data.write(to: fileURL)
        } catch {
            print("Failed to persist command history: \(error)")
        }
    }
    
    private func loadPersistentHistory() async {
        guard config.enablePersistence else { return }
        
        do {
            let historyFiles = try fileManager.contentsOfDirectory(
                at: historyDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey]
            ).filter { $0.pathExtension == "json" }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            for file in historyFiles.sorted(by: { $0.lastPathComponent > $1.lastPathComponent }).prefix(10) {
                let data = try Data(contentsOf: file)
                let loadedEntries = try decoder.decode([CommandHistoryEntry].self, from: data)
                entries.append(contentsOf: loadedEntries)
            }
            
            // Maintain size limit
            if entries.count > config.maxEntriesInMemory {
                entries.removeFirst(entries.count - config.maxEntriesInMemory)
            }
            
            // Rebuild analytics
            for entry in entries {
                updateCategoryStats(entry)
                updateUserPatterns(entry)
                updateFrequentCommands(entry)
                updateCommandPatterns(entry)
            }
        } catch {
            print("Failed to load persistent command history: \(error)")
        }
    }
    
    // MARK: - Export & Reporting
    
    /// Export history as CSV
    func exportAsCSV() -> String {
        var csv = "Timestamp,Command,Input,Result,ExecutionTime,Success,Category\n"
        
        for entry in entries {
            let escapedInput = entry.input.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedResult = entry.result?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            
            csv += "\(entry.timestamp),\(entry.command),\"\(escapedInput)\",\"\(escapedResult)\",\(entry.executionTime),\(entry.success),\(entry.category)\n"
        }
        
        return csv
    }
    
    /// Export history as JSON
    func exportAsJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(entries)
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    // MARK: - Cleanup
    
    /// Clear old entries
    func clearOldEntries() {
        let cutoffDate = Date().addingTimeInterval(-Double(config.retentionDays) * 86400)
        entries.removeAll { $0.timestamp < cutoffDate }
    }
    
    /// Clear all history
    func clearAll() {
        entries.removeAll()
        patterns.removeAll()
        frequentCommands.removeAll()
        categoryStats.removeAll()
        userPatterns.removeAll()
    }
    
    deinit {
        persistenceTask?.cancel()
    }
}

// MARK: - TCA Integration

extension DependencyValues {
    var commandHistory: CommandHistory {
        get { self[CommandHistoryKey.self] }
        set { self[CommandHistoryKey.self] = newValue }
    }
}

private struct CommandHistoryKey: DependencyKey {
    static let liveValue = CommandHistory.shared
    static let testValue = CommandHistory.shared
}
