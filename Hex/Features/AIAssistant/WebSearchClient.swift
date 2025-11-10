import Foundation

/// WebSearchClient handles web search requests through custom APIs
///
/// Features:
/// - Web search query execution
/// - Result parsing and formatting
/// - Error handling and retries
/// - Rate limiting support
///
/// Used by User Story 2: Voice Information Search (T037)
public struct WebSearchClient {
    private let baseURL: String
    private let apiKey: String?
    private let session: URLSession

    public init(
        baseURL: String = "https://ser.jainparichay.online",
        apiKey: String? = nil,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.session = session
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

        // Construct search URL
        var components = URLComponents(string: "\(baseURL)/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
        ]

        guard let url = components?.url else {
            throw WebSearchError.invalidURL
        }

        // Make request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30

        // Add API key if provided
        if let apiKey = apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)

        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WebSearchError.networkError("Invalid response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 429 {
                throw WebSearchError.rateLimitExceeded
            }
            throw WebSearchError.networkError("Status code: \(httpResponse.statusCode)")
        }

        // Parse results
        return try parseSearchResults(data)
    }

    // MARK: - Parsing

    private func parseSearchResults(_ data: Data) throws -> [WebSearchResult] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        struct SearchResponse: Decodable {
            let results: [SearchResultItem]?
            let items: [SearchResultItem]?

            struct SearchResultItem: Decodable {
                let title: String?
                let url: String?
                let link: String?
                let snippet: String?
                let description: String?
                let position: Int?
            }
        }

        do {
            let response = try decoder.decode(SearchResponse.self, from: data)

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
            throw WebSearchError.parseError("Failed to parse results: \(error.localizedDescription)")
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
