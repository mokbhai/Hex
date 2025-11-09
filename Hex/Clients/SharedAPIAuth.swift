import Foundation
import ComposableArchitecture

/// SharedAPIAuth provides unified authentication for external API calls
/// 
/// Supports:
/// - Basic Authentication (username:password)
/// - Bearer Token Authentication (API keys)
/// - Custom headers
/// - Token refresh/rotation
/// - Secure credential storage
/// 
/// Used by:
/// - User Story 2: Web search APIs (search.jainparichay.online, Google)
/// - Future: Other external service integrations
public struct SharedAPIAuth {
    // MARK: - Configuration

    /// Maximum time to cache API credentials
    public static let credentialCacheDuration: TimeInterval = 3600 // 1 hour

    /// Supported authentication methods
    public enum AuthMethod: Equatable {
        /// Basic authentication (username:password)
        case basic(username: String, password: String)
        /// Bearer token (API key)
        case bearer(token: String)
        /// Custom header
        case custom(header: String, value: String)
        /// No authentication
        case none
    }

    // MARK: - Authentication Management

    /// Get authentication header for a request
    /// - Parameter method: Authentication method to use
    /// - Returns: Tuple of (header name, header value)
    public static func getAuthHeader(for method: AuthMethod) -> (String, String)? {
        switch method {
        case .basic(let username, let password):
            return ("Authorization", basicAuthHeader(username: username, password: password))

        case .bearer(let token):
            return ("Authorization", "Bearer \(token)")

        case .custom(let header, let value):
            return (header, value)

        case .none:
            return nil
        }
    }

    /// Create Basic authentication header
    /// - Parameters:
    ///   - username: Username for basic auth
    ///   - password: Password for basic auth
    /// - Returns: Formatted Basic auth header value
    private static func basicAuthHeader(username: String, password: String) -> String {
        let credentials = "\(username):\(password)"
        guard let encodedCredentials = credentials.data(using: .utf8)?.base64EncodedString() else {
            return ""
        }
        return "Basic \(encodedCredentials)"
    }

    // MARK: - Credential Storage

    /// Store API credentials securely
    /// - Parameters:
    ///   - service: Service identifier (e.g., "search.jainparichay.online")
    ///   - method: Authentication method to store
    public static func storeCredentials(_ method: AuthMethod, for service: String) {
        // TODO: T016 Credential Storage
        // 1. Use Keychain for secure storage (macOS)
        // 2. Store service name, auth method type, and credentials
        // 3. Handle errors gracefully
        // 4. Log access for audit trail
    }

    /// Retrieve API credentials
    /// - Parameter service: Service identifier
    /// - Returns: Authentication method, or nil if not found
    public static func retrieveCredentials(for service: String) -> AuthMethod? {
        // TODO: T016 Credential Retrieval
        // 1. Query Keychain
        // 2. Deserialize stored credentials
        // 3. Validate not expired
        // 4. Return or refresh if needed
        return nil
    }

    /// Delete stored credentials
    /// - Parameter service: Service identifier
    public static func deleteCredentials(for service: String) {
        // TODO: T016 Credential Deletion
        // 1. Query Keychain
        // 2. Delete entry
        // 3. Verify deletion
    }

    // MARK: - Token Refresh

    /// Check if token needs refresh
    /// - Parameter token: Bearer token
    /// - Returns: True if token should be refreshed
    public static func shouldRefreshToken(_ token: String) -> Bool {
        // TODO: T016 Token Validation
        // 1. Parse JWT if applicable
        // 2. Check expiration time
        // 3. Refresh if within 5 minutes of expiry
        return false
    }

    /// Refresh authentication token
    /// - Parameters:
    ///   - service: Service identifier
    ///   - refreshMethod: Method to refresh (varies by service)
    /// - Returns: New authentication method
    public static func refreshToken(
        for service: String,
        refreshMethod: @escaping () async throws -> AuthMethod
    ) async throws -> AuthMethod {
        // TODO: T016 Token Refresh
        // 1. Call refresh method (service-specific)
        // 2. Validate new credentials
        // 3. Store new credentials
        // 4. Return new method
        return try await refreshMethod()
    }

