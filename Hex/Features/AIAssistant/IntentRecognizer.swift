import Foundation
import ComposableArchitecture

/// IntentRecognizer recognizes user intent from voice commands
/// 
/// Processes natural language to identify:
/// - System control commands (app launch, window management)
/// - Search queries (web or local)
/// - Productivity actions (timer, note, todo)
/// - Ambiguous commands requiring clarification
/// 
/// Used by User Story 1 (Voice System Control) and all other user stories
public struct IntentRecognizer {
    /// Intent types that can be recognized
    public enum Intent: Equatable {
        case systemCommand(SystemCommand)
        case search(query: String, type: SearchType)
        case productivity(type: ProductivityType)
        case unknown(String)
        case ambiguous([String]) // Possible interpretations

        public enum SearchType: String, Equatable {
            case web
            case local
        }

        public enum ProductivityType: Equatable {
            case createTimer(duration: String)
            case createNote(content: String)
            case createTodo(description: String)
            case calculate(expression: String)
        }
    }

    // MARK: - Intent Recognition

    /// Recognize intent from voice input
    /// - Parameter input: Voice command text
    /// - Returns: Recognized intent
    public static func recognize(_ input: String) -> Intent {
        let trimmed = input.trimmingCharacters(in: .whitespaces)

        // Try system commands first (highest priority)
        if let command = CommandParser.parse(trimmed) {
            return .systemCommand(command)
        }

        // Try search commands
        if let searchIntent = recognizeSearch(trimmed) {
            return searchIntent
        }

        // Try productivity commands
        if let productivityIntent = recognizeProductivity(trimmed) {
            return productivityIntent
        }

        // Check for ambiguous commands
        let possibilities = findPossibilities(for: trimmed)
        if possibilities.count > 1 {
            return .ambiguous(possibilities)
        }

        return .unknown(trimmed)
    }

    // MARK: - Search Recognition

    private static func recognizeSearch(_ input: String) -> Intent? {
        let lowercased = input.lowercased()

        // Web search: "Search for [query]", "Google [query]"
        if lowercased.hasPrefix("search for ") {
            let query = String(input.dropFirst("search for ".count))
            return .search(query: query.trimmingCharacters(in: .whitespaces), type: .web)
        }

        if lowercased.hasPrefix("google ") {
            let query = String(input.dropFirst("google ".count))
            return .search(query: query.trimmingCharacters(in: .whitespaces), type: .web)
        }

        // Local search: "Find [query]", "Search files for [query]"
        if lowercased.hasPrefix("find ") {
            let query = String(input.dropFirst("find ".count))
            return .search(query: query.trimmingCharacters(in: .whitespaces), type: .local)
        }

        return nil
    }

    // MARK: - Productivity Recognition

    private static func recognizeProductivity(_ input: String) -> Intent? {
        let lowercased = input.lowercased()

        // Timer: "Set a timer for [duration]"
        if lowercased.contains("timer") && lowercased.contains("for") {
            if let duration = extractDuration(from: input) {
                return .productivity(type: .createTimer(duration: duration))
            }
        }

        // Note: "Create a note", "Note: [content]"
        if lowercased.hasPrefix("note:") {
            let content = String(input.dropFirst("note:".count)).trimmingCharacters(in: .whitespaces)
            return .productivity(type: .createNote(content: content))
        }

        // Todo: "Add a todo", "Todo: [description]"
        if lowercased.hasPrefix("todo:") || lowercased.hasPrefix("add a todo") {
            let content = lowercased.hasPrefix("todo:") ?
                String(input.dropFirst("todo:".count)) :
                String(input.dropFirst("add a todo ".count))
            return .productivity(type: .createTodo(description: content.trimmingCharacters(in: .whitespaces)))
        }

        // Calculation: "[number] percent of [number]", "[number] plus [number]"
        if recognizeCalculation(lowercased) {
            return .productivity(type: .calculate(expression: input))
        }

        return nil
    }

    // MARK: - Helper Functions

    /// Extract duration from natural language (e.g., "5 minutes" → "5m")
    private static func extractDuration(from input: String) -> String? {
        let patterns = [
            ("\\d+\\s*minutes?", "m"),
            ("\\d+\\s*hours?", "h"),
            ("\\d+\\s*seconds?", "s"),
        ]

        for (pattern, suffix) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)),
               let range = Range(match.range, in: input) {
                let matched = String(input[range])
                if let number = Int(matched.filter { $0.isNumber }) {
                    return "\(number)\(suffix)"
                }
            }
        }

        return nil
    }

    /// Check if input looks like a calculation
    private static func recognizeCalculation(_ input: String) -> Bool {
        let calculationPatterns = [
            "percent of",
            "plus",
            "minus",
            "times",
            "divided by",
        ]

        return calculationPatterns.contains { input.contains($0) }
    }

    /// Find all possible interpretations of ambiguous command
    private static func findPossibilities(for input: String) -> [String] {
        // TODO: T022 Ambiguity Resolution
        // 1. Use fuzzy matching against known commands
        // 2. Suggest similar commands
        // 3. Return up to 3 suggestions
        return []
    }

    // MARK: - Confidence Scoring

    /// Score confidence in recognized intent (0.0-1.0)
    /// - Parameter intent: Recognized intent
    /// - Returns: Confidence score
    public static func scoreConfidence(for intent: Intent) -> Double {
        switch intent {
        case .systemCommand:
            return 0.95 // System commands are usually clear

        case .search:
            return 0.85 // Search is usually clear but could be ambiguous

        case .productivity:
            return 0.80 // Productivity could be ambiguous with other intents

        case .unknown:
            return 0.0 // No confidence in unknown commands

        case .ambiguous:
            return 0.5 // Multiple possibilities, needs clarification
        }
    }

    /// Check if intent confidence is sufficient
    /// - Parameter intent: Intent to check
    /// - Returns: True if confidence >= 0.75
    public static func isConfidentIntent(_ intent: Intent) -> Bool {
        scoreConfidence(for: intent) >= 0.75
    }
}

// MARK: - Effect Integration

/// TCA Effect for intent recognition
public func recognizeIntentEffect(_ input: String) -> Effect<AIAssistantFeature.Action> {
    return .run { send in
        let intent = IntentRecognizer.recognize(input)

        // Route to appropriate handler based on intent
        switch intent {
        case .systemCommand(let command):
            await send(.executeCommand(command.description))

        case .search(let query, let type):
            switch type {
            case .web:
                await send(.searchWeb(query))
            case .local:
                await send(.searchLocal(query))
            }

        case .productivity:
            // Route to productivity handlers
            break

        case .ambiguous(let possibilities):
            // Prompt user for clarification
            break

        case .unknown:
            // Ask user to repeat or get help
            break
        }
    }
}

// MARK: - Command Description

extension SystemCommand {
    public var description: String {
        switch self {
        case .launchApp(let name):
            return "Open \(name)"
        case .closeApp(let name):
            return "Close \(name)"
        case .focusApp(let name):
            return "Focus \(name)"
        case .minimizeWindow:
            return "Minimize window"
        case .maximizeWindow:
            return "Maximize window"
        case .closeWindow:
            return "Close window"
        case .snapWindowLeft:
            return "Snap window to left"
        case .snapWindowRight:
            return "Snap window to right"
        case .lockScreen:
            return "Lock screen"
        case .sleep:
            return "Sleep system"
        case .screenshot:
            return "Take screenshot"
        case .setVolume(let level):
            return "Set volume to \(level)%"
        case .toggleMute:
            return "Toggle mute"
        case .setBrightness(let level):
            return "Set brightness to \(level)%"
        }
    }
}
