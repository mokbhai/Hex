import Foundation
import ComposableArchitecture
import Combine

/// Comprehensive settings for the AI Assistant feature
public struct AIAssistantSettings: Codable, Equatable {
    // MARK: - Basic Settings
    var isEnabled: Bool = true
    var autoLaunchOnStartup: Bool = false
    var minimizeToMenuBar: Bool = true
    var showNotifications: Bool = true
    
    // MARK: - Search Settings
    var searchProvider: String = "google" // "google", "bing", "custom"
    var googleAPIKey: String?
    var bingAPIKey: String?
    var customSearchURL: String?
    var customSearchAuthHeader: String?
    var enableWebSearch: Bool = true
    var searchTimeout: TimeInterval = 5.0
    var maxSearchResults: Int = 10
    
    // MARK: - Model Settings
    var preferredModel: String = "mistral-7b"
    var autoDownloadModels: Bool = false
    var downloadQuality: ModelQuality = .standard
    var enableGPUAcceleration: Bool = true
    var modelCacheSize: Int = 5 // GB
    var autoUpdateModels: Bool = true
    
    enum ModelQuality: String, Codable {
        case low = "low"
        case standard = "standard"
        case high = "high"
        case maximum = "maximum"
    }
    
    // MARK: - Hotkey Settings
    var globalHotkeyEnabled: Bool = true
    var globalHotkeyModifiers: [String] = [] // ["cmd", "shift"]
    var globalHotkeyKey: String = "h"
    var recordingHotkeyEnabled: Bool = true
    var recordingHotkeyModifiers: [String] = ["cmd"]
    var recordingHotkeyKey: String = "r"
    
    // MARK: - Voice & Audio Settings
    var voiceInputEnabled: Bool = true
    var voiceOutputEnabled: Bool = false
    var autoPlayAudio: Bool = false
    var audioOutputVolume: Double = 0.7 // 0-1
    var audioInputDevice: String?
    var audioOutputDevice: String?
    var transcriptionLanguage: String = "en-US"
    var speechRate: Double = 1.0 // 0.5-2.0
    var voiceGender: String = "default" // "male", "female", "default"
    
    // MARK: - Response Settings
    var responseStyle: String = "balanced" // "brief", "balanced", "detailed"
    var verbosity: String = "normal" // "silent", "minimal", "normal", "verbose", "debug"
    var showCommandConfirmation: Bool = true
    var showExecutionResults: Bool = true
    var executionTimeout: TimeInterval = 30.0
    
    // MARK: - Privacy & Security
    var enableLogging: Bool = true
    var logLevel: String = "info" // "debug", "info", "warning", "error"
    var retainLogs: Int = 30 // days
    var enableEncryption: Bool = true
    var storeSensitiveData: Bool = false
    var clearHistoryOnExit: Bool = false
    var shareUsageAnalytics: Bool = false
    
    // MARK: - Performance Settings
    var maxConcurrentOperations: Int = 3
    var enableCaching: Bool = true
    var cacheSize: Int = 100 // MB
    var enablePrefetching: Bool = true
    var prioritizePerformance: Bool = false
    var backgroundProcessingEnabled: Bool = true
    
    // MARK: - Advanced Settings
    var customSystemPrompt: String?
    var contextWindowSize: Int = 4096 // tokens
    var temperatureSetting: Double = 0.7 // 0-1
    var topPSetting: Double = 0.9 // 0-1
    var enableExperimental: Bool = false
    var debugMode: Bool = false
    
    // MARK: - Productivity Tool Settings
    var timerNotificationSound: Bool = true
    var todoAutoSync: Bool = true
    var noteAutoBackup: Bool = true
    var noteBackupInterval: TimeInterval = 3600 // 1 hour
    var enableCalculatorHistory: Bool = true
    var enableCommandHistory: Bool = true
    var commandHistorySize: Int = 1000
    
    // MARK: - Feature Flags
    var featureFlags: [String: Bool] = [
        "voiceCommands": true,
        "systemControl": true,
        "webSearch": true,
        "modelManagement": true,
        "audioTranscription": true,
        "voiceFeedback": false,
        "workflowAutomation": true,
        "contextAwareness": true,
        "performanceMetrics": true,
        "errorLogging": true,
        "commandHistory": true
    ]
    
    // MARK: - Last Updated
    var lastUpdated: Date = Date()
    var settingsVersion: Int = 1
}

