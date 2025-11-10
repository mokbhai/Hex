import Foundation
import AppKit

/// Handles opening URLs in the default web browser or specified browser
/// Supports opening search results and URLs from voice commands
actor BrowserIntegration {
    // MARK: - Types

    enum BrowserIntegrationError: LocalizedError {
        case failedToOpen(String)
        case invalidURL(String)
        case noBrowserAvailable
        case operationCancelled

        var errorDescription: String? {
            switch self {
            case .failedToOpen(let url):
                return "Failed to open URL: \(url)"
            case .invalidURL(let url):
                return "Invalid URL: \(url)"
            case .noBrowserAvailable:
                return "No web browser available"
            case .operationCancelled:
                return "Operation was cancelled"
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .failedToOpen:
                return "Try opening the URL in your browser manually"
            case .invalidURL:
                return "Please check the URL format"
            case .noBrowserAvailable:
                return "Install Safari or another web browser"
            case .operationCancelled:
                return "Try opening the URL again"
            }
        }
    }

    enum BrowserType {
        case default_
        case safari
        case chrome
        case firefox
        case edge

        var bundleIdentifier: String {
            switch self {
            case .default_:
                return "com.apple.Safari" // Safari is default
            case .safari:
                return "com.apple.Safari"
            case .chrome:
                return "com.google.Chrome"
            case .firefox:
                return "org.mozilla.firefox"
            case .edge:
                return "com.microsoft.edgeformac"
            }
        }

        var displayName: String {
            switch self {
            case .default_:
                return "Default Browser"
            case .safari:
                return "Safari"
            case .chrome:
                return "Chrome"
            case .firefox:
                return "Firefox"
            case .edge:
                return "Microsoft Edge"
            }
        }
    }

    // MARK: - Properties

    private let workspace = NSWorkspace.shared
    private var preferredBrowser: BrowserType = .default_

    // MARK: - Initialization

    init(preferredBrowser: BrowserType = .default_) {
        self.preferredBrowser = preferredBrowser
    }

    // MARK: - Opening URLs

    /// Open a URL in the default browser
    /// - Parameter urlString: The URL to open
    /// - Throws: BrowserIntegrationError if opening fails
    func openURL(_ urlString: String) async throws {
        try await openURL(urlString, in: preferredBrowser)
    }

    /// Open a URL in a specific browser
    /// - Parameters:
    ///   - urlString: The URL to open
    ///   - browser: The browser to use
    /// - Throws: BrowserIntegrationError if opening fails
    func openURL(_ urlString: String, in browser: BrowserType) async throws {
        // Validate URL format
        guard !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BrowserIntegrationError.invalidURL(urlString)
        }

        // Ensure URL has scheme
        var url = urlString
        if !url.lowercased().hasPrefix("http://") && !url.lowercased().hasPrefix("https://") {
            url = "https://\(url)"
        }

        guard let nsURL = URL(string: url) else {
            throw BrowserIntegrationError.invalidURL(urlString)
        }

        do {
            try await openNSURL(nsURL, in: browser)
        } catch {
            throw BrowserIntegrationError.failedToOpen(urlString)
        }
    }

    /// Open a URL in the default browser (async/await version)
    /// - Parameter url: The URL to open
    /// - Throws: BrowserIntegrationError if opening fails
    func openURL(_ url: URL) async throws {
        try await openNSURL(url, in: preferredBrowser)
    }

    // MARK: - Batch Operations

    /// Open multiple URLs in the browser
    /// - Parameters:
    ///   - urls: Array of URL strings to open
    ///   - delayBetween: Delay between opening each URL in seconds
    /// - Throws: BrowserIntegrationError if any URL fails to open
    func openURLs(_ urls: [String], delayBetween: TimeInterval = 0.5) async throws {
        for (index, urlString) in urls.enumerated() {
            if index > 0 {
                try await Task.sleep(nanoseconds: UInt64(delayBetween * 1_000_000_000))
            }
            try await openURL(urlString)
        }
    }

    /// Open search results in the browser
    /// - Parameters:
    ///   - results: Array of SearchResults to open
    ///   - maxResults: Maximum number of results to open (default: 5)
    /// - Throws: BrowserIntegrationError if opening fails
    func openSearchResults(_ results: [SearchResult], maxResults: Int = 5) async throws {
        let urls = results
            .prefix(maxResults)
            .filter { $0.source == .web }
            .map { $0.url }

        try await openURLs(urls)
    }

    // MARK: - Browser Detection

    /// Get available browsers on the system
    /// - Returns: Array of BrowserType for available browsers
    func getAvailableBrowsers() -> [BrowserType] {
        [.default_, .safari, .chrome, .firefox, .edge]
            .filter { workspace.absolutePathForApplication(withBundleIdentifier: $0.bundleIdentifier) != nil }
    }

    /// Check if a browser is available
    /// - Parameter browser: The browser to check
    /// - Returns: true if the browser is available
    func isBrowserAvailable(_ browser: BrowserType) -> Bool {
        workspace.absolutePathForApplication(withBundleIdentifier: browser.bundleIdentifier) != nil
    }

    /// Get the path to a browser application
    /// - Parameter browser: The browser to locate
    /// - Returns: Path to the browser app, or nil if not found
    func getBrowserPath(_ browser: BrowserType) -> String? {
        workspace.absolutePathForApplication(withBundleIdentifier: browser.bundleIdentifier)
    }

    // MARK: - Settings

    /// Set the preferred browser for opening URLs
    /// - Parameter browser: The browser to use by default
    func setPreferredBrowser(_ browser: BrowserType) {
        guard isBrowserAvailable(browser) else {
            return
        }
        preferredBrowser = browser
        UserDefaults.standard.set(browser.bundleIdentifier, forKey: "PreferredBrowser")
    }

    /// Get the current preferred browser
    /// - Returns: The preferred BrowserType
    func getPreferredBrowser() -> BrowserType {
        preferredBrowser
    }

    // MARK: - Private Methods

    private func openNSURL(_ url: URL, in browser: BrowserType) async throws {
        let config = NSWorkspaceOpenConfiguration()
        config.promptsUserIfNeeded = false

        guard isBrowserAvailable(browser) else {
            throw BrowserIntegrationError.noBrowserAvailable
        }

        guard let appURL = URL(fileURLWithPath: workspace.absolutePathForApplication(withBundleIdentifier: browser.bundleIdentifier) ?? "") else {
            throw BrowserIntegrationError.noBrowserAvailable
        }

        do {
            _ = try workspace.open([url], withApplicationAt: appURL, configuration: config)
        } catch {
            throw BrowserIntegrationError.failedToOpen(url.absoluteString)
        }
    }

    // MARK: - Convenience Methods

    /// Open a search query in the default search engine
    /// - Parameters:
    ///   - query: The search query
    ///   - searchEngine: The search engine to use (default: Google)
    /// - Throws: BrowserIntegrationError if opening fails
    func openSearch(_ query: String, engine: SearchEngine = .google) async throws {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let searchURL = engine.searchURL(for: encodedQuery)
        try await openURL(searchURL)
    }

    /// Open a GitHub repository
    /// - Parameter repo: The repository in "owner/repo" format
    /// - Throws: BrowserIntegrationError if opening fails
    func openGitHubRepo(_ repo: String) async throws {
        try await openURL("https://github.com/\(repo)")
    }

    /// Open a documentation URL
    /// - Parameter path: The path relative to Apple Developer docs
    /// - Throws: BrowserIntegrationError if opening fails
    func openAppleDocs(_ path: String) async throws {
        try await openURL("https://developer.apple.com/documentation/\(path)")
    }
}

