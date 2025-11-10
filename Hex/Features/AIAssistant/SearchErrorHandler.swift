import Foundation
import ComposableArchitecture

/// Handles errors from search operations with recovery strategies
/// Manages network failures, API errors, and user-facing error messages
struct SearchErrorHandler {
    // MARK: - Types

    enum SearchErrorCategory {
        case networkError       // Connection issues
        case apiError          // API returned error
        case invalidInput      // Malformed query
        case timeout           // Request timeout
        case rateLimited       // API rate limit exceeded
        case unauthorized      // Authentication failed
        case notFound          // No results or resource not found
        case serverError       // Server-side error (5xx)
        case unknown           // Unknown error

        var retryable: Bool {
            switch self {
            case .networkError, .timeout, .rateLimited, .serverError:
                return true
            case .invalidInput, .unauthorized, .notFound:
                return false
            case .apiError, .unknown:
                return true // Retry with caution
            }
        }

        var suggestedDelay: TimeInterval {
            switch self {
            case .rateLimited:
                return 60 // Wait 1 minute for rate limit
            case .serverError:
                return 5 // Exponential backoff handled by retry logic
            case .timeout, .networkError:
                return 2 // Short delay before retry
            default:
                return 0
            }
        }
    }

    struct SearchError: Error, LocalizedError {
        let category: SearchErrorCategory
        let message: String
        let originalError: Error?
        let timestamp: Date
        let retryCount: Int

        var errorDescription: String? {
            message
        }

        var recoverySuggestion: String? {
            switch category {
            case .networkError:
                return "Check your internet connection and try again"
            case .apiError:
                return "The search service had an issue. Please try again."
            case .invalidInput:
                return "Please refine your search query and try again"
            case .timeout:
                return "The search took too long. Please try again."
            case .rateLimited:
                return "Too many requests. Please wait a moment and try again."
            case .unauthorized:
                return "Authentication failed. Check your API credentials."
            case .notFound:
                return "No results found for this search. Try different keywords."
            case .serverError:
                return "The search service is temporarily unavailable. Please try again later."
            case .unknown:
                return "An unexpected error occurred. Please try again."
            }
        }

        var failureReason: String? {
            "Search failed: \(message)"
        }
    }

    struct ErrorContext {
        let query: String
        let searchType: SearchType
        let timestamp: Date
        let retryAttempt: Int
        var lastError: SearchError?

        enum SearchType {
            case web
            case local
            case combined
        }
    }

    struct RetryConfig {
        let maxAttempts: Int
        let initialDelay: TimeInterval
        let maxDelay: TimeInterval
        let backoffMultiplier: Double

        static let `default` = RetryConfig(
            maxAttempts: 3,
            initialDelay: 1.0,
            maxDelay: 30.0,
            backoffMultiplier: 2.0
        )
    }

    // MARK: - Properties

    private let retryConfig: RetryConfig
    private var errorLog: [SearchError] = []
    private let maxLogSize = 100

    // MARK: - Initialization

    init(retryConfig: RetryConfig = .default) {
        self.retryConfig = retryConfig
    }

    // MARK: - Error Classification

    /// Classify an error from WebSearchClient
    /// - Parameter error: The error from web search
    /// - Returns: Classified SearchError
    func classifyWebSearchError(_ error: Error, query: String) -> SearchError {
        if let urlError = error as? URLError {
            let category: SearchErrorCategory
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                category = .networkError
            case .timedOut, .dataLengthExceedsMaximum:
                category = .timeout
            default:
                category = .networkError
            }
            return SearchError(
                category: category,
                message: "Web search failed: \(urlError.localizedDescription)",
                originalError: error,
                timestamp: Date(),
                retryCount: 0
            )
        }

        if let decodingError = error as? DecodingError {
            return SearchError(
                category: .apiError,
                message: "Invalid response from search service",
                originalError: error,
                timestamp: Date(),
                retryCount: 0
            )
        }

