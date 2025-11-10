import Foundation
import ComposableArchitecture
import AppKit

/// Represents the current context for the user and their environment
struct ContextSnapshot: Codable, Equatable {
    let timestamp: Date
    let timeOfDay: TimeOfDay
    let dayOfWeek: DayOfWeek
    let currentApplication: String?
    let userActivityPattern: UserActivityPattern
    let systemLoad: SystemLoad
    let isNightTime: Bool
    let isBusyHours: Bool
    let recentCommands: [String]?
    let userLocation: String? // "Home", "Work", etc.
    let customContext: [String: String]?
    
    enum TimeOfDay: String, Codable {
        case morning // 6 AM - 12 PM
        case afternoon // 12 PM - 6 PM
        case evening // 6 PM - 12 AM
        case night // 12 AM - 6 AM
    }
    
    enum DayOfWeek: String, Codable {
        case monday, tuesday, wednesday, thursday, friday, saturday, sunday
        
        static func current() -> DayOfWeek {
            let calendar = Calendar.current
            let weekday = calendar.component(.weekday, from: Date()) - 1
            let days: [DayOfWeek] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
            return days[weekday]
        }
    }
    
    enum UserActivityPattern: String, Codable {
        case focused // User is actively working
        case idle // No recent activity
        case multitasking // Frequent app switching
        case resting // Off-work hours
    }
    
    enum SystemLoad: String, Codable {
        case light
        case normal
        case heavy
    }
}

/// Represents user preferences based on context
struct ContextualPreferences: Codable {
    var responseStyle: ResponseStyle = .balanced
    var verbosity: Verbosity = .normal
    var voiceEnabled: Bool = true
    var searchEnabled: Bool = true
    var executionConfirmation: Bool = true
    var prioritizeSpeed: Bool = false
    var prioritizeAccuracy: Bool = false
    
    enum ResponseStyle: String, Codable {
        case brief // Minimal output
        case balanced // Normal output
        case detailed // Verbose output
    }
    
    enum Verbosity: String, Codable {
        case silent
        case minimal
        case normal
        case verbose
        case debug
    }
}

