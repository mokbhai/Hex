import Foundation

/// WebSearchClient handles web search requests through multiple search providers
///
/// Features:
/// - Multi-provider support (Google, Bing, custom APIs)
/// - Web search query execution
/// - Result parsing and formatting
/// - Error handling and retries
/// - Rate limiting support
/// - Provider configuration from SearchSettings
///
/// Used by User Story 2: Voice Information Search (T037, T046)
public struct WebSearchClient {
    private let baseURL: String
    private let apiKey: String?
    private let customHeader: String?
    private let session: URLSession
    private let provider: SearchSettings.SearchProvider

    public init(
        baseURL: String = "https://ser.jainparichay.online",
        apiKey: String? = nil,
        customHeader: String? = nil,
        provider: SearchSettings.SearchProvider = .google,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.customHeader = customHeader
        self.provider = provider
        self.session = session
    }

    /// Create WebSearchClient from SearchSettings
    /// - Parameters:
    ///   - settings: SearchSettings containing provider configuration
    ///   - session: URLSession to use (default: .shared)
    /// - Returns: Configured WebSearchClient
    public static func fromSettings(
        _ settings: SearchSettings,
        session: URLSession = .shared
    ) -> WebSearchClient {
        let credentials = settings.getActiveProviderCredentials()
        return WebSearchClient(
            baseURL: credentials.baseURL,
            apiKey: credentials.apiKey,
            customHeader: credentials.customHeader,
            provider: settings.selectedProvider,
            session: session
        )
    }

    // MARK: - Web Search