// MARK: - Search Engine Enum

enum SearchEngine {
    case google
    case bing
    case duckduckgo
    case ecosia
    case custom(String)

    func searchURL(for query: String) -> String {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        switch self {
        case .google:
            return "https://www.google.com/search?q=\(encoded)"
        case .bing:
            return "https://www.bing.com/search?q=\(encoded)"
        case .duckduckgo:
            return "https://duckduckgo.com/?q=\(encoded)"
        case .ecosia:
            return "https://www.ecosia.org/search?q=\(encoded)"
        case .custom(let baseURL):
            return "\(baseURL)?q=\(encoded)"
        }
    }

    var displayName: String {
        switch self {
        case .google:
            return "Google"
        case .bing:
            return "Bing"
        case .duckduckgo:
            return "DuckDuckGo"
        case .ecosia:
            return "Ecosia"
        case .custom:
            return "Custom"
        }
    }
}

// MARK: - TCA Dependencies

import ComposableArchitecture

extension DependencyValues {
    var browserIntegration: BrowserIntegration {
        get { self[BrowserIntegrationKey.self] }
        set { self[BrowserIntegrationKey.self] = newValue }
    }
}

private enum BrowserIntegrationKey: DependencyKey {
    static let liveValue: BrowserIntegration = .init()

    static let previewValue: BrowserIntegration = .init()

    static let testValue: BrowserIntegration = .init()
}
