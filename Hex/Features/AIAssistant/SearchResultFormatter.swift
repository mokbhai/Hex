import Foundation

/// Formats search results for display and voice feedback
/// Handles consistent formatting of web and local file search results
struct SearchResultFormatter {
    // MARK: - Types

    enum FormatStyle {
        case brief       // One-liner summary
        case detailed    // Full result with snippet
        case numbered    // Numbered list for voice readout
        case markdown    // Markdown formatted
    }

    // MARK: - Result Formatting

    /// Format a single search result
    /// - Parameters:
    ///   - result: The SearchResult to format
    ///   - style: The desired formatting style
    /// - Returns: Formatted string representation
    func format(_ result: SearchResult, style: FormatStyle = .detailed) -> String {
        switch style {
        case .brief:
            return formatBrief(result)
        case .detailed:
            return formatDetailed(result)
        case .numbered:
            return formatNumbered(result, index: 1)
        case .markdown:
            return formatMarkdown(result)
        }
    }

    /// Format multiple search results
    /// - Parameters:
    ///   - results: Array of SearchResults to format
    ///   - style: The desired formatting style
    /// - Returns: Formatted string representation of all results
    func formatResults(_ results: [SearchResult], style: FormatStyle = .detailed) -> String {
        switch style {
        case .brief:
            return results.map(formatBrief).joined(separator: "\n")
        case .detailed:
            return results.map(formatDetailed).joined(separator: "\n\n---\n\n")
        case .numbered:
            return results.enumerated()
                .map { index, result in formatNumbered(result, index: index + 1) }
                .joined(separator: "\n\n")
        case .markdown:
            return results.map(formatMarkdown).joined(separator: "\n\n")
        }
    }

    // MARK: - Private Formatting Methods

    private func formatBrief(_ result: SearchResult) -> String {
        switch result.source {
        case .web:
            return "\(result.title) - \(result.url)"
        case .local:
            return "\(result.title) (\(result.fileType ?? "file"))"
        }
    }

    private func formatDetailed(_ result: SearchResult) -> String {
        var output = result.title.uppercased()
        output += "\n"

        if result.source == .web {
            output += "🌐 \(result.url)\n"
        } else {
            output += "📁 \(result.url)\n"
        }

        if let snippet = result.snippet, !snippet.isEmpty {
            output += "\n\(snippet)\n"
        }

        if let relevance = result.relevance {
            let relevancePercent = Int(relevance * 100)
            output += "\nRelevance: \(relevancePercent)%"
        }

        if result.source == .local, let fileType = result.fileType {
            output += " | Type: \(fileType)"
        }

        return output
    }

    private func formatNumbered(_ result: SearchResult, index: Int) -> String {
        let titleLine = "\(index). \(result.title)"

        if let snippet = result.snippet, !snippet.isEmpty {
            let cleanSnippet = snippet.trimmingCharacters(in: .whitespacesAndNewlines)
            return "\(titleLine)\n   \(cleanSnippet)"
        }

        return titleLine
    }

    private func formatMarkdown(_ result: SearchResult) -> String {
        var output = "### \(result.title)\n\n"

        let icon = result.source == .web ? "🌐" : "📁"
        output += "[\(icon) \(result.displayURL)]()\n\n"

        if let snippet = result.snippet, !snippet.isEmpty {
            output += "> \(snippet)\n\n"
        }

        if let relevance = result.relevance {
            let relevancePercent = Int(relevance * 100)
            output += "**Relevance:** \(relevancePercent)%"
        }

        return output
    }

    // MARK: - Voice Feedback Formatting

    /// Format result for voice readout
    /// - Parameter result: The SearchResult to format for voice
    /// - Returns: String optimized for text-to-speech
    func formatForVoice(_ result: SearchResult) -> String {
        switch result.source {
        case .web:
            let title = result.title.replacingOccurrences(of: "&", with: "and")
            let snippet = (result.snippet ?? "").prefix(100).trimmingCharacters(in: .whitespacesAndNewlines)
            
            if snippet.isEmpty {
                return "\(title). From \(extractDomain(result.url))."
            } else {
                return "\(title). \(snippet). From \(extractDomain(result.url))."
            }

        case .local:
            let title = result.title.replacingOccurrences(of: "_", with: " ")
            let fileType = result.fileType ?? "file"
            return "\(title). A \(fileType) located at \(extractFileName(result.url))."
        }
    }

