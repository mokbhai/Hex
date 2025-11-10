import Foundation

/// ModelValidator checks Core ML compatibility and validates model files
///
/// Ensures:
/// - Model file format is supported
/// - Model architecture is compatible with Apple Silicon
/// - File integrity and completeness
/// - Required model files are present
///
/// Used by User Story 5: AI Model Management (T032)
public struct ModelValidator {
    // MARK: - Validation

    /// Validate if a model is Core ML compatible
    /// - Parameter model: Model to validate
    /// - Returns: Validation result with any errors
    public static func validateCoreMLCompatibility(_ model: HuggingFaceModelDetail) -> ValidationResult {
        var issues: [ValidationIssue] = []

        // Check model size (must be under 1GB for reasonable performance)
        if model.size > 1_000_000_000 {
            issues.append(ValidationIssue(
                severity: .warning,
                message: "Model size (\(formatBytes(model.size))) is large. Download may take several minutes."
            ))
        }

        // Check if model has Core ML compatibility indicators
        if !model.coreMlCompatible && !hasConverterAvailable(for: model) {
            issues.append(ValidationIssue(
                severity: .error,
                message: "Model format not directly compatible with Core ML. Manual conversion may be required."
            ))
        }

        // Check for known supported tasks
        let supportedTasks = ["text-generation", "question-answering", "text-classification"]
        let hasKnownTask = model.tags.contains { tag in
            supportedTasks.contains { tag.lowercased().contains($0) }
        }

        if !hasKnownTask {
            issues.append(ValidationIssue(
                severity: .info,
                message: "Model task is not in the known supported list. Performance may vary."
            ))
        }

        let isValid = !issues.contains { $0.severity == .error }
        return ValidationResult(isValid: isValid, issues: issues)
    }

    /// Validate a downloaded model file
    /// - Parameters:
    ///   - path: Path to downloaded model file
    ///   - model: Expected model metadata
    /// - Returns: Validation result
    public static func validateModelFile(at path: String, expectedModel: AIModel) -> ValidationResult {
        var issues: [ValidationIssue] = []

        let fileManager = FileManager.default

        // Check file exists
        guard fileManager.fileExists(atPath: path) else {
            issues.append(ValidationIssue(
                severity: .error,
                message: "Model file not found at \(path)"
            ))
            return ValidationResult(isValid: false, issues: issues)
        }

        // Check file is readable
        guard fileManager.isReadableFile(atPath: path) else {
            issues.append(ValidationIssue(
                severity: .error,
                message: "Model file is not readable"
            ))
        }

        // Check file size matches expected
        do {
            let attributes = try fileManager.attributesOfItem(atPath: path)
            let fileSize = attributes[.size] as? Int64 ?? 0

            if fileSize != expectedModel.size && expectedModel.size > 0 {
                // Allow 5% size difference (for compression variations)
                let sizeRatio = Double(fileSize) / Double(expectedModel.size)
                if sizeRatio < 0.95 || sizeRatio > 1.05 {
                    issues.append(ValidationIssue(
                        severity: .warning,
                        message: "File size mismatch. Expected \(formatBytes(expectedModel.size)), got \(formatBytes(fileSize))"
                    ))
                }
            }
        } catch {
            issues.append(ValidationIssue(
                severity: .error,
                message: "Failed to check file attributes: \(error.localizedDescription)"
            ))
        }

        // Check for model integrity
        if !isValidModelFormat(at: path) {
            issues.append(ValidationIssue(
                severity: .error,
                message: "Model file appears to be corrupted or invalid"
            ))
        }

        let isValid = !issues.contains { $0.severity == .error }
        return ValidationResult(isValid: isValid, issues: issues)
    }

    /// Get validation requirements for a model
    /// - Parameter model: Model to check
    /// - Returns: List of requirements
    public static func getRequirements(for model: HuggingFaceModelDetail) -> [String] {
        var requirements: [String] = []

        requirements.append("Available disk space: \(formatBytes(model.size))")

        let estimatedDownloadTime = model.size / (1_000_000) // Assume 1MB/s
        if estimatedDownloadTime > 60 {
            let minutes = estimatedDownloadTime / 60
            requirements.append("Estimated download time: \(Int(minutes)) minutes")
        }

        requirements.append("macOS 13 or later (for Core ML support)")
        requirements.append("Apple Silicon recommended for optimal performance")

        if model.size > 500_000_000 {
            requirements.append("Network connection should be stable for \(Int(estimatedDownloadTime / 60))+ minute download")
        }

        return requirements
    }

    // MARK: - Helper Methods

    private static func hasConverterAvailable(for model: HuggingFaceModelDetail) -> Bool {
        // Check if we have converters for known model formats
        let convertibleFormats = [
            "pytorch", "tensorflow", "onnx", "huggingface"
        ]

        return model.tags.contains { tag in
            convertibleFormats.contains { tag.lowercased().contains($0) }
        }
    }

    private static func isValidModelFormat(at path: String) -> Bool {
        let fileManager = FileManager.default

        // Check file extensions
        let validExtensions = ["bin", "pt", "pb", "onnx", "mlmodel", "zip"]
        let fileExtension = (path as NSString).pathExtension.lowercased()

        if !validExtensions.contains(fileExtension) {
            return false
        }

        // Try to read first bytes to verify it's not corrupted
        do {
            guard let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped) else {
                return false
            }

            // Check for magic numbers of common formats
            if data.count < 4 {
                return false
            }

            // PyTorch: starts with specific magic bytes
            if fileExtension == "pt" || fileExtension == "bin" {
                // Check for ZIP magic number (PyTorch models are ZIPs)
                return data[0] == 0x50 && data[1] == 0x4B
            }

            return true
        } catch {
            return false
        }
    }

    private static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Validation Result Types

public struct ValidationResult {
    public let isValid: Bool
    public let issues: [ValidationIssue]

    public var hasErrors: Bool {
        issues.contains { $0.severity == .error }
    }

    public var hasWarnings: Bool {
        issues.contains { $0.severity == .warning }
    }

    public var errorMessages: [String] {
        issues.filter { $0.severity == .error }.map { $0.message }
    }

    public var warningMessages: [String] {
        issues.filter { $0.severity == .warning }.map { $0.message }
    }

    public var infoMessages: [String] {
        issues.filter { $0.severity == .info }.map { $0.message }
    }
}

public struct ValidationIssue {
    public enum Severity {
        case error
        case warning
        case info
    }

    public let severity: Severity
    public let message: String
}