/// Settings manager for persistent storage and retrieval
actor AIAssistantSettingsManager {
    static let shared = AIAssistantSettingsManager()
    
    @MainActor
    static var settingsDidChange = PassthroughSubject<AIAssistantSettings, Never>()
    
    private var currentSettings: AIAssistantSettings
    private let fileManager = FileManager.default
    private let settingsDirectory: URL
    private let settingsFileName = "ai-assistant-settings.json"
    private var autoSaveTask: Task<Void, Never>?
    private var autoSaveInterval: TimeInterval = 5.0 // seconds
    
    /// Default settings for factory reset
    static func defaultSettings() -> AIAssistantSettings {
        AIAssistantSettings()
    }
    
    private init() {
        let appSupportDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        self.settingsDirectory = appSupportDirectory.appendingPathComponent("HexSettings", isDirectory: true)
        self.currentSettings = AIAssistantSettings()
        
        Task {
            try? FileManager.default.createDirectory(
                at: self.settingsDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            await self.loadSettings()
            await self.setupAutoSave()
        }
    }
    
    // MARK: - Accessing Settings
    
    /// Get current settings
    func getSettings() -> AIAssistantSettings {
        currentSettings
    }
    
    /// Get a specific setting by key path
    func getSetting<T>(_ keyPath: KeyPath<AIAssistantSettings, T>) -> T {
        currentSettings[keyPath: keyPath]
    }
    
    /// Update a specific setting by key path
    func updateSetting<T>(_ value: T, at keyPath: WritableKeyPath<AIAssistantSettings, T>) async {
        currentSettings[keyPath: keyPath] = value
        currentSettings.lastUpdated = Date()
        await notifySettingsChanged()
    }
    
    /// Batch update multiple settings
    func updateSettings(_ updates: (inout AIAssistantSettings) -> Void) async {
        updates(&currentSettings)
        currentSettings.lastUpdated = Date()
        await notifySettingsChanged()
    }
    
    /// Reset to default settings
    func resetToDefaults() async {
        currentSettings = AIAssistantSettings()
        await saveSettings()
        await notifySettingsChanged()
    }
    
    /// Partially reset specific categories
    func resetCategory(_ category: String) async {
        let defaults = AIAssistantSettings()
        
        switch category.lowercased() {
        case "search":
            currentSettings.searchProvider = defaults.searchProvider
            currentSettings.googleAPIKey = defaults.googleAPIKey
            currentSettings.bingAPIKey = defaults.bingAPIKey
            
        case "model":
            currentSettings.preferredModel = defaults.preferredModel
            currentSettings.downloadQuality = defaults.downloadQuality
            
        case "voice":
            currentSettings.voiceInputEnabled = defaults.voiceInputEnabled
            currentSettings.voiceOutputEnabled = defaults.voiceOutputEnabled
            
        case "hotkey":
            currentSettings.globalHotkeyKey = defaults.globalHotkeyKey
            currentSettings.globalHotkeyModifiers = defaults.globalHotkeyModifiers
            
        case "privacy":
            currentSettings.enableLogging = defaults.enableLogging
            currentSettings.storeSensitiveData = defaults.storeSensitiveData
            
        default:
            break
        }
        
        currentSettings.lastUpdated = Date()
        await saveSettings()
        await notifySettingsChanged()
    }
    
    // MARK: - Validation
    
    /// Validate current settings
    func validate() -> [(field: String, error: String)] {
        var errors: [(String, String)] = []
        
        if currentSettings.searchTimeout <= 0 {
            errors.append(("searchTimeout", "Search timeout must be positive"))
        }
        
        if currentSettings.audioOutputVolume < 0 || currentSettings.audioOutputVolume > 1 {
            errors.append(("audioOutputVolume", "Volume must be between 0 and 1"))
        }
        
        if currentSettings.maxConcurrentOperations < 1 {
            errors.append(("maxConcurrentOperations", "Must allow at least 1 concurrent operation"))
        }
        
        if currentSettings.temperatureSetting < 0 || currentSettings.temperatureSetting > 1 {
            errors.append(("temperatureSetting", "Temperature must be between 0 and 1"))
        }
        
        if currentSettings.topPSetting < 0 || currentSettings.topPSetting > 1 {
            errors.append(("topPSetting", "Top P must be between 0 and 1"))
        }
        
        if currentSettings.searchProvider == "custom" && currentSettings.customSearchURL?.isEmpty ?? true {
            errors.append(("customSearchURL", "Custom search URL required for custom provider"))
        }
        
        return errors
    }
    
    // MARK: - Import & Export
    
    /// Export settings as JSON string
    func exportSettings() throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(currentSettings)
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    /// Import settings from JSON string
    func importSettings(_ json: String) async throws {
        guard let data = json.data(using: .utf8) else {
            throw SettingsError.invalidFormat
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let imported = try decoder.decode(AIAssistantSettings.self, from: data)
        
        let validationErrors = validateImportedSettings(imported)
        if !validationErrors.isEmpty {
            throw SettingsError.validationFailed(validationErrors)
        }
        
        currentSettings = imported
        await saveSettings()
        await notifySettingsChanged()
    }
    
    /// Export settings to file
    func exportToFile(url: URL) throws {
        let json = try exportSettings()
        try json.write(to: url, atomically: true, encoding: .utf8)
    }
    
    /// Import settings from file
    func importFromFile(_ url: URL) async throws {
        let json = try String(contentsOf: url, encoding: .utf8)
        try await importSettings(json)
    }
    
    private func validateImportedSettings(_ settings: AIAssistantSettings) -> [(field: String, error: String)] {
        // Replace current temporarily to validate
        let original = currentSettings
        currentSettings = settings
        let errors = validate()
        currentSettings = original
        return errors
    }
    
    // MARK: - Feature Flags
    
    /// Check if a feature is enabled
    func isFeatureEnabled(_ feature: String) -> Bool {
        currentSettings.featureFlags[feature] ?? false
    }
    
    /// Set feature flag
    func setFeatureFlag(_ feature: String, enabled: Bool) async {
        currentSettings.featureFlags[feature] = enabled
        await saveSettings()
        await notifySettingsChanged()
    }
    
    /// Get all feature flags
    func getAllFeatureFlags() -> [String: Bool] {
        currentSettings.featureFlags
    }
    
    // MARK: - Persistence
    
    private func setupAutoSave() {
        autoSaveTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(autoSaveInterval * 1_000_000_000))
                if !Task.isCancelled {
                    await saveSettings()
                }
            }
        }
    }
    
    func saveSettings() async {
        let fileURL = settingsDirectory.appendingPathComponent(settingsFileName)
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(currentSettings)
            try data.write(to: fileURL)
        } catch {
            print("Failed to save settings: \(error)")
        }
    }
    
    private func loadSettings() async {
        let fileURL = settingsDirectory.appendingPathComponent(settingsFileName)
        
        do {
            guard fileManager.fileExists(atPath: fileURL.path) else {
                // First time setup - create default settings
                currentSettings = AIAssistantSettings()
                await saveSettings()
                return
            }
            
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            currentSettings = try decoder.decode(AIAssistantSettings.self, from: data)
            
            // Migrate old settings if needed
            await migrateSettingsIfNeeded()
        } catch {
            print("Failed to load settings: \(error), using defaults")
            currentSettings = AIAssistantSettings()
        }
    }
    
    private func migrateSettingsIfNeeded() async {
        // Handle version migrations here
        if currentSettings.settingsVersion < 1 {
            currentSettings.settingsVersion = 1
        }
    }
    
    // MARK: - Notifications
    
    private func notifySettingsChanged() async {
        let settings = currentSettings
        await MainActor.run {
            AIAssistantSettingsManager.settingsDidChange.send(settings)
        }
    }
    
    // MARK: - Cleanup
    
    /// Clear sensitive data
    func clearSensitiveData() async {
        currentSettings.googleAPIKey = nil
        currentSettings.bingAPIKey = nil
        currentSettings.customSearchAuthHeader = nil
        currentSettings.customSystemPrompt = nil
        
        await saveSettings()
        await notifySettingsChanged()
    }
    
    /// Delete all settings (factory reset)
    func deleteAllSettings() async {
        let fileURL = settingsDirectory.appendingPathComponent(settingsFileName)
        try? fileManager.removeItem(at: fileURL)
        currentSettings = AIAssistantSettings()
        await notifySettingsChanged()
    }
    
    deinit {
        autoSaveTask?.cancel()
    }
}

// MARK: - Error Types

enum SettingsError: LocalizedError {
    case invalidFormat
    case validationFailed([(field: String, error: String)])
    case saveFailure(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Settings format is invalid"
        case .validationFailed(let errors):
            let errorMessages = errors.map { "\($0.field): \($0.error)" }.joined(separator: ", ")
            return "Settings validation failed: \(errorMessages)"
        case .saveFailure(let reason):
            return "Failed to save settings: \(reason)"
        }
    }
}

// MARK: - TCA Integration

extension DependencyValues {
    var settingsManager: AIAssistantSettingsManager {
        get { self[SettingsManagerKey.self] }
        set { self[SettingsManagerKey.self] = newValue }
    }
}

private struct SettingsManagerKey: DependencyKey {
    static let liveValue = AIAssistantSettingsManager.shared
    static let testValue = AIAssistantSettingsManager.shared
}
