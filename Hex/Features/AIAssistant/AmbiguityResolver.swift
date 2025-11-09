import Foundation

/// AmbiguityResolver handles ambiguous voice commands and prompts for clarification
/// 
/// Used by User Story 1: Voice System Control
/// Improves user experience by asking for clarification instead of guessing
public struct AmbiguityResolver {
    // MARK: - Ambiguity Detection

    /// Detect if command is ambiguous
    /// - Parameter command: Recognized command
    /// - Returns: Possible interpretations if ambiguous
    public static func detectAmbiguity(_ command: String) -> [Interpretation]? {
        let lowercased = command.lowercased()

        // "Open" could mean launch app or open file
        if lowercased.hasPrefix("open ") {
            let target = String(command.dropFirst("open ".count))
            return [
                Interpretation(
                    text: "Launch the app '\(target)'",
                    intent: .launchApp(target),
                    confidence: 0.8
                ),
                Interpretation(
                    text: "Open file '\(target)'",
                    intent: .openFile(target),
                    confidence: 0.7
                ),
            ]
        }

        // "Close" could mean close app or close window
        if lowercased.hasPrefix("close ") {
            let target = String(command.dropFirst("close ".count))
            return [
                Interpretation(
                    text: "Close the app '\(target)'",
                    intent: .closeApp(target),
                    confidence: 0.7
                ),
                Interpretation(
                    text: "Close a window in '\(target)'",
                    intent: .closeWindow,
                    confidence: 0.6
                ),
            ]
        }

        // "Search" could mean web or local
        if lowercased.hasPrefix("search ") {
            let query = String(command.dropFirst("search ".count))
            return [
                Interpretation(
                    text: "Search the web for '\(query)'",
                    intent: .searchWeb(query),
                    confidence: 0.75
                ),
                Interpretation(
                    text: "Search my computer for '\(query)'",
                    intent: .searchLocal(query),
                    confidence: 0.75
                ),
            ]
        }

        // "Set" could mean volume, brightness, or other settings
        if lowercased.hasPrefix("set ") && lowercased.contains("to") {
            return detectSettingAmbiguity(command)
        }

        return nil
    }

    private static func detectSettingAmbiguity(_ command: String) -> [Interpretation]? {
        let lowercased = command.lowercased()

        var interpretations: [Interpretation] = []

        // Extract value (e.g., "50" from "set volume to 50")
        if let value = extractNumericValue(command) {
            // Could be volume or brightness
            interpretations.append(Interpretation(
                text: "Set volume to \(value)%",
                intent: .setVolume(value),
                confidence: 0.7
            ))
            interpretations.append(Interpretation(
                text: "Set brightness to \(value)%",
                intent: .setBrightness(value),
                confidence: 0.7
            ))
        }

        return interpretations.isEmpty ? nil : interpretations
    }

    private static func extractNumericValue(_ input: String) -> Int? {
        let pattern = "\\d+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let range = NSRange(input.startIndex..., in: input)
        guard let match = regex.firstMatch(in: input, range: range),
              let matchRange = Range(match.range, in: input) else {
            return nil
        }

        return Int(input[matchRange])
    }

    // MARK: - Clarification Prompts

    /// Generate clarification prompt for ambiguous command
    /// - Parameter interpretations: Possible interpretations
    /// - Returns: User-friendly prompt
    public static func generateClarificationPrompt(
        _ interpretations: [Interpretation]
    ) -> String {
        guard !interpretations.isEmpty else {
            return "I didn't understand that. Could you please rephrase?"
        }

        var prompt = "I found \(interpretations.count) possible meanings:\n\n"

        for (index, interpretation) in interpretations.enumerated() {
            prompt += "\(index + 1). \(interpretation.text)\n"
        }

        prompt += "\nWhich one did you mean? (Say 1, 2, or 3)"
        return prompt
    }

    /// Generate follow-up question for partial match
    /// - Parameter command: Partially matched command
    /// - Returns: Follow-up question
    public static func generateFollowUp(for command: String) -> String {
        let lowercased = command.lowercased()

        if lowercased.contains("app") && !lowercased.contains("which") {
            return "Which app would you like to open?"
        }

        if lowercased.contains("window") && !lowercased.contains("how") {
            return "What would you like to do with the window?"
        }

        if lowercased.contains("search") && !lowercased.contains("what") {
            return "What would you like to search for?"
        }

        return "Could you provide more details?"
    }

    // MARK: - Resolution