/// Context awareness engine for adaptive behavior
actor ContextAwareness {
    static let shared = ContextAwareness()
    
    private var currentContext: ContextSnapshot?
    private var contextHistory: [ContextSnapshot] = []
    private var userPreferences: [String: ContextualPreferences] = [:]
    private var contextRules: [ContextRule] = []
    private let fileManager = FileManager.default
    private let preferencesDirectory: URL
    private var contextUpdateTask: Task<Void, Never>?
    
    /// Rule for context-based behavior
    struct ContextRule: Codable {
        let id: UUID
        let name: String
        let condition: String // Descriptive condition
        let responseStyle: ContextualPreferences.ResponseStyle?
        let verbosity: ContextualPreferences.Verbosity?
        let enableVoice: Bool?
        let priority: Int // Higher priority = applied first
        let enabled: Bool
    }
    
    nonisolated private init() {
        let appSupportDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        self.preferencesDirectory = appSupportDirectory.appendingPathComponent("HexContext", isDirectory: true)
        
        Task {
            try? FileManager.default.createDirectory(
                at: self.preferencesDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            await self.loadPreferences()
            await self.loadContextRules()
            await self.startContextUpdateLoop()
        }
    }
    
    // MARK: - Context Capture
    
    /// Capture current system and user context
    func captureContext(
        userLocation: String? = nil,
        customContext: [String: String]? = nil
    ) async -> ContextSnapshot {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        
        // Determine time of day
        let timeOfDay: ContextSnapshot.TimeOfDay = {
            if hour >= 6 && hour < 12 { return .morning }
            if hour >= 12 && hour < 18 { return .afternoon }
            if hour >= 18 && hour < 24 { return .evening }
            return .night
        }()
        
        // Check if night time (user may want less audio)
        let isNightTime = hour >= 22 || hour < 6
        
        // Check if busy hours (9-5 on weekdays)
        let dayOfWeek = ContextSnapshot.DayOfWeek.current()
        let isBusyHours = (dayOfWeek != .saturday && dayOfWeek != .sunday) && (hour >= 9 && hour < 17)
        
        // Get current application
        let currentApp = getCurrentApplication()
        
        // Estimate user activity pattern
        let activityPattern = estimateActivityPattern()
        
        // Estimate system load
        let systemLoad = estimateSystemLoad()
        
        // Get recent commands (stub - would integrate with CommandHistory)
        let recentCommands: [String]? = nil
        
        let snapshot = ContextSnapshot(
            timestamp: now,
            timeOfDay: timeOfDay,
            dayOfWeek: dayOfWeek,
            currentApplication: currentApp,
            userActivityPattern: activityPattern,
            systemLoad: systemLoad,
            isNightTime: isNightTime,
            isBusyHours: isBusyHours,
            recentCommands: recentCommands,
            userLocation: userLocation,
            customContext: customContext
        )
        
        currentContext = snapshot
        contextHistory.append(snapshot)
        
        // Maintain history size
        if contextHistory.count > 1000 {
            contextHistory.removeFirst(contextHistory.count - 1000)
        }
        
        return snapshot
    }
    
    private func getCurrentApplication() -> String? {
        let workspace = NSWorkspace.shared
        guard let frontmostApp = workspace.frontmostApplication else { return nil }
        return frontmostApp.bundleIdentifier
    }
    
    private func estimateActivityPattern() -> ContextSnapshot.UserActivityPattern {
        // Simple heuristic: check if there were recent interactions
        guard !contextHistory.isEmpty else { return .idle }
        
        let now = Date()
        let recentContext = contextHistory.suffix(10)
        
        // Check for app switching (multitasking indicator)
        let uniqueApps = Set(recentContext.compactMap { $0.currentApplication }).count
        if uniqueApps > 3 {
            return .multitasking
        }
        
        // Check for recent activity
        let recentTime = recentContext.filter { now.timeIntervalSince($0.timestamp) < 300 }
        if recentTime.isEmpty {
            return .idle
        }
        
        // If time is off-hours and no recent commands, assume resting
        let hour = Calendar.current.component(.hour, from: now)
        if (hour >= 22 || hour < 6) && recentTime.count < 2 {
            return .resting
        }
        
        return .focused
    }
    
    private func estimateSystemLoad() -> ContextSnapshot.SystemLoad {
        let processor = ProcessInfo.processInfo
        let loadAverage = processor.systemUptime > 0 ? 0.5 : 0.0
        
        if loadAverage > 0.7 {
            return .heavy
        } else if loadAverage > 0.4 {
            return .normal
        } else {
            return .light
        }
    }
    
    // MARK: - Context-Based Preferences
    
    /// Get contextual preferences based on current context
    func getContextualPreferences() async -> ContextualPreferences {
        guard let context = currentContext else {
            return ContextualPreferences()
        }
        
        var preferences = ContextualPreferences()
        
        // Apply context-specific rules (sorted by priority)
        let applicableRules = contextRules
            .filter { $0.enabled }
            .sorted { $0.priority > $1.priority }
        
        for rule in applicableRules {
            if evaluateRule(rule, against: context) {
                if let responseStyle = rule.responseStyle {
                    preferences.responseStyle = responseStyle
                }
                if let verbosity = rule.verbosity {
                    preferences.verbosity = verbosity
                }
                if let enableVoice = rule.enableVoice {
                    preferences.voiceEnabled = enableVoice
                }
            }
        }
        
        // Night-time adjustments
        if context.isNightTime {
            preferences.voiceEnabled = false
            preferences.verbosity = .minimal
        }
        
        // Busy hours adjustments
        if context.isBusyHours {
            preferences.responseStyle = .brief
            preferences.executionConfirmation = true
        }
        
        // App-specific adjustments
        if let app = context.currentApplication {
            preferences = adjustPreferencesForApplication(app, base: preferences)
        }
        
        return preferences
    }
    
    private func evaluateRule(_ rule: ContextRule, against context: ContextSnapshot) -> Bool {
        // Simple rule evaluation based on condition string
        // Could be extended with more complex pattern matching
        let condition = rule.condition.lowercased()
        
        if condition.contains("morning") && context.timeOfDay == .morning { return true }
        if condition.contains("afternoon") && context.timeOfDay == .afternoon { return true }
        if condition.contains("evening") && context.timeOfDay == .evening { return true }
        if condition.contains("night") && context.timeOfDay == .night { return true }
        if condition.contains("weekend") && (context.dayOfWeek == .saturday || context.dayOfWeek == .sunday) { return true }
        if condition.contains("weekday") && !(context.dayOfWeek == .saturday || context.dayOfWeek == .sunday) { return true }
        if condition.contains("idle") && context.userActivityPattern == .idle { return true }
        if condition.contains("focused") && context.userActivityPattern == .focused { return true }
        
        return false
    }
    
    private func adjustPreferencesForApplication(_ bundleId: String, base: ContextualPreferences) -> ContextualPreferences {
        var adjusted = base
        
        // Adjust for specific applications
        if bundleId.contains("slack") || bundleId.contains("mail") {
            adjusted.responseStyle = .brief
            adjusted.prioritizeSpeed = true
        } else if bundleId.contains("xcode") || bundleId.contains("sublime") {
            adjusted.responseStyle = .detailed
            adjusted.prioritizeAccuracy = true
        } else if bundleId.contains("music") || bundleId.contains("spotify") {
            adjusted.voiceEnabled = false // Don't interrupt audio
        }
        
        return adjusted
    }
    
    // MARK: - Preference Management
    
    /// Get or create user preferences
    func getPreferences(for userId: String) -> ContextualPreferences {
        userPreferences[userId] ?? ContextualPreferences()
    }
    
    /// Save user preferences
    func savePreferences(_ prefs: ContextualPreferences, for userId: String) async {
        userPreferences[userId] = prefs
        await persistPreferences()
    }
    
    /// Reset preferences to default
    func resetPreferences(for userId: String) async {
        userPreferences[userId] = ContextualPreferences()
        await persistPreferences()
    }
    
    // MARK: - Rule Management
    
    /// Add a context rule
    func addRule(_ rule: ContextRule) async {
        contextRules.append(rule)
        contextRules.sort { $0.priority > $1.priority }
        await persistContextRules()
    }
    
    /// Remove a rule by ID
    func removeRule(_ id: UUID) async {
        contextRules.removeAll { $0.id == id }
        await persistContextRules()
    }
    
    /// Update a rule
    func updateRule(_ rule: ContextRule) async {
        if let index = contextRules.firstIndex(where: { $0.id == rule.id }) {
            contextRules[index] = rule
            contextRules.sort { $0.priority > $1.priority }
            await persistContextRules()
        }
    }
    
    /// Get all rules
    func getRules() -> [ContextRule] {
        contextRules
    }
    
    // MARK: - Analytics
    
    /// Get context statistics
    func getContextStatistics() -> [String: Any] {
        guard !contextHistory.isEmpty else { return [:] }
        
        let timeOfDayDist = Dictionary(grouping: contextHistory, by: { $0.timeOfDay })
            .mapValues { $0.count }
        let dayOfWeekDist = Dictionary(grouping: contextHistory, by: { $0.dayOfWeek })
            .mapValues { $0.count }
        let activityDist = Dictionary(grouping: contextHistory, by: { $0.userActivityPattern })
            .mapValues { $0.count }
        
        let nightTimeCount = contextHistory.filter { $0.isNightTime }.count
        let busyHoursCount = contextHistory.filter { $0.isBusyHours }.count
        
        return [
            "totalSnapshots": contextHistory.count,
            "timeOfDayDistribution": timeOfDayDist,
            "dayOfWeekDistribution": dayOfWeekDist,
            "activityDistribution": activityDist,
            "nightTimePercentage": Double(nightTimeCount) / Double(contextHistory.count),
            "busyHoursPercentage": Double(busyHoursCount) / Double(contextHistory.count)
        ]
    }
    
    /// Get context recommendation
    func getRecommendations() async -> [String] {
        guard let context = currentContext else { return [] }
        
        var recommendations: [String] = []
        
        if context.userActivityPattern == .idle {
            recommendations.append("User appears idle - consider brief responses")
        }
        
        if context.isNightTime {
            recommendations.append("It's night time - disable voice output")
        }
        
        if context.systemLoad == .heavy {
            recommendations.append("System is under heavy load - prioritize speed")
        }
        
        if context.userActivityPattern == .multitasking {
            recommendations.append("User is multitasking - keep responses brief")
        }
        
        return recommendations
    }
    
    // MARK: - Persistence
    
    private func startContextUpdateLoop() {
        contextUpdateTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 300_000_000_000) // 5 minutes
                if !Task.isCancelled {
                    _ = await captureContext()
                }
            }
        }
    }
    
    private func persistPreferences() async {
        let fileURL = preferencesDirectory.appendingPathComponent("preferences.json")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(userPreferences)
            try data.write(to: fileURL)
        } catch {
            print("Failed to persist preferences: \(error)")
        }
    }
    
    private func loadPreferences() async {
        let fileURL = preferencesDirectory.appendingPathComponent("preferences.json")
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            userPreferences = try decoder.decode([String: ContextualPreferences].self, from: data)
        } catch {
            print("Failed to load preferences: \(error)")
        }
    }
    
    private func persistContextRules() async {
        let fileURL = preferencesDirectory.appendingPathComponent("context-rules.json")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(contextRules)
            try data.write(to: fileURL)
        } catch {
            print("Failed to persist context rules: \(error)")
        }
    }
    
    private func loadContextRules() async {
        let fileURL = preferencesDirectory.appendingPathComponent("context-rules.json")
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            contextRules = try decoder.decode([ContextRule].self, from: data)
        } catch {
            print("Failed to load context rules: \(error)")
        }
    }
    
    /// Clear old context history
    func clearOldContext(olderThan days: Int = 7) {
        let cutoffDate = Date().addingTimeInterval(-Double(days) * 86400)
        contextHistory.removeAll { $0.timestamp < cutoffDate }
    }
    
    deinit {
        contextUpdateTask?.cancel()
    }
}

// MARK: - TCA Integration

extension DependencyValues {
    var contextAwareness: ContextAwareness {
        get { self[ContextAwarenessKey.self] }
        set { self[ContextAwarenessKey.self] = newValue }
    }
}

private struct ContextAwarenessKey: DependencyKey {
    static let liveValue = ContextAwareness.shared
    static let testValue = ContextAwareness.shared
}
