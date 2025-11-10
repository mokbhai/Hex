import Foundation

/// LocalModelStorage manages storage and caching of downloaded AI models
///
/// Handles:
/// - Model file storage organization
/// - Cache management and cleanup
/// - Storage quota enforcement
/// - Model metadata persistence
///
/// Used by User Story 5: AI Model Management (T033)
public struct LocalModelStorage {
    private static let defaultModelsDirectory = "AIModels"
    private static let metadataFileName = "model-metadata.json"
    private static let maxCacheSize: Int64 = 10_000_000_000 // 10GB

    // MARK: - Storage Operations

    /// Get the directory where models should be stored
    /// - Returns: URL to models directory
    public static func getModelsDirectory() -> URL {
        let fileManager = FileManager.default

        // Use Application Support directory
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        ?? URL(fileURLWithPath: NSHomeDirectory())

        let modelsURL = appSupportURL.appendingPathComponent(defaultModelsDirectory)

        // Create directory if needed
        if !fileManager.fileExists(atPath: modelsURL.path) {
            try? fileManager.createDirectory(at: modelsURL, withIntermediateDirectories: true)
        }

        return modelsURL
    }

    /// Get storage path for a specific model
    /// - Parameter model: Model to get path for
    /// - Returns: File URL for model storage
    public static func getModelPath(for model: AIModel) -> URL {
        let modelsDir = getModelsDirectory()
        let modelDir = modelsDir.appendingPathComponent(model.id, isDirectory: true)
        return modelDir.appendingPathComponent("\(model.id).bin")
    }

    /// Get metadata storage path for a model
    /// - Parameter modelId: Model ID
    /// - Returns: File URL for metadata
    public static func getMetadataPath(for modelId: String) -> URL {
        let modelsDir = getModelsDirectory()
        let modelDir = modelsDir.appendingPathComponent(modelId, isDirectory: true)
        return modelDir.appendingPathComponent(metadataFileName)
    }

    // MARK: - Cache Management

    /// Get current cache size
    /// - Returns: Total size of all models in cache
    public static func getCacheSize() -> Int64 {
        let fileManager = FileManager.default
        let modelsDir = getModelsDirectory()

        var totalSize: Int64 = 0

        if let enumerator = fileManager.enumerator(atPath: modelsDir.path) {
            for case let file as String in enumerator {
                let filePath = modelsDir.appendingPathComponent(file).path
                if let attributes = try? fileManager.attributesOfItem(atPath: filePath),
                   let fileSize = attributes[.size] as? Int64 {
                    totalSize += fileSize
                }
            }
        }

        return totalSize
    }

    /// Check if cache is full
    /// - Returns: True if cache size exceeds maximum
    public static func isCacheFull() -> Bool {
        getCacheSize() > maxCacheSize
    }

    /// Get space available for new models
    /// - Returns: Available space in bytes
    public static func getAvailableSpace() -> Int64 {
        max(0, maxCacheSize - getCacheSize())
    }

    /// Clear least recently used models to free space
    /// - Parameter targetSize: Target cache size to achieve
    /// - Returns: Number of models removed
    public static func clearLRUModels(targetSize: Int64) -> Int {
        let fileManager = FileManager.default
        let modelsDir = getModelsDirectory()

        // Get all models with their last access time
        var models: [(id: String, path: URL, accessTime: Date, size: Int64)] = []

        if let enumerator = fileManager.enumerator(atPath: modelsDir.path) {
            for case let subdir as String in enumerator {
                let subdirPath = modelsDir.appendingPathComponent(subdir)
                let metadataPath = subdirPath.appendingPathComponent(metadataFileName)

                if fileManager.fileExists(atPath: metadataPath.path),
                   let attributes = try? fileManager.attributesOfItem(atPath: metadataPath.path),
                   let accessTime = attributes[.contentAccessDate] as? Date {

                    // Calculate total size of this model directory
                    var modelSize: Int64 = 0
                    if let enumerator = fileManager.enumerator(atPath: subdirPath.path) {
                        for case let file as String in enumerator {
                            let filePath = subdirPath.appendingPathComponent(file).path
                            if let attributes = try? fileManager.attributesOfItem(atPath: filePath),
                               let fileSize = attributes[.size] as? Int64 {
                                modelSize += fileSize
                            }
                        }
                    }

                    if modelSize > 0 {
                        models.append((id: subdir, path: subdirPath, accessTime: accessTime, size: modelSize))
                    }
                }
            }
        }

        // Sort by access time (oldest first)
        models.sort { $0.accessTime < $1.accessTime }

        // Remove models until target size is reached
        var removed = 0
        var currentSize = getCacheSize()

        for model in models {
            guard currentSize > targetSize else { break }

            do {
                try fileManager.removeItem(at: model.path)
                currentSize -= model.size
                removed += 1
            } catch {
                print("Failed to remove model \(model.id): \(error)")
            }
        }

        return removed
    }