    /// Resolve ambiguous command with user input
    /// - Parameters:
    ///   - interpretations: Possible interpretations
    ///   - userChoice: User's selection (1-based index)
    /// - Returns: Selected interpretation
    public static func resolveWithChoice(
        _ interpretations: [Interpretation],
        userChoice: Int
    ) -> Interpretation? {
        let index = userChoice - 1
        guard index >= 0 && index < interpretations.count else {
            return nil
        }
        return interpretations[index]
    }

    /// Auto-resolve if confidence is high enough
    /// - Parameter interpretations: Possible interpretations
    /// - Returns: Auto-selected interpretation if confidence >= 0.85, nil otherwise
    public static func tryAutoResolve(_ interpretations: [Interpretation]) -> Interpretation? {
        // Find interpretation with highest confidence
        let best = interpretations.max { $0.confidence < $1.confidence }

        // Only auto-resolve if confidence is high
        guard let best = best, best.confidence >= 0.85 else {
            return nil
        }

        return best
    }

    // MARK: - Context-Based Resolution

    /// Resolve ambiguity using context
    /// - Parameters:
    ///   - interpretations: Possible interpretations
    ///   - recentCommands: Recent command history
    /// - Returns: Most likely interpretation based on context
    public static func resolveWithContext(
        _ interpretations: [Interpretation],
        recentCommands: [String]
    ) -> Interpretation? {
        // TODO: T026 Context Analysis
        // 1. Analyze recent commands to infer user intent
        // 2. If user recently searched, favor search interpretations
        // 3. If user recently controlled windows, favor window commands
        // 4. Return most contextually relevant interpretation

        // For now, return highest confidence
        return interpretations.max { $0.confidence < $1.confidence }
    }

    // MARK: - Learning

    /// Record user choice for ambiguous command
    /// - Parameters:
    ///   - command: Original ambiguous command
    ///   - chosen: User's choice
    /// - Returns: Learning record
    public static func recordUserChoice(
        for command: String,
        chosen: Interpretation
    ) -> LearningRecord {
        return LearningRecord(
            originalCommand: command,
            chosenInterpretation: chosen.text,
            timestamp: Date()
        )
    }

    /// Use learning history to improve future resolution
    /// - Parameters:
    ///   - interpretations: Current possible interpretations
    ///   - history: Past learning records
    /// - Returns: Reordered interpretations by user preference
    public static func reorderByLearning(
        _ interpretations: [Interpretation],
        learningHistory: [LearningRecord]
    ) -> [Interpretation] {
        // TODO: T026 Learning Integration
        // 1. Count how often each interpretation was chosen
        // 2. Boost score for frequently chosen interpretations
        // 3. Return reordered list

        return interpretations
    }
}

// MARK: - Supporting Types

/// Possible interpretation of an ambiguous command
public struct Interpretation: Equatable {
    public let text: String // User-friendly description
    public let intent: Intent
    public let confidence: Double // 0.0-1.0

    public enum Intent: Equatable {
        case launchApp(String)
        case closeApp(String)
        case openFile(String)
        case closeWindow
        case searchWeb(String)
        case searchLocal(String)
        case setVolume(Int)
        case setBrightness(Int)
    }

    public init(text: String, intent: Intent, confidence: Double) {
        self.text = text
        self.intent = intent
        self.confidence = max(0.0, min(1.0, confidence))
    }
}

/// Learning record for user's choices
public struct LearningRecord: Equatable {
    public let originalCommand: String
    public let chosenInterpretation: String
    public let timestamp: Date

    public init(originalCommand: String, chosenInterpretation: String, timestamp: Date = Date()) {
        self.originalCommand = originalCommand
        self.chosenInterpretation = chosenInterpretation
        self.timestamp = timestamp
    }
}

// MARK: - Ambiguity Statistics

/// Track and analyze ambiguity patterns
public struct AmbiguityStats: Equatable {
    public let totalCommands: Int
    public let ambiguousCommands: Int
    public let resolvedCommands: Int
    public let failedResolutions: Int
    public let averageResolutionTime: TimeInterval

    public var ambiguityRate: Double {
        guard totalCommands > 0 else { return 0 }
        return Double(ambiguousCommands) / Double(totalCommands)
    }

    public var resolutionRate: Double {
        guard ambiguousCommands > 0 else { return 1.0 }
        return Double(resolvedCommands) / Double(ambiguousCommands)
    }

    public init(
        totalCommands: Int = 0,
        ambiguousCommands: Int = 0,
        resolvedCommands: Int = 0,
        failedResolutions: Int = 0,
        averageResolutionTime: TimeInterval = 0
    ) {
        self.totalCommands = totalCommands
        self.ambiguousCommands = ambiguousCommands
        self.resolvedCommands = resolvedCommands
        self.failedResolutions = failedResolutions
        self.averageResolutionTime = averageResolutionTime
    }
}
