import Foundation
import ComposableArchitecture

/// Settings for customizable search providers and configurations
/// Allows users to select between different search services (Google, Bing, custom)
/// and configure API credentials
///
/// Used by User Story 2: Voice Information Search (T046)
struct SearchSettings: Codable, Equatable {
    // MARK: - Search Provider Configuration

    /// Supported search provider types
    enum SearchProvider: String, Codable, Equatable, CaseIterable, Identifiable {
        case google = "google"
        case bing = "bing"
        case custom = "custom"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .google:
                return "Google"
            case .bing:
                return "Bing"
            case .custom:
                return "Custom API"
            }
        }

        var description: String {
            switch self {
            case .google:
                return "Search using Google Custom Search API"
            case .bing:
                return "Search using Bing Web Search API"
            case .custom:
                return "Use a custom search API endpoint"
            }
        }

        var requiresAPIKey: Bool {
            switch self {
            case .google, .bing, .custom:
                return true
            }
        }
    }

    /// Configuration for a specific search provider
    struct ProviderConfig: Codable, Equatable {
        let provider: SearchProvider
        var apiKey: String?
        var baseURL: String?
        var customHeader: String? // For custom API header key (e.g., "X-API-Key")
        var isEnabled: Bool = true

        enum CodingKeys: String, CodingKey {
            case provider
            case apiKey
            case baseURL
            case customHeader
            case isEnabled
        }

        init(
            provider: SearchProvider,
            apiKey: String? = nil,
            baseURL: String? = nil,
            customHeader: String? = nil,
            isEnabled: Bool = true
        ) {
            self.provider = provider
            self.apiKey = apiKey
            self.baseURL = baseURL
            self.customHeader = customHeader
            self.isEnabled = isEnabled
        }

        /// Validate provider configuration
        /// - Returns: true if configuration is complete and valid
        func isValid() -> Bool {
            guard provider.requiresAPIKey else { return true }
            
            switch provider {
            case .google, .bing:
                // Requires API key, optionally custom base URL
                return !((apiKey ?? "").isEmpty)
            case .custom:
                // Requires both API key and base URL
                return !((apiKey ?? "").isEmpty) && !((baseURL ?? "").isEmpty)
            }
        }

        /// Get default base URL for provider
        static func defaultBaseURL(for provider: SearchProvider) -> String {
            switch provider {
            case .google:
                return "https://www.googleapis.com/customsearch/v1"
            case .bing:
                return "https://api.bing.microsoft.com/v7.0/search"
            case .custom:
                return "" // User must provide
            }
        }

        /// Get default header key for provider
        static func defaultHeaderKey(for provider: SearchProvider) -> String? {
            switch provider {
            case .google, .bing:
                return nil // Use standard Authorization header
            case .custom:
                return "X-API-Key" // Customizable
            }
        }
    }

    // MARK: - Properties

    /// Currently selected search provider
    var selectedProvider: SearchProvider = .google

    /// Configurations for each provider
    var providerConfigs: [SearchProvider: ProviderConfig] = [
        .google: ProviderConfig(provider: .google),
        .bing: ProviderConfig(provider: .bing),
        .custom: ProviderConfig(provider: .custom),
    ]

    /// Enable/disable web search feature
    var webSearchEnabled: Bool = true

    /// Enable/disable local file search feature
    var localSearchEnabled: Bool = true

    /// Maximum results per search
    var maxResultsPerSearch: Int = 10

    /// Search timeout in seconds
    var searchTimeout: TimeInterval = 30

    /// Enable result caching
    var enableResultCaching: Bool = true

    /// Cache expiration time in hours
    var cacheExpirationHours: Int = 24

    // MARK: - Coding

    enum CodingKeys: String, CodingKey {
        case selectedProvider
        case providerConfigs
        case webSearchEnabled
        case localSearchEnabled
        case maxResultsPerSearch
        case searchTimeout
        case enableResultCaching
        case cacheExpirationHours
    }

    // MARK: - Initialization

    init(
        selectedProvider: SearchProvider = .google,
        webSearchEnabled: Bool = true,
        localSearchEnabled: Bool = true,
        maxResultsPerSearch: Int = 10,
        searchTimeout: TimeInterval = 30,
        enableResultCaching: Bool = true,
        cacheExpirationHours: Int = 24
    ) {
        self.selectedProvider = selectedProvider
        self.webSearchEnabled = webSearchEnabled
        self.localSearchEnabled = localSearchEnabled
        self.maxResultsPerSearch = maxResultsPerSearch
        self.searchTimeout = searchTimeout
        self.enableResultCaching = enableResultCaching
        self.cacheExpirationHours = cacheExpirationHours

        // Initialize default provider configs
        self.providerConfigs = [
            .google: ProviderConfig(provider: .google),
            .bing: ProviderConfig(provider: .bing),
            .custom: ProviderConfig(provider: .custom),
        ]
    }

    // Custom decoder for backwards compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        selectedProvider = try container.decodeIfPresent(
            SearchProvider.self,
            forKey: .selectedProvider
        ) ?? .google

        providerConfigs = try container.decodeIfPresent(
            [SearchProvider: ProviderConfig].self,
            forKey: .providerConfigs
        ) ?? [
            .google: ProviderConfig(provider: .google),
            .bing: ProviderConfig(provider: .bing),
            .custom: ProviderConfig(provider: .custom),
        ]

        webSearchEnabled = try container.decodeIfPresent(Bool.self, forKey: .webSearchEnabled) ?? true
        localSearchEnabled = try container.decodeIfPresent(Bool.self, forKey: .localSearchEnabled) ?? true
        maxResultsPerSearch = try container.decodeIfPresent(Int.self, forKey: .maxResultsPerSearch) ?? 10
        searchTimeout = try container.decodeIfPresent(TimeInterval.self, forKey: .searchTimeout) ?? 30
        enableResultCaching = try container.decodeIfPresent(Bool.self, forKey: .enableResultCaching) ?? true
        cacheExpirationHours = try container.decodeIfPresent(Int.self, forKey: .cacheExpirationHours) ?? 24
    }

    // MARK: - Configuration Access

    /// Get the active provider configuration
    /// - Returns: ProviderConfig for the selected provider, or nil if not configured
    func getActiveProviderConfig() -> ProviderConfig? {
        return providerConfigs[selectedProvider]
    }

    /// Get provider configuration by type
    /// - Parameter provider: The provider type to get config for
    /// - Returns: ProviderConfig or nil if not found
    func getProviderConfig(for provider: SearchProvider) -> ProviderConfig? {
        return providerConfigs[provider]
    }

    /// Set provider configuration
    /// - Parameters:
    ///   - config: The new configuration
    mutating func setProviderConfig(_ config: ProviderConfig) {
        providerConfigs[config.provider] = config
    }

    /// Check if can search with current configuration
    /// - Returns: true if web search is enabled and active provider is configured
    func canSearch() -> Bool {
        guard webSearchEnabled else { return false }
        guard let activeConfig = getActiveProviderConfig() else { return false }
        return activeConfig.isEnabled && activeConfig.isValid()
    }

    /// Check if can perform local search
    /// - Returns: true if local search is enabled
    func canLocalSearch() -> Bool {
        return localSearchEnabled
    }

    /// Check if can perform combined search (web + local)
    /// - Returns: true if both web and local search are enabled
    func canCombinedSearch() -> Bool {
        return canSearch() && canLocalSearch()
    }

    // MARK: - Validation

    /// Validate that at least one search method is available
    /// - Returns: (isValid, errorMessage)
    func validateSearchConfiguration() -> (isValid: Bool, errorMessage: String?) {
        if !webSearchEnabled && !localSearchEnabled {
            return (false, "At least one search method must be enabled")
        }

        if webSearchEnabled {
            if let activeConfig = getActiveProviderConfig() {
                if !activeConfig.isValid() {
                    let providerName = activeConfig.provider.displayName
                    return (false, "\(providerName) is not properly configured")
                }
            } else {
                return (false, "Selected search provider is not configured")
            }
        }

        return (true, nil)
    }

    // MARK: - Migration

    /// Create search settings from existing HexSettings
    /// - Parameter hexSettings: Existing HexSettings instance
    /// - Returns: SearchSettings with default values
    static func migrateFromHexSettings(_ hexSettings: HexSettings) -> SearchSettings {
        return SearchSettings()
    }
}

// MARK: - TCA Dependency Integration

extension SearchSettings {
    /// Create provider configuration for web search client initialization
    /// - Returns: Tuple of (baseURL, apiKey, customHeader)
    func getActiveProviderCredentials() -> (baseURL: String, apiKey: String?, customHeader: String?) {
        guard let config = getActiveProviderConfig() else {
            return (baseURL: ProviderConfig.defaultBaseURL(for: selectedProvider), apiKey: nil, customHeader: nil)
        }

        let baseURL = config.baseURL ?? ProviderConfig.defaultBaseURL(for: config.provider)
        let customHeader = config.customHeader ?? ProviderConfig.defaultHeaderKey(for: config.provider)

        return (baseURL: baseURL, apiKey: config.apiKey, customHeader: customHeader)
    }
}

// MARK: - Dependency Value Extension

extension SharedReaderKey
    where Self == FileStorageKey<SearchSettings>.Default
{
    static var searchSettings: Self {
        Self[
            .fileStorage(URL.documentsDirectory.appending(component: "hex_search_settings.json")),
            default: .init()
        ]
    }
}