    /// Search the web for a query
    /// - Parameters:
    ///   - query: Search query string
    ///   - limit: Maximum number of results (default: 10)
    /// - Returns: Array of search results
    /// - Throws: WebSearchError if search fails
    public func search(query: String, limit: Int = 10) async throws -> [WebSearchResult] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw WebSearchError.emptyQuery
        }

        guard !apiKey.map({ $0.isEmpty }) ?? true else {
            throw WebSearchError.unauthorized
        }

        // Build request based on provider type
        let request = try buildRequest(query: query, limit: limit)

        // Make HTTP request
        let (data, response) = try await session.data(for: request)

        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WebSearchError.networkError("Invalid response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 429 {
                throw WebSearchError.rateLimitExceeded
            } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw WebSearchError.unauthorized
            }
            throw WebSearchError.networkError("Status code: \(httpResponse.statusCode)")
        }

        // Parse results based on provider type
        return try parseSearchResults(data, for: provider)
    }

    // MARK: - Request Building

    private func buildRequest(query: String, limit: Int) throws -> URLRequest {
        let url: URL

        switch provider {
        case .google:
            url = try buildGoogleURL(query: query, limit: limit)
        case .bing:
            url = try buildBingURL(query: query, limit: limit)
        case .custom:
            url = try buildCustomURL(query: query, limit: limit)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30

        // Add authentication headers based on provider and custom configuration
        addAuthenticationHeaders(to: &request)

        return request
    }

    private func buildGoogleURL(query: String, limit: Int) throws -> URL {
        var components = URLComponents(string: "\(baseURL)/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "num", value: String(min(limit, 10))), // Google max 10
        ]

        guard let url = components?.url else {
            throw WebSearchError.invalidURL
        }

        return url
    }

    private func buildBingURL(query: String, limit: Int) throws -> URL {
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "count", value: String(min(limit, 50))), // Bing max 50
        ]

        guard let url = components?.url else {
            throw WebSearchError.invalidURL
        }

        return url
    }

    private func buildCustomURL(query: String, limit: Int) throws -> URL {
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
        ]

        guard let url = components?.url else {
            throw WebSearchError.invalidURL
        }

        return url
    }

    private func addAuthenticationHeaders(to request: inout URLRequest) {
        guard let apiKey = apiKey else { return }

        // Use custom header if provided, otherwise use standard Authorization header
        if let customHeader = customHeader {
            request.setValue(apiKey, forHTTPHeaderField: customHeader)
        } else {
            // For Google and Bing, check if key should be in URL vs header
            switch provider {
            case .google:
                // Google uses API key in URL query parameter
                if var url = request.url, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                    if components.queryItems == nil {
                        components.queryItems = []
                    }
                    components.queryItems?.append(URLQueryItem(name: "key", value: apiKey))
                    request.url = components.url
                }
            case .bing:
                // Bing uses Ocp-Apim-Subscription-Key header
                request.setValue(apiKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
            case .custom:
                // Custom APIs typically use Bearer token
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
        }
    }

    // MARK: - Parsing

    private func parseSearchResults(_ data: Data, for provider: SearchSettings.SearchProvider) throws -> [WebSearchResult] {
        switch provider {
        case .google:
            return try parseGoogleResults(data)
        case .bing:
            return try parseBingResults(data)
        case .custom:
            return try parseCustomResults(data)
        }
    }

    private func parseGoogleResults(_ data: Data) throws -> [WebSearchResult] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        struct GoogleSearchResponse: Decodable {
            let items: [GoogleSearchItem]?

            struct GoogleSearchItem: Decodable {
                let title: String?
                let link: String?
                let snippet: String?
            }
        }

        do {
            let response = try decoder.decode(GoogleSearchResponse.self, from: data)
            let items = response.items ?? []

            return items.enumerated().map { index, item in
                WebSearchResult(
                    title: item.title ?? "Untitled",
                    url: item.link ?? "",
                    snippet: item.snippet ?? "",
                    rank: index + 1
                )
            }
        } catch {
            throw WebSearchError.parseError("Failed to parse Google results: \(error.localizedDescription)")
        }
    }

    private func parseBingResults(_ data: Data) throws -> [WebSearchResult] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        struct BingSearchResponse: Decodable {
            let webPages: BingWebPages?

            struct BingWebPages: Decodable {
                let value: [BingSearchItem]?

                struct BingSearchItem: Decodable {
                    let name: String?
                    let url: String?
                    let snippet: String?
                }
            }
        }

        do {
            let response = try decoder.decode(BingSearchResponse.self, from: data)
            let items = response.webPages?.value ?? []

            return items.enumerated().map { index, item in
                WebSearchResult(
                    title: item.name ?? "Untitled",
                    url: item.url ?? "",
                    snippet: item.snippet ?? "",
                    rank: index + 1
                )
            }
        } catch {
            throw WebSearchError.parseError("Failed to parse Bing results: \(error.localizedDescription)")
        }
    }

    private func parseCustomResults(_ data: Data) throws -> [WebSearchResult] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        struct CustomSearchResponse: Decodable {
            let results: [CustomSearchItem]?
            let items: [CustomSearchItem]?

            struct CustomSearchItem: Decodable {
                let title: String?
                let url: String?
                let link: String?
                let snippet: String?
                let description: String?
                let position: Int?
            }
        }

        do {
            let response = try decoder.decode(CustomSearchResponse.self, from: data)
            let items = response.results ?? response.items ?? []

            return items.enumerated().map { index, item in
                WebSearchResult(
                    title: item.title ?? "Untitled",
                    url: item.url ?? item.link ?? "",
                    snippet: item.snippet ?? item.description ?? "",
                    rank: item.position ?? index + 1
                )
            }
        } catch {
            throw WebSearchError.parseError("Failed to parse custom results: \(error.localizedDescription)")
        }
    }

    // MARK: - Result Formatting

    /// Format search results for display
    /// - Parameter results: Raw search results
    /// - Returns: Formatted result strings
    public static func formatResults(_ results: [WebSearchResult]) -> [String] {
        return results.enumerated().map { index, result in
            """
            \(index + 1). \(result.title)
               \(result.url)
               \(result.snippet)
            """
        }
    }
}

// MARK: - Result Types

public struct WebSearchResult: Equatable {
    public let title: String
    public let url: String
    public let snippet: String
    public let rank: Int

    public init(title: String, url: String, snippet: String, rank: Int) {
        self.title = title
        self.url = url
        self.snippet = snippet
        self.rank = rank
    }
}

// MARK: - Errors

public enum WebSearchError: LocalizedError {
    case emptyQuery
    case invalidURL
    case networkError(String)
    case parseError(String)
    case rateLimitExceeded
    case unauthorized

    public var errorDescription: String? {
        switch self {
        case .emptyQuery:
            return "Search query cannot be empty"
        case .invalidURL:
            return "Invalid search URL"
        case .networkError(let reason):
            return "Network error: \(reason)"
        case .parseError(let reason):
            return "Failed to parse results: \(reason)"
        case .rateLimitExceeded:
            return "Too many requests. Please try again later"
        case .unauthorized:
            return "API key is invalid or missing"
        }
    }
}

// MARK: - Mock Implementation

public struct WebSearchClientMock: Sendable {
    private let mockResults: [WebSearchResult]

    public init(mockResults: [WebSearchResult] = []) {
        self.mockResults = mockResults
    }

    public func search(query: String, limit: Int = 10) async throws -> [WebSearchResult] {
        return Array(mockResults.prefix(limit))
    }
}
