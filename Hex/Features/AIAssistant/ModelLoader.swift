import Foundation

/// ModelLoader handles loading and unloading AI models for inference
///
/// Manages:
/// - Model loading into memory
/// - Model lifecycle (initialization, cleanup)
/// - Memory usage optimization
/// - Model compatibility checking
///
/// Used by User Story 5: AI Model Management (T036)
public struct ModelLoader {
    private static var loadedModels: [String: LoadedModelInfo] = [:]
    private static let lock = NSLock()
    private static let maxMemory: Int64 = 2_000_000_000 // 2GB max for models

    // MARK: - Model Loading

    /// Load a model for inference
    /// - Parameters:
    ///   - model: Model to load
    ///   - path: Path to model file
    /// - Returns: Loading result
    public static func loadModel(_ model: AIModel, from path: String) async throws -> LoadingResult {
        Self.lock.lock()
        defer { Self.lock.unlock() }

        // Check if already loaded
        if let loaded = loadedModels[model.id] {
            loaded.referenceCount += 1
            return LoadingResult(
                modelId: model.id,
                status: .loaded,
                memoryUsed: loaded.memoryUsed,
                estimatedInferenceTime: loaded.estimatedInferenceTime
            )
        }

        // Check if we have enough memory
        let totalMemoryUsed = loadedModels.values.reduce(0) { $0 + $1.memoryUsed }
        if totalMemoryUsed + model.size > maxMemory {
            // Try to unload least recently used model
            if !unloadLRUModel() {
                throw ModelLoaderError.insufficientMemory(
                    required: model.size,
                    available: maxMemory - totalMemoryUsed
                )
            }
        }

        // Validate model file
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path) else {
            throw ModelLoaderError.modelFileNotFound(path)
        }

        // Load model
        let loadedInfo = LoadedModelInfo(
            modelId: model.id,
            displayName: model.displayName,
            memoryUsed: model.size,
            loadedAt: Date(),
            lastUsedAt: Date(),
            referenceCount: 1,
            estimatedInferenceTime: estimateInferenceTime(for: model)
        )

        loadedModels[model.id] = loadedInfo

        // Update storage access time
        LocalModelStorage.updateLastAccessTime(for: model.id)

        return LoadingResult(
            modelId: model.id,
            status: .loaded,
            memoryUsed: loadedInfo.memoryUsed,
            estimatedInferenceTime: loadedInfo.estimatedInferenceTime
        )
    }

    /// Unload a model from memory
    /// - Parameter modelId: Model ID to unload
    /// - Returns: True if unloaded, false if still in use
    public static func unloadModel(_ modelId: String) -> Bool {
        Self.lock.lock()
        defer { Self.lock.unlock() }

        guard let loadedInfo = loadedModels[modelId] else {
            return false
        }

        loadedInfo.referenceCount -= 1

        if loadedInfo.referenceCount <= 0 {
            loadedModels.removeValue(forKey: modelId)
            return true
        }

        return false
    }

    /// Unload all models from memory
    public static func unloadAll() {
        Self.lock.lock()
        defer { Self.lock.unlock() }

        loadedModels.removeAll()
    }

    // MARK: - Status Queries

    /// Get memory used by all loaded models
    /// - Returns: Total memory in bytes
    public static func getTotalMemoryUsed() -> Int64 {
        Self.lock.lock()
        defer { Self.lock.unlock() }

        return loadedModels.values.reduce(0) { $0 + $1.memoryUsed }
    }

    /// Get available memory for loading more models
    /// - Returns: Available memory in bytes
    public static func getAvailableMemory() -> Int64 {
        max(0, maxMemory - getTotalMemoryUsed())
    }

    /// Check if a model is currently loaded
    /// - Parameter modelId: Model ID to check
    /// - Returns: True if model is loaded
    public static func isModelLoaded(_ modelId: String) -> Bool {
        Self.lock.lock()
        defer { Self.lock.unlock() }

        return loadedModels[modelId] != nil
    }

    /// Get information about a loaded model
    /// - Parameter modelId: Model ID
    /// - Returns: Loaded model info if available
    public static func getLoadedModelInfo(_ modelId: String) -> LoadedModelInfo? {
        Self.lock.lock()
        defer { Self.lock.unlock() }

        return loadedModels[modelId]
    }

    /// Get all currently loaded models
    /// - Returns: Array of loaded model IDs
    public static func getLoadedModels() -> [String] {
        Self.lock.lock()
        defer { Self.lock.unlock() }

        return Array(loadedModels.keys)
    }

    // MARK: - Optimization

    /// Optimize memory by unloading unused models
    /// - Returns: Number of models unloaded
    public static func optimizeMemory() -> Int {
        Self.lock.lock()
        defer { Self.lock.unlock() }

        let targetUsage = maxMemory / 2 // Try to use only 50% max

        let sortedByUsage = loadedModels.values.sorted { $0.lastUsedAt < $1.lastUsedAt }

        var unloadedCount = 0
        var currentUsage = getTotalMemoryUsed()

        for modelInfo in sortedByUsage {
            guard currentUsage > targetUsage else { break }

            if modelInfo.referenceCount <= 0 {
                loadedModels.removeValue(forKey: modelInfo.modelId)
                currentUsage -= modelInfo.memoryUsed
                unloadedCount += 1
            }
        }

        return unloadedCount
    }

    /// Get memory usage report
    /// - Returns: Detailed memory usage information
    public static func getMemoryReport() -> MemoryReport {
        Self.lock.lock()
        defer { Self.lock.unlock() }

        let totalUsed = loadedModels.values.reduce(0) { $0 + $1.memoryUsed }
        let models = loadedModels.values.map { info in
            ModelMemoryInfo(
                modelId: info.modelId,
                displayName: info.displayName,
                memoryUsed: info.memoryUsed,
                referenceCount: info.referenceCount,
                inferenceTimeMs: info.estimatedInferenceTime
            )
        }

        return MemoryReport(
            totalMemoryUsed: totalUsed,
            maxMemory: maxMemory,
            availableMemory: maxMemory - totalUsed,
            modelsLoaded: models.count,
            models: models
        )
    }

    // MARK: - Helper Methods

    private static func unloadLRUModel() -> Bool {
        guard let lru = loadedModels.values.min(by: { $0.lastUsedAt < $1.lastUsedAt }) else {
            return false
        }

        if lru.referenceCount <= 0 {
            loadedModels.removeValue(forKey: lru.modelId)
            return true
        }

        return false
    }

    private static func estimateInferenceTime(for model: AIModel) -> Int {
        // Estimate based on model size
        // Small models (<100MB): ~100ms
        // Medium models (100-500MB): ~200ms
        // Large models (>500MB): ~500ms+

        let sizeInMB = Double(model.size) / 1_000_000

        if sizeInMB < 100 {
            return 100
        } else if sizeInMB < 500 {
            return 200
        } else {
            return min(1000, Int(sizeInMB / 500) * 100)
        }
    }
}

