import Foundation

/// CommandSuggester provides helpful suggestions for unrecognized voice commands
/// 
/// Helps users learn the assistant's capabilities and recover from misunderstood commands.
/// Used by User Story 1: Voice System Control
public struct CommandSuggester {
    // MARK: - Suggestion Generation

    /// Generate suggestions for unrecognized command
    /// - Parameter command: Unrecognized command text
    /// - Returns: Array of suggested commands
    public static func suggestCommands(for command: String) -> [Suggestion] {
        let lowercased = command.lowercased()

        var suggestions: [Suggestion] = []

        // Find similar system commands
        suggestions.append(contentsOf: findSimilarSystemCommands(lowercased))

        // Suggest related commands
        suggestions.append(contentsOf: suggestRelatedCommands(lowercased))

        // Sort by relevance and return top 3
        return suggestions
            .sorted { $0.relevance > $1.relevance }
            .prefix(3)
            .map { $0 }
    }

    // MARK: - Similar Command Finding

    private static func findSimilarSystemCommands(_ input: String) -> [Suggestion] {
        let knownCommands = [
            "Open Safari",
            "Close Safari",
            "Open Mail",
            "Minimize window",
            "Maximize window",
            "Take a screenshot",
            "Lock screen",
            "Set volume to 50%",
            "Set brightness to 75%",
        ]

        return knownCommands.compactMap { command in
            let similarity = levenshteinSimilarity(input, command.lowercased())
            guard similarity > 0.5 else { return nil }

            return Suggestion(
                text: command,
                relevance: similarity,
                category: .system,
                reasoning: "Similar to '\(command)'"
            )
        }
    }

    private static func suggestRelatedCommands(_ input: String) -> [Suggestion] {
        var suggestions: [Suggestion] = []

        // If user says "app", suggest common app commands
        if input.contains("app") && input.contains("open") {
            suggestions.append(Suggestion(
                text: "Open Safari",
                relevance: 0.7,
                category: .system,
                reasoning: "Common app launch"
            ))
            suggestions.append(Suggestion(
                text: "Open Mail",
                relevance: 0.7,
                category: .system,
                reasoning: "Common app launch"
            ))
        }

        // If user mentions window, suggest window commands
        if input.contains("window") {
            suggestions.append(Suggestion(
                text: "Minimize window",
                relevance: 0.8,
                category: .system,
                reasoning: "Window management command"
            ))
            suggestions.append(Suggestion(
                text: "Maximize window",
                relevance: 0.8,
                category: .system,
                reasoning: "Window management command"
            ))
        }

        // If user mentions search, suggest search commands
        if input.contains("search") || input.contains("find") {
            suggestions.append(Suggestion(
                text: "Search Google for SwiftUI",
                relevance: 0.8,
                category: .search,
                reasoning: "Web search command"
            ))
        }

        // If user mentions time/timer, suggest productivity
        if input.contains("timer") || input.contains("time") {
            suggestions.append(Suggestion(
                text: "Set a timer for 5 minutes",
                relevance: 0.8,
                category: .productivity,
                reasoning: "Timer command"
            ))
        }

        return suggestions
    }

    // MARK: - Levenshtein Distance for Similarity

    /// Calculate similarity between two strings (0.0-1.0)
    /// Uses Levenshtein distance algorithm
    private static func levenshteinSimilarity(_ str1: String, _ str2: String) -> Double {
        let distance = levenshteinDistance(str1, str2)
        let maxLength = max(str1.count, str2.count)
        guard maxLength > 0 else { return 1.0 }
        return 1.0 - Double(distance) / Double(maxLength)
    }

    private static func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
        let s1 = Array(str1)
        let s2 = Array(str2)
        let m = s1.count
        let n = s2.count

        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

        for i in 0...m {
            dp[i][0] = i
        }
        for j in 0...n {
            dp[0][j] = j
        }

        for i in 1...m {
            for j in 1...n {
                let cost = s1[i - 1] == s2[j - 1] ? 0 : 1
                dp[i][j] = min(
                    dp[i - 1][j] + 1,
                    dp[i][j - 1] + 1,
                    dp[i - 1][j - 1] + cost
                )
            }
        }

        return dp[m][n]
    }

    // MARK: - General Help

    /// Get general help text with example commands
    public static func getHelpText() -> String {
        """
        I can help you with:

        **System Control:**
        - "Open Safari" - Launch an application
        - "Minimize window" - Control windows
        - "Take a screenshot" - Capture screen

        **Search:**
        - "Search Google for SwiftUI" - Web search
        - "Find my projects" - Search files

        **Productivity:**
        - "Set a timer for 5 minutes" - Create timer
        - "Note: Remember to call John" - Save note
        - "Calculate 15% of 250" - Do math

        Say "help" anytime for these options.
        """
    }

    /// Get category-specific help
    public static func getCategoryHelp(_ category: Suggestion.Category) -> String {
        switch category {
        case .system:
            return "I can control your Mac: launch apps, manage windows, adjust settings."
        case .search:
            return "I can search the web or your files for you."
        case .productivity:
            return "I can help with timers, notes, todos, and calculations."
        case .unknown:
            return "I didn't understand that. Try saying 'help' for examples."
        }
    }
}

// MARK: - Suggestion Type

public struct Suggestion: Equatable {
    public let text: String
    public let relevance: Double // 0.0-1.0
    public let category: Category
    public let reasoning: String

    public enum Category: String, Equatable {
        case system
        case search
        case productivity
        case unknown
    }

    public init(
        text: String,
        relevance: Double,
        category: Category,
        reasoning: String
    ) {
        self.text = text
        self.relevance = max(0.0, min(1.0, relevance))
        self.category = category
        self.reasoning = reasoning
    }
}

// MARK: - Feedback Provider

/// Provides user-facing feedback for command recognition
public struct CommandFeedbackProvider {
    /// Generate feedback message for unrecognized command
    /// - Parameters:
    ///   - command: Unrecognized command
    ///   - suggestions: Available suggestions
    /// - Returns: User-friendly feedback message
    public static func feedbackForUnrecognized(
        command: String,
        suggestions: [Suggestion]
    ) -> String {
        var message = "I didn't understand '\(command)'."

        if suggestions.isEmpty {
            message += "\n\nSay 'help' to learn what I can do."
        } else {
            message += "\n\nDid you mean:"
            for (index, suggestion) in suggestions.enumerated() {
                message += "\n\(index + 1). \(suggestion.text)"
            }
        }

        return message
    }

    /// Generate acknowledgment for recognized command
    /// - Parameter command: Recognized command
    /// - Returns: Brief confirmation message
    public static func acknowledgeCommand(_ command: String) -> String {
        let acknowledgments = [
            "Got it, I'll \(command) for you.",
            "Sure, I'll \(command).",
            "Understood. \(command.prefix(1).uppercased())\(command.dropFirst())...",
            "Let me \(command).",
        ]

        return acknowledgments.randomElement() ?? "Executing command..."
    }

    /// Generate feedback for ambiguous command
    /// - Parameter possibilities: Possible interpretations
    /// - Returns: Clarification message
    public static func clarifyAmbiguous(_ possibilities: [String]) -> String {
        var message = "I found multiple interpretations:"

        for (index, possibility) in possibilities.enumerated() {
            message += "\n\(index + 1). \(possibility)"
        }

        message += "\n\nWhich one did you mean?"
        return message
    }
}
