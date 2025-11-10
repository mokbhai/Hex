import Foundation

/// Parser for natural language calculation expressions
/// Converts voice commands into mathematical expressions
///
/// Used by User Story 3: Voice Productivity Tools (T057)
public struct CalculationParser {
    // MARK: - Types

    enum ParserError: LocalizedError {
        case invalidSyntax
        case unsupportedOperation
        case ambiguousExpression

        public var errorDescription: String? {
            switch self {
            case .invalidSyntax:
                return "Invalid calculation syntax"
            case .unsupportedOperation:
                return "Unsupported mathematical operation"
            case .ambiguousExpression:
                return "Expression is ambiguous"
            }
        }
    }

    // MARK: - Parsing

    /// Parse natural language math expression
    /// - Parameter input: Voice input string
    /// - Returns: Mathematical expression string
    /// - Throws: ParserError if parsing fails
    public static func parse(_ input: String) throws -> String {
        let normalized = normalizeInput(input)

        // Try different parsing strategies
        if let result = trySimpleExpression(normalized) {
            return result
        }

        if let result = tryPercentageExpression(normalized) {
            return result
        }

        if let result = tryComparisonExpression(normalized) {
            return result
        }

        if let result = tryWordExpression(normalized) {
            return result
        }

        throw ParserError.invalidSyntax
    }

    // MARK: - Expression Parsing

    private static func normalizeInput(_ input: String) -> String {
        var normalized = input.lowercased()
            .trimmingCharacters(in: .whitespaces)

        // Replace common words with operators
        let replacements: [String: String] = [
            " plus ": " + ",
            " minus ": " - ",
            " times ": " * ",
            " multiplied by ": " * ",
            " divided by ": " / ",
            " over ": " / ",
            "squared": "^2",
            "cubed": "^3",
        ]

        for (key, value) in replacements {
            normalized = normalized.replacingOccurrences(of: key, with: value)
        }

        return normalized
    }

    private static func trySimpleExpression(_ input: String) -> String? {
        let operators = ["+", "-", "*", "/", "^"]
        
        for op in operators {
            if input.contains(" \(op) ") || input.contains("\(op)") {
                return input
            }
        }

        return nil
    }

    private static func tryPercentageExpression(_ input: String) -> String? {
        // "15 percent of 250" -> "250 * (15 / 100)"
        if input.contains("percent of") || input.contains("% of") {
            let components = input.components(separatedBy: " of ")
            guard components.count == 2 else { return nil }

            let percentPart = components[0]
                .replacingOccurrences(of: "percent", with: "")
                .replacingOccurrences(of: "%", with: "")
                .trimmingCharacters(in: .whitespaces)

            guard !percentPart.isEmpty, !components[1].isEmpty else { return nil }

            return "\(components[1]) * (\(percentPart) / 100)"
        }

        // "25 percent" -> "25 / 100"
        if input.contains("percent") || input.contains("%") {
            let numberPart = input
                .replacingOccurrences(of: "percent", with: "")
                .replacingOccurrences(of: "%", with: "")
                .trimmingCharacters(in: .whitespaces)

            guard !numberPart.isEmpty else { return nil }

            return "(\(numberPart) / 100)"
        }

        return nil
    }

    private static func tryComparisonExpression(_ input: String) -> String? {
        // "what is X times Y" -> "X * Y"
        if input.contains("what is") {
            let expr = input.replacingOccurrences(of: "what is", with: "")
                .trimmingCharacters(in: .whitespaces)
            return expr
        }

        // "X more than Y" -> "Y + X"
        if input.contains(" more than ") {
            let components = input.components(separatedBy: " more than ")
            guard components.count == 2 else { return nil }
            return "\(components[1]) + \(components[0])"
        }

        // "X less than Y" -> "Y - X"
        if input.contains(" less than ") {
            let components = input.components(separatedBy: " less than ")
            guard components.count == 2 else { return nil }
            return "\(components[1]) - \(components[0])"
        }

        // "X times more than Y" -> "Y * X"
        if input.contains(" times more than ") {
            let components = input.components(separatedBy: " times more than ")
            guard components.count == 2 else { return nil }
            return "\(components[1]) * \(components[0])"
        }

        return nil
    }