    // MARK: - Model Storage

    /// Save model metadata
    /// - Parameters:
    ///   - model: Model to save metadata for
    ///   - modelDetail: Detailed model information
    public static func saveModelMetadata(_ model: AIModel, detail: HuggingFaceModelDetail) {
        let fileManager = FileManager.default
        let metadataPath = getMetadataPath(for: model.id)

        // Create directory if needed
        let directory = metadataPath.deletingLastPathComponent()
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        // Create metadata struct
        let metadata = ModelMetadata(
            id: model.id,
            displayName: model.displayName,
            modelDetail: detail,
            storedAt: Date(),
            lastAccessedAt: Date(),
            size: model.size
        )

        // Encode and save
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        do {
            let encoded = try encoder.encode(metadata)
            try encoded.write(to: metadataPath)
        } catch {
            print("Failed to save model metadata: \(error)")
        }
    }

    /// Load model metadata
    /// - Parameter modelId: Model ID to load metadata for
    /// - Returns: Metadata if available
    public static func loadModelMetadata(for modelId: String) -> ModelMetadata? {
        let fileManager = FileManager.default
        let metadataPath = getMetadataPath(for: modelId)

        guard fileManager.fileExists(atPath: metadataPath.path) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let data = try Data(contentsOf: metadataPath)
            return try decoder.decode(ModelMetadata.self, from: data)
        } catch {
            print("Failed to load model metadata: \(error)")
            return nil
        }
    }

    /// Get all stored models
    /// - Returns: Array of AIModel for all stored models
    public static func getAllStoredModels() -> [AIModel] {
        let fileManager = FileManager.default
        let modelsDir = getModelsDirectory()

        var models: [AIModel] = []

        if let enumerator = fileManager.enumerator(atPath: modelsDir.path) {
            for case let modelId as String in enumerator {
                if let metadata = loadModelMetadata(for: modelId) {
                    let modelPath = getModelPath(for: AIModel(
                        id: modelId,
                        displayName: metadata.displayName,
                        version: "1.0",
                        size: metadata.size
                    ))

                    let model = AIModel(
                        id: modelId,
                        displayName: metadata.displayName,
                        version: "1.0",
                        size: metadata.size,
                        localPath: modelPath.path,
                        downloadDate: metadata.storedAt,
                        lastUsed: metadata.lastAccessedAt,
                        capabilities: metadata.modelDetail.tags
                    )

                    models.append(model)
                }
            }
        }

        return models
    }

    /// Delete a stored model
    /// - Parameter modelId: Model ID to delete
    /// - Returns: True if deletion succeeded
    public static func deleteModel(modelId: String) -> Bool {
        let fileManager = FileManager.default
        let modelsDir = getModelsDirectory()
        let modelDir = modelsDir.appendingPathComponent(modelId)

        do {
            try fileManager.removeItem(at: modelDir)
            return true
        } catch {
            print("Failed to delete model: \(error)")
            return false
        }
    }

    /// Update last access time for a model
    /// - Parameter modelId: Model ID to update
    public static func updateLastAccessTime(for modelId: String) {
        guard var metadata = loadModelMetadata(for: modelId) else {
            return
        }

        metadata.lastAccessedAt = Date()
        saveModelMetadata(
            AIModel(
                id: metadata.id,
                displayName: metadata.displayName,
                version: "1.0",
                size: metadata.size
            ),
            detail: metadata.modelDetail
        )
    }
}

// MARK: - Metadata Types

public struct ModelMetadata: Codable {
    public let id: String
    public let displayName: String
    public let modelDetail: HuggingFaceModelDetail
    public let storedAt: Date
    public var lastAccessedAt: Date
    public let size: Int64

    public init(
        id: String,
        displayName: String,
        modelDetail: HuggingFaceModelDetail,
        storedAt: Date,
        lastAccessedAt: Date,
        size: Int64
    ) {
        self.id = id
        self.displayName = displayName
        self.modelDetail = modelDetail
        self.storedAt = storedAt
        self.lastAccessedAt = lastAccessedAt
        self.size = size
    }
}
