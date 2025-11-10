import Foundation

/// Calculator service for voice-controlled calculations
/// Handles natural language math expressions and basic calculations
///
/// Used by User Story 3: Voice Productivity Tools (T048)
public struct Calculator {
    // MARK: - Types

    enum CalculatorError: LocalizedError {
        case invalidExpression
        case divisionByZero
        case unsupportedOperation

        public var errorDescription: String? {
            switch self {
            case .invalidExpression:
                return "Invalid mathematical expression"
            case .divisionByZero:
                return "Cannot divide by zero"
            case .unsupportedOperation:
                return "Operation is not supported"
            }
        }
    }

    public struct CalculationResult: Equatable {
        public let expression: String
        public let result: Double
        public let displayText: String

        public init(expression: String, result: Double, displayText: String? = nil) {
            self.expression = expression
            self.result = result
            self.displayText = displayText ?? String(format: "%.2f", result)
        }
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Basic Operations

    /// Perform a calculation with a mathematical expression
    /// - Parameter expression: Mathematical expression (e.g., "2 + 3", "10 * 5")
    /// - Returns: CalculationResult
    /// - Throws: CalculatorError if expression is invalid
    public func calculate(_ expression: String) throws -> CalculationResult {
        let normalized = normalizeExpression(expression)
        guard !normalized.isEmpty else {
            throw CalculatorError.invalidExpression
        }

        // Use NSExpression for safe evaluation
        let nsExpression = try createNSExpression(normalized)
        
        guard let value = nsExpression.expressionValue(with: nil, context: nil) as? NSNumber else {
            throw CalculatorError.invalidExpression
        }

        let result = value.doubleValue

        // Check for division by zero (NSExpression doesn't always catch it)
        if normalized.contains("/") && result.isInfinite {
            throw CalculatorError.divisionByZero
        }

        return CalculationResult(expression: expression, result: result)
    }

    /// Parse and calculate a natural language math expression
    /// - Parameter input: Natural language expression (e.g., "15 percent of 250")
    /// - Returns: CalculationResult
    /// - Throws: CalculatorError if parsing or calculation fails
    public func calculateNaturalLanguage(_ input: String) throws -> CalculationResult {
        let normalized = input.lowercased().trimmingCharacters(in: .whitespaces)

        // Handle percentage: "15 percent of 250" -> 250 * 0.15
        if normalized.contains("percent of") || normalized.contains("% of") {
            return try handlePercentageExpression(normalized)
        }

        // Handle "X to Y" (range/conversion notation)
        if normalized.contains(" to ") && !normalized.contains("+") {
            return try handleRangeExpression(normalized)
        }

        // Handle percentage conversion: "25 percent" -> 0.25
        if normalized.contains("percent") || normalized.contains("%") {
            return try handlePercentageConversion(normalized)
        }

        // Try direct calculation
        return try calculate(normalized)
    }

    // MARK: - Expression Normalization

    private func normalizeExpression(_ expression: String) -> String {
        var normalized = expression
            .lowercased()
            .trimmingCharacters(in: .whitespaces)

        // Remove extra spaces around operators
        let operators = ["+", "-", "*", "/", "^"]
        for op in operators {
            normalized = normalized.replacingOccurrences(of: " \(op) ", with: op)
            normalized = normalized.replacingOccurrences(of: " \(op)", with: op)
            normalized = normalized.replacingOccurrences(of: "\(op) ", with: op)
        }

        // Replace "x" or "×" with "*"
        normalized = normalized.replacingOccurrences(of: "x", with: "*")
        normalized = normalized.replacingOccurrences(of: "×", with: "*")

        // Replace "÷" with "/"
        normalized = normalized.replacingOccurrences(of: "÷", with: "/")

        // Replace "^" with "pow(a,b)" format if needed
        if normalized.contains("^") {
            // For simple cases, use ** instead (if supported)
            // Otherwise, keep ^ for now
        }

        return normalized
    }

