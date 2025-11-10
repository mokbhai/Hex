import SwiftUI
import ComposableArchitecture

/// Settings UI for customizing search providers, model selection, and assistant behavior
struct AIAssistantSettingsView: View {
    @State private var settings: AIAssistantSettings = .default
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedSearchProvider: SearchProvider = .google
    @State private var apiKey: String = ""
    @State private var customBaseURL: String = ""
    @State private var showSaveConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Search Provider Settings
                Section("Search Configuration") {
                    Picker("Search Provider", selection: $selectedSearchProvider) {
                        ForEach(SearchProvider.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .onChange(of: selectedSearchProvider) { _, newProvider in
                        settings.activeProvider = newProvider
                    }
                    
                    // Provider-specific configuration
                    if selectedSearchProvider == .custom {
                        TextField("Custom Base URL", text: $customBaseURL)
                            .textInputAutocapitalization(.none)
                            .keyboardType(.URL)
                        
                        TextField("API Key", text: $apiKey)
                            .textContentType(.password)
                    } else if selectedSearchProvider != .google {
                        SecureField("API Key", text: $apiKey)
                    }
                }
                
                // MARK: - Model Settings
                Section("AI Model Configuration") {
                    Picker("Model Size", selection: $settings.modelSize) {
                        ForEach(AIModelSize.allCases, id: \.self) { size in
                            Text(size.displayName).tag(size)
                        }
                    }
                    
                    Toggle("Enable Local Processing", isOn: $settings.enableLocalProcessing)
                        .help("Process requests locally without sending to remote servers")
                    
                    Toggle("Cache Responses", isOn: $settings.cacheResponses)
                        .help("Cache responses to improve performance")
                    
                    Stepper(
                        "Cache Size: \(settings.cacheSizeMB) MB",
                        value: $settings.cacheSizeMB,
                        in: 10...500,
                        step: 10
                    )
                }
                
                // MARK: - Feature Toggles
                Section("Features") {
                    Toggle("Voice Commands", isOn: $settings.enableVoiceCommands)
                    Toggle("Auto-Transcription", isOn: $settings.enableAutoTranscription)
                    Toggle("Contextual Awareness", isOn: $settings.enableContextAwareness)
                    Toggle("Command History", isOn: $settings.enableCommandHistory)
                    Toggle("Performance Metrics", isOn: $settings.enablePerformanceMetrics)
                }
                
                // MARK: - Privacy & Logging
                Section("Privacy & Logging") {
                    Toggle("Error Logging", isOn: $settings.enableErrorLogging)
                        .help("Log errors for debugging and improvement")
                    
                    Toggle("Analytics", isOn: $settings.enableAnalytics)
                        .help("Send usage analytics to improve the assistant")
                    
                    Toggle("Secure Storage", isOn: $settings.useSecureStorage)
                        .help("Encrypt sensitive data at rest")
                }
                
                // MARK: - Advanced
                Section("Advanced") {
                    Stepper(
                        "Request Timeout: \(settings.requestTimeoutSeconds)s",
                        value: $settings.requestTimeoutSeconds,
                        in: 5...60,
                        step: 5
                    )
                    
                    Stepper(
                        "Max Retries: \(settings.maxRetries)",
                        value: $settings.maxRetries,
                        in: 1...5,
                        step: 1
                    )
                    
                    Toggle("Debug Mode", isOn: $settings.debugMode)
                        .help("Enable verbose logging and debug output")
                }
                
                // MARK: - Actions
                Section {
                    Button(action: saveSettings) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                            Text("Save Settings")
                        }
                    }
                    .foregroundColor(.blue)
                    
                    Button(action: resetToDefaults, role: .destructive) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset to Defaults")
                        }
                    }
                    
                    Button(action: clearCache, role: .destructive) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear Cache")
                        }
                    }
                }
            }
            .navigationTitle("AI Assistant Settings")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showAlert.toggle() }) {
                        Image(systemName: "info.circle")
                    }
                    .help("Information about current settings")
                }
            }
            .alert("Settings Info", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(settingsInfoMessage)
            }
            .alert("Confirmation", isPresented: $showSaveConfirmation) {
                Button("Save", action: confirmSave)
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Save these settings? This will restart the assistant.")
            }
        }
        .onAppear(perform: loadCurrentSettings)
    }
    
    // MARK: - Private Methods
    
    private func loadCurrentSettings() {
        settings = AIAssistantSettings.load() ?? .default
        selectedSearchProvider = settings.activeProvider
    }
    
    private func saveSettings() {
        // Validate settings
        if selectedSearchProvider == .custom && customBaseURL.isEmpty {
            alertMessage = "Custom base URL is required for custom search provider"
            showAlert = true
            return
        }
        
        if (selectedSearchProvider == .bing || selectedSearchProvider == .custom) && apiKey.isEmpty {
            alertMessage = "API Key is required for \(selectedSearchProvider.displayName)"
            showAlert = true
            return
        }
        
        // Update settings with current values
        settings.activeProvider = selectedSearchProvider
        if !apiKey.isEmpty {
            settings.updateSearchAPIKey(apiKey, for: selectedSearchProvider)
        }
        if !customBaseURL.isEmpty && selectedSearchProvider == .custom {
            settings.customSearchBaseURL = customBaseURL
        }
        
        showSaveConfirmation = true
    }
    
    private func confirmSave() {
        settings.save()
        alertMessage = "Settings saved successfully. The assistant will restart to apply changes."
        showAlert = true
    }
    
    private func resetToDefaults() {
        settings = .default
        selectedSearchProvider = .google
        apiKey = ""
        customBaseURL = ""
        alertMessage = "Settings reset to defaults"
        showAlert = true
    }
    
    private func clearCache() {
        // Clear cache through PersistenceService
        do {
            try PersistenceService.shared.clearCache()
            alertMessage = "Cache cleared successfully"
        } catch {
            alertMessage = "Failed to clear cache: \(error.localizedDescription)"
        }
        showAlert = true
    }
    
    private var settingsInfoMessage: String {
        """
        Current Configuration:
        • Search Provider: \(selectedSearchProvider.displayName)
        • Model Size: \(settings.modelSize.displayName)
        • Local Processing: \(settings.enableLocalProcessing ? "Enabled" : "Disabled")
        • Voice Commands: \(settings.enableVoiceCommands ? "Enabled" : "Disabled")
        • Cache Size: \(settings.cacheSizeMB) MB
        • Request Timeout: \(settings.requestTimeoutSeconds)s
        
        All settings are stored securely on your device.
        """
    }
}

// MARK: - SearchProvider Extensions

extension SearchProvider {
    var displayName: String {
        switch self {
        case .google:
            return "Google Search"
        case .bing:
            return "Bing Search"
        case .custom:
            return "Custom API"
        }
    }
}

// MARK: - AIModelSize Enum

enum AIModelSize: String, CaseIterable, Codable {
    case small
    case medium
    case large
    
    var displayName: String {
        switch self {
        case .small:
            return "Small (Fast, Less Accurate)"
        case .medium:
            return "Medium (Balanced)"
        case .large:
            return "Large (Slow, More Accurate)"
        }
    }
}

// MARK: - Preview

#Preview {
    AIAssistantSettingsView()
}