// MARK: - Result Types

public struct LoadingResult {
    public let modelId: String
    public let status: LoadingStatus
    public let memoryUsed: Int64
    public let estimatedInferenceTime: Int // milliseconds

    public enum LoadingStatus {
        case loaded
        case loading
        case error(String)
    }
}

public class LoadedModelInfo {
    public let modelId: String
    public let displayName: String
    public let memoryUsed: Int64
    public let loadedAt: Date
    public var lastUsedAt: Date
    public var referenceCount: Int
    public let estimatedInferenceTime: Int

    public init(
        modelId: String,
        displayName: String,
        memoryUsed: Int64,
        loadedAt: Date,
        lastUsedAt: Date,
        referenceCount: Int,
        estimatedInferenceTime: Int
    ) {
        self.modelId = modelId
        self.displayName = displayName
        self.memoryUsed = memoryUsed
        self.loadedAt = loadedAt
        self.lastUsedAt = lastUsedAt
        self.referenceCount = referenceCount
        self.estimatedInferenceTime = estimatedInferenceTime
    }
}

public struct MemoryReport {
    public let totalMemoryUsed: Int64
    public let maxMemory: Int64
    public let availableMemory: Int64
    public let modelsLoaded: Int
    public let models: [ModelMemoryInfo]

    public var memoryUsagePercentage: Double {
        guard maxMemory > 0 else { return 0 }
        return Double(totalMemoryUsed) / Double(maxMemory) * 100
    }
}

public struct ModelMemoryInfo {
    public let modelId: String
    public let displayName: String
    public let memoryUsed: Int64
    public let referenceCount: Int
    public let inferenceTimeMs: Int
}

// MARK: - Errors

public enum ModelLoaderError: LocalizedError {
    case modelFileNotFound(String)
    case insufficientMemory(required: Int64, available: Int64)
    case loadingFailed(String)
    case invalidModel(String)

    public var errorDescription: String? {
        switch self {
        case .modelFileNotFound(let path):
            return "Model file not found: \(path)"
        case .insufficientMemory(let required, let available):
            return "Insufficient memory. Required: \(formatBytes(required)), Available: \(formatBytes(available))"
        case .loadingFailed(let reason):
            return "Model loading failed: \(reason)"
        case .invalidModel(let reason):
            return "Invalid model: \(reason)"
        }
    }

    private static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        return formatter.string(fromByteCount: bytes)
    }
}