    /// Format multiple results for sequential voice readout
    /// - Parameter results: Array of SearchResults
    /// - Returns: String optimized for voice with introductory context
    func formatResultsForVoice(_ results: [SearchResult], query: String) -> String {
        let count = results.count
        var output = "I found \(count) result"
        if count != 1 {
            output += "s"
        }
        output += " for \(query).\n\n"

        output += results.enumerated()
            .map { index, result in
                let number = "Result \(index + 1)"
                let formatted = formatForVoice(result)
                return "\(number). \(formatted)"
            }
            .joined(separator: "\n\n")

        return output
    }

    // MARK: - Summary Generation

    /// Generate a brief summary of results
    /// - Parameters:
    ///   - results: Array of SearchResults
    ///   - maxResults: Maximum number of results to include (default: 5)
    /// - Returns: Summary string with top results
    func generateSummary(_ results: [SearchResult], maxResults: Int = 5) -> String {
        let topResults = Array(results.prefix(maxResults))
        let count = results.count

        var summary = "Found \(count) result"
        if count != 1 { summary += "s" }
        summary += ":\n\n"

        summary += topResults.enumerated()
            .map { index, result in
                "\(index + 1). \(result.title)\n   \(extractDomain(result.url))"
            }
            .joined(separator: "\n")

        if results.count > maxResults {
            summary += "\n\n... and \(results.count - maxResults) more"
        }

        return summary
    }

    // MARK: - Helper Methods

    private func extractDomain(_ url: String) -> String {
        if let url = URL(string: url) {
            return url.host ?? url.lastPathComponent
        }
        return url
    }

    private func extractFileName(_ path: String) -> String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    // MARK: - Validation

    /// Check if a result has sufficient data for display
    /// - Parameter result: The SearchResult to validate
    /// - Returns: true if result is valid for display
    func isValidForDisplay(_ result: SearchResult) -> Bool {
        !result.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !result.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Filter results to only those valid for display
    /// - Parameter results: Array of SearchResults
    /// - Returns: Filtered array of valid results
    func filterValidResults(_ results: [SearchResult]) -> [SearchResult] {
        results.filter(isValidForDisplay)
    }

    // MARK: - HTML/Text Cleaning

    /// Clean HTML entities and formatting from text
    /// - Parameter text: Text potentially containing HTML entities
    /// - Returns: Cleaned text
    func cleanText(_ text: String) -> String {
        var cleaned = text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        return cleaned
    }

    /// Extract snippet from longer text
    /// - Parameters:
    ///   - text: The full text
    ///   - maxLength: Maximum length of snippet (default: 150)
    /// - Returns: Cleaned and truncated snippet
    func extractSnippet(_ text: String, maxLength: Int = 150) -> String {
        let cleaned = cleanText(text)
        if cleaned.count <= maxLength {
            return cleaned
        }

        let truncated = String(cleaned.prefix(maxLength))
        return truncated.trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}

// MARK: - SearchResult Model Extension

extension SearchResult {
    /// Get human-readable display URL
    var displayURL: String {
        switch source {
        case .web:
            if let url = URL(string: url) {
                return url.host ?? url.lastPathComponent
            }
            return url
        case .local:
            return URL(fileURLWithPath: url).lastPathComponent
        }
    }
}

// MARK: - Formatter Singleton

extension SearchResultFormatter {
    /// Shared formatter instance
    static let shared = SearchResultFormatter()
}

// MARK: - Tests

#if DEBUG
    func testSearchResultFormatter() {
        let formatter = SearchResultFormatter()

        // Test web result
        let webResult = SearchResult(
            title: "SwiftUI Documentation",
            url: "https://developer.apple.com/documentation/swiftui",
            snippet: "SwiftUI is an innovative, exceptionally simple way to build user interfaces...",
            source: .web,
            relevance: 0.95
        )

        // Test local result
        let localResult = SearchResult(
            title: "SwiftUI Guide",
            url: "/Users/user/Projects/Guides/SwiftUI.md",
            snippet: "A comprehensive guide to building UIs with SwiftUI",
            source: .local,
            fileType: "markdown",
            relevance: 0.87
        )

        let results = [webResult, localResult]

        // Test various formats
        print("=== Brief Format ===")
        print(formatter.format(webResult, style: .brief))

        print("\n=== Detailed Format ===")
        print(formatter.format(webResult, style: .detailed))

        print("\n=== Numbered Format ===")
        print(formatter.formatResults(results, style: .numbered))

        print("\n=== Voice Format ===")
        print(formatter.formatForVoice(webResult))

        print("\n=== Voice Results ===")
        print(formatter.formatResultsForVoice(results, query: "SwiftUI"))

        print("\n=== Summary ===")
        print(formatter.generateSummary(results))
    }
#endif