    // MARK: - Request Preparation

    /// Prepare URLRequest with authentication
    /// - Parameters:
    ///   - url: Endpoint URL
    ///   - method: HTTP method (GET, POST, etc.)
    ///   - authMethod: Authentication to apply
    /// - Returns: URLRequest with auth headers set
    public static func prepareRequest(
        url: URL,
        method: String = "GET",
        authMethod: AuthMethod
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method

        if let (headerName, headerValue) = getAuthHeader(for: authMethod) {
            request.setValue(headerValue, forHTTPHeaderField: headerName)
        }

        return request
    }

    // MARK: - Service-Specific Authentication

    /// Get authenticated client for search service
    /// - Returns: URLSession configured with search API credentials
    public static func getSearchServiceSession() -> URLSession {
        // TODO: T016 Search Service Auth
        // 1. Retrieve credentials for search service
        // 2. Create URLSession with auth headers
        // 3. Handle credential rotation
        return URLSession.shared
    }

    /// Get authenticated client for a generic service
    /// - Parameter service: Service identifier
    /// - Returns: URLSession configured with service credentials
    public static func getAuthenticatedSession(for service: String) -> URLSession {
        // TODO: T016 Generic Service Auth
        // 1. Retrieve credentials for service
        // 2. Create URLSession delegate with auth handling
        // 3. Implement challenge responses
        return URLSession.shared
    }

    // MARK: - Error Handling

    /// Handle authentication errors
    /// - Parameter error: Error from API call
    /// - Returns: Recoverable error with suggestions
    public static func handleAuthError(_ error: Error) -> AuthError {
        // TODO: T016 Error Handling
        // 1. Identify error type (401, 403, network, etc.)
        // 2. Suggest recovery (refresh token, re-auth, etc.)
        // 3. Return user-friendly error message

        return AuthError.authenticationFailed("Authentication failed")
    }

    // MARK: - Audit Trail

    /// Log authentication attempt
    /// - Parameters:
    ///   - service: Service being accessed
    ///   - method: Authentication method used
    ///   - success: Whether auth succeeded
    public static func logAuthAttempt(
        service: String,
        method: AuthMethod,
        success: Bool
    ) {
        // TODO: T016 Audit Logging
        // 1. Create audit record
        // 2. Log service, method type, timestamp, success
        // 3. Don't log actual credentials
        // 4. Store for compliance
    }

    /// Get authentication audit log
    /// - Returns: Recent authentication attempts
    public static func getAuditLog() -> [AuthAuditRecord] {
        // TODO: Query audit log
        return []
    }
}

// MARK: - Supporting Types

/// Authentication errors
public enum AuthError: LocalizedError, Equatable {
    case authenticationFailed(String)
    case credentialsMissing
    case tokenExpired
    case invalidCredentials
    case keyChainError(String)
    case networkError(String)

    public var errorDescription: String? {
        switch self {
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason)"
        case .credentialsMissing:
            return "Credentials not configured"
        case .tokenExpired:
            return "Authentication token expired"
        case .invalidCredentials:
            return "Invalid credentials"
        case .keyChainError(let reason):
            return "Keychain error: \(reason)"
        case .networkError(let reason):
            return "Network error: \(reason)"
        }
    }
}

/// Audit record for authentication
public struct AuthAuditRecord: Equatable {
    public let timestamp: Date
    public let service: String
    public let methodType: String
    public let success: Bool
    public let error: String?

    public init(
        timestamp: Date = Date(),
        service: String,
        methodType: String,
        success: Bool,
        error: String? = nil
    ) {
        self.timestamp = timestamp
        self.service = service
        self.methodType = methodType
        self.success = success
        self.error = error
    }
}

/// Credential validation result
public struct CredentialValidation: Equatable {
    public let isValid: Bool
    public let expiresAt: Date?
    public let refreshRequired: Bool
    public let error: String?

    public init(
        isValid: Bool,
        expiresAt: Date? = nil,
        refreshRequired: Bool = false,
        error: String? = nil
    ) {
        self.isValid = isValid
        self.expiresAt = expiresAt
        self.refreshRequired = refreshRequired
        self.error = error
    }
}