        return SearchError(
            category: .unknown,
            message: "Search failed: \(error.localizedDescription)",
            originalError: error,
            timestamp: Date(),
            retryCount: 0
        )
    }

    /// Classify an error from LocalFileSearcher
    /// - Parameter error: The error from file search
    /// - Returns: Classified SearchError
    func classifyLocalSearchError(_ error: Error, query: String) -> SearchError {
        let category: SearchErrorCategory
        let message: String

        if let ioError = error as? NSError {
            switch ioError.code {
            case NSFileReadNoPermissionError:
                category = .unauthorized
                message = "Permission denied accessing files"
            case NSFileReadNoSuchFileError:
                category = .notFound
                message = "Search directory not found"
            default:
                category = .unknown
                message = "File search error: \(ioError.localizedDescription)"
            }
        } else {
            category = .unknown
            message = "File search failed: \(error.localizedDescription)"
        }

        return SearchError(
            category: category,
            message: message,
            originalError: error,
            timestamp: Date(),
            retryCount: 0
        )
    }

    /// Classify an HTTP status code error
    /// - Parameters:
    ///   - statusCode: The HTTP status code
    ///   - responseBody: Optional response body for context
    /// - Returns: Classified SearchError
    func classifyHTTPError(statusCode: Int, responseBody: String? = nil) -> SearchError {
        let category: SearchErrorCategory
        let message: String

        switch statusCode {
        case 400:
            category = .invalidInput
            message = "Invalid search query"
        case 401, 403:
            category = .unauthorized
            message = "Authentication failed for search service"
        case 404:
            category = .notFound
            message = "Search service endpoint not found"
        case 429:
            category = .rateLimited
            message = "Search service rate limit exceeded"
        case 500...599:
            category = .serverError
            message = "Search service error (status: \(statusCode))"
        default:
            category = .apiError
            message = "Search failed with status \(statusCode)"
        }

        return SearchError(
            category: category,
            message: message,
            originalError: nil,
            timestamp: Date(),
            retryCount: 0
        )
    }

    // MARK: - Recovery Strategies

    /// Determine if an error should be retried
    /// - Parameters:
    ///   - error: The SearchError to evaluate
    ///   - context: The error context
    /// - Returns: true if should retry
    func shouldRetry(_ error: SearchError, context: ErrorContext) -> Bool {
        guard error.category.retryable else {
            return false
        }
        return context.retryAttempt < retryConfig.maxAttempts
    }

    /// Calculate delay before retry with exponential backoff
    /// - Parameters:
    ///   - attempt: The retry attempt number (0-based)
    ///   - error: The error that triggered retry
    /// - Returns: Time to wait before retry
    func calculateRetryDelay(attempt: Int, error: SearchError) -> TimeInterval {
        let baseSuggestedDelay = error.category.suggestedDelay
        let exponentialDelay = retryConfig.initialDelay * pow(retryConfig.backoffMultiplier, Double(attempt))

        let maxDelay = max(baseSuggestedDelay, retryConfig.maxDelay)
        return min(exponentialDelay, maxDelay)
    }

    // MARK: - Error Handling

    /// Handle a search error with recovery logic
    /// - Parameters:
    ///   - error: The SearchError to handle
    ///   - context: The error context
    ///   - retryHandler: Closure to execute if retry should occur
    /// - Returns: Recovery result
    func handleError(
        _ error: SearchError,
        context: ErrorContext,
        retryHandler: @escaping (TimeInterval) async -> Void
    ) async {
        // Log error
        logError(error)

        // Determine recovery action
        if shouldRetry(error, context: context) {
            let delay = calculateRetryDelay(attempt: context.retryAttempt, error: error)
            print("Will retry search after \(delay)s delay")
            await retryHandler(delay)
        } else {
            print("Search failed - no more retries available")
        }
    }

    /// Get user-friendly error message
    /// - Parameter error: The SearchError
    /// - Returns: Message suitable for display to user
    func getUserFriendlyMessage(_ error: SearchError) -> String {
        switch error.category {
        case .networkError:
            return "Connection error. Please check your internet."
        case .apiError:
            return "Search service temporary issue. Try again."
        case .invalidInput:
            return "Please try a different search query."
        case .timeout:
            return "Search took too long. Try again."
        case .rateLimited:
            return "Too many searches. Please wait."
        case .unauthorized:
            return "Search access denied. Check credentials."
        case .notFound:
            return "No results found. Try different keywords."
        case .serverError:
            return "Search service unavailable. Try later."
        case .unknown:
            return "Search failed. Please try again."
        }
    }

    // MARK: - Error Logging

    /// Log an error for debugging
    /// - Parameter error: The SearchError to log
    mutating func logError(_ error: SearchError) {
        errorLog.append(error)

        // Keep log size manageable
        if errorLog.count > maxLogSize {
            errorLog.removeFirst()
        }
    }

    /// Get error log
    /// - Returns: Array of logged errors
    func getErrorLog() -> [SearchError] {
        errorLog
    }

    /// Clear error log
    mutating func clearErrorLog() {
        errorLog.removeAll()
    }

    /// Get error statistics
    /// - Returns: Dictionary with error category counts
    func getErrorStatistics() -> [String: Int] {
        var stats: [String: Int] = [:]
        for error in errorLog {
            let key = String(describing: error.category)
            stats[key, default: 0] += 1
        }
        return stats
    }

    // MARK: - Error Chain Handling

    /// Handle multiple search errors (web + local)
    /// - Parameters:
    ///   - webError: Error from web search, if any
    ///   - localError: Error from local search, if any
    /// - Returns: Consolidated error message
    func handleMultipleErrors(webError: SearchError?, localError: SearchError?) -> String {
        var messages: [String] = []

        if let webError = webError {
            messages.append("Web: \(getUserFriendlyMessage(webError))")
        }

        if let localError = localError {
            messages.append("Files: \(getUserFriendlyMessage(localError))")
        }

        if messages.isEmpty {
            return "Search completed with no results"
        }

        return messages.joined(separator: "\n")
    }

    // MARK: - Telemetry

    /// Create telemetry entry for error
    /// - Parameter error: The SearchError
    /// - Returns: Dictionary suitable for logging/analytics
    func getTelemetryEntry(_ error: SearchError) -> [String: Any] {
        [
            "errorCategory": String(describing: error.category),
            "timestamp": error.timestamp.timeIntervalSince1970,
            "retryCount": error.retryCount,
            "message": error.message,
            "isRetryable": error.category.retryable,
        ]
    }
}

// MARK: - TCA Integration

extension DependencyValues {
    var searchErrorHandler: SearchErrorHandler {
        get { self[SearchErrorHandlerKey.self] }
        set { self[SearchErrorHandlerKey.self] = newValue }
    }
}

private enum SearchErrorHandlerKey: DependencyKey {
    static let liveValue = SearchErrorHandler()
    static let previewValue = SearchErrorHandler()
    static let testValue = SearchErrorHandler()
}