    private func createNSExpression(_ expression: String) throws -> NSExpression {
        do {
            return try NSExpression(format: expression)
        } catch {
            throw CalculatorError.invalidExpression
        }
    }

    // MARK: - Natural Language Handlers

    private func handlePercentageExpression(_ input: String) throws -> CalculationResult {
        // "15 percent of 250" or "15% of 250"
        let components = input.components(separatedBy: " of ")
        guard components.count == 2 else {
            throw CalculatorError.invalidExpression
        }

        let percentPart = components[0]
            .replacingOccurrences(of: " percent", with: "")
            .replacingOccurrences(of: "%", with: "")
            .trimmingCharacters(in: .whitespaces)

        let basePart = components[1].trimmingCharacters(in: .whitespaces)

        guard let percentValue = Double(percentPart),
              let baseValue = Double(basePart) else {
            throw CalculatorError.invalidExpression
        }

        let result = baseValue * (percentValue / 100)
        let displayText = "\(percentValue)% of \(baseValue) = \(String(format: "%.2f", result))"

        return CalculationResult(expression: input, result: result, displayText: displayText)
    }

    private func handlePercentageConversion(_ input: String) throws -> CalculationResult {
        // "25 percent" -> 0.25
        let numberPart = input
            .replacingOccurrences(of: " percent", with: "")
            .replacingOccurrences(of: "%", with: "")
            .trimmingCharacters(in: .whitespaces)

        guard let value = Double(numberPart) else {
            throw CalculatorError.invalidExpression
        }

        let result = value / 100
        let displayText = "\(value)% = \(String(format: "%.4f", result))"

        return CalculationResult(expression: input, result: result, displayText: displayText)
    }

    private func handleRangeExpression(_ input: String) throws -> CalculationResult {
        // "10 to 20" -> could mean add, or could be a range query
        // For now, interpret as asking the difference or average
        let components = input.components(separatedBy: " to ")
        guard components.count == 2,
              let first = Double(components[0].trimmingCharacters(in: .whitespaces)),
              let second = Double(components[1].trimmingCharacters(in: .whitespaces)) else {
            throw CalculatorError.invalidExpression
        }

        // Return the difference
        let result = second - first
        let displayText = "Difference from \(first) to \(second) = \(String(format: "%.2f", result))"

        return CalculationResult(expression: input, result: result, displayText: displayText)
    }

    // MARK: - Utility Methods

    /// Check if a string is a valid mathematical expression
    /// - Parameter input: The input string
    /// - Returns: true if it appears to be a valid math expression
    public func isValidExpression(_ input: String) -> Bool {
        do {
            _ = try calculate(input)
            return true
        } catch {
            return false
        }
    }

    /// Get supported operations
    /// - Returns: Array of supported operations
    public static func supportedOperations() -> [String] {
        [
            "Addition: 5 + 3",
            "Subtraction: 10 - 4",
            "Multiplication: 6 * 7",
            "Division: 20 / 4",
            "Percentage: 15% of 250",
            "Percentage conversion: 25 percent",
            "Decimals: 3.5 + 2.1",
            "Negative numbers: -5 + 3",
            "Parentheses: (5 + 3) * 2",
        ]
    }

    /// Format a number for display
    /// - Parameters:
    ///   - value: The number to format
    ///   - precision: Number of decimal places
    /// - Returns: Formatted string
    public static func formatNumber(_ value: Double, precision: Int = 2) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.\(precision)f", value)
    }

    /// Convert a calculation result to a user-friendly string
    /// - Parameter result: CalculationResult
    /// - Returns: Formatted string for display
    public static func formatResult(_ result: CalculationResult) -> String {
        "\(result.expression) = \(result.displayText)"
    }
}

// MARK: - TCA Integration

import ComposableArchitecture

extension DependencyValues {
    var calculator: Calculator {
        get { self[CalculatorKey.self] }
        set { self[CalculatorKey.self] = newValue }
    }
}

private enum CalculatorKey: DependencyKey {
    static let liveValue = Calculator()
    static let previewValue = Calculator()
    static let testValue = Calculator()
}