    private static func tryWordExpression(_ input: String) -> String? {
        // "one plus two" -> "1 + 2"
        var expr = input
        
        let wordNumbers: [String: String] = [
            "zero": "0",
            "one": "1",
            "two": "2",
            "three": "3",
            "four": "4",
            "five": "5",
            "six": "6",
            "seven": "7",
            "eight": "8",
            "nine": "9",
            "ten": "10",
            "eleven": "11",
            "twelve": "12",
            "thirteen": "13",
            "fourteen": "14",
            "fifteen": "15",
            "sixteen": "16",
            "seventeen": "17",
            "eighteen": "18",
            "nineteen": "19",
            "twenty": "20",
            "thirty": "30",
            "forty": "40",
            "fifty": "50",
            "hundred": "100",
            "thousand": "1000",
        ]

        for (word, num) in wordNumbers {
            expr = expr.replacingOccurrences(of: word, with: num)
        }

        // If we made replacements, try as simple expression
        if expr != input {
            return expr
        }

        return nil
    }

    // MARK: - Validation

    /// Validate expression syntax
    /// - Parameter expression: The expression to validate
    /// - Returns: true if expression appears valid
    public static func isValidExpression(_ expression: String) -> Bool {
        let expression = expression.trimmingCharacters(in: .whitespaces)

        guard !expression.isEmpty else { return false }

        // Must contain numbers
        let hasNumbers = expression.contains(where: { $0.isNumber })
        guard hasNumbers else { return false }

        // Check balanced parentheses
        var parenCount = 0
        for char in expression {
            if char == "(" { parenCount += 1 }
            if char == ")" { parenCount -= 1 }
            if parenCount < 0 { return false }
        }

        if parenCount != 0 { return false }

        return true
    }

    /// Extract all numbers from an expression
    /// - Parameter expression: The expression to analyze
    /// - Returns: Array of Double values found
    public static func extractNumbers(_ expression: String) -> [Double] {
        var numbers: [Double] = []
        var currentNumber = ""

        for char in expression {
            if char.isNumber || char == "." {
                currentNumber.append(char)
            } else {
                if !currentNumber.isEmpty, let num = Double(currentNumber) {
                    numbers.append(num)
                    currentNumber = ""
                }
            }
        }

        if !currentNumber.isEmpty, let num = Double(currentNumber) {
            numbers.append(num)
        }

        return numbers
    }

    /// Extract operators from expression
    /// - Parameter expression: The expression to analyze
    /// - Returns: Array of operator strings found
    public static func extractOperators(_ expression: String) -> [String] {
        let operators = ["+", "-", "*", "/", "^", "%"]
        var found: [String] = []

        for op in operators {
            if expression.contains(op) {
                found.append(op)
            }
        }

        return found
    }

    // MARK: - Suggestions

    /// Get calculation suggestions for incomplete input
    /// - Parameter input: Partial voice input
    /// - Returns: Array of suggested completions
    public static func getSuggestions(for input: String) -> [String] {
        let normalized = input.lowercased()
        var suggestions: [String] = []

        if normalized.contains("percent") && !normalized.contains("of") {
            suggestions.append("percent of [number]")
        }

        if normalized.contains("times") && !normalized.contains(" * ") {
            suggestions.append("times [number]")
        }

        if normalized.contains("more than") {
            suggestions.append("[number] more than [number]")
        }

        if normalized.contains("less than") {
            suggestions.append("[number] less than [number]")
        }

        // Add basic operations if input looks like it needs one
        if input.contains(where: { $0.isNumber }) {
            if !normalized.contains("+") {
                suggestions.append("plus [number]")
            }
            if !normalized.contains("-") {
                suggestions.append("minus [number]")
            }
            if !normalized.contains("*") {
                suggestions.append("times [number]")
            }
            if !normalized.contains("/") {
                suggestions.append("divided by [number]")
            }
        }

        return Array(suggestions.prefix(4)) // Return top 4
    }

    // MARK: - Complexity Analysis

    /// Analyze expression complexity
    /// - Parameter expression: The expression to analyze
    /// - Returns: Complexity score (0-10, where 10 is most complex)
    public static func analyzeComplexity(_ expression: String) -> Int {
        var score = 0

        // Count operators
        let operators = ["+", "-", "*", "/", "^", "%"]
        for op in operators {
            score += expression.filter { String($0) == op }.count
        }

        // Check nesting
        let parenCount = expression.filter { $0 == "(" }.count
        score += parenCount * 2

        // Normalize to 0-10
        return min(10, score)
    }
}

// MARK: - Example Usage

extension CalculationParser {
    /// Get example expressions
    /// - Returns: Array of example calculation strings
    public static func getExamples() -> [String] {
        [
            "what is 5 plus 3",
            "15 percent of 250",
            "25 times 4",
            "100 divided by 5",
            "how much is 10 more than 20",
            "30 less than 100",
            "2 times more than 50",
            "calculate 15 percent",
        ]
    }
}
