import Foundation
import ComposableArchitecture

/// Manages model selection, activation, and switching
/// Coordinates between model discovery (HuggingFaceClient), validation (ModelValidator),
/// storage (LocalModelStorage), and loading (ModelLoader)
actor ModelManager {
    // MARK: - Types

    enum ModelManagerError: LocalizedError {
        case modelNotFound(String)
        case validationFailed(String)
        case loadingFailed(String)
        case switchingFailed(String)
        case noModelSelected

        var errorDescription: String? {
            switch self {
            case .modelNotFound(let modelId):
                return "Model not found: \(modelId)"
            case .validationFailed(let reason):
                return "Model validation failed: \(reason)"
            case .loadingFailed(let reason):
                return "Failed to load model: \(reason)"
            case .switchingFailed(let reason):
                return "Failed to switch model: \(reason)"
            case .noModelSelected:
                return "No model is currently selected"
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .modelNotFound(let modelId):
                return "Try downloading \(modelId) first from the model browser"
            case .validationFailed:
                return "Ensure the model is Core ML compatible and meets system requirements"
            case .loadingFailed:
                return "Check available system memory and try again"
            case .switchingFailed:
                return "Close other applications to free memory and try switching models"
            case .noModelSelected:
                return "Select a model from the available models list"
            }
        }
    }

    struct ModelInfo: Equatable, Codable {
        let modelId: String
        let name: String
        let description: String
        let size: Int
        let taskType: String
        let isSelected: Bool
        let isLoaded: Bool
        let lastUsed: Date?
    }

    // MARK: - Properties

    private let huggingFaceClient: HuggingFaceClient
    private let validator: ModelValidator
    private let storage: LocalModelStorage
    private let loader: ModelLoader

    private var selectedModelId: String?
    private var loadedModelId: String?
    private var modelCache: [String: HuggingFaceModelDetail] = [:]

    // MARK: - Initialization

    init(
        huggingFaceClient: HuggingFaceClient,
        validator: ModelValidator = .init(),
        storage: LocalModelStorage = .init(),
        loader: ModelLoader = .init()
    ) {
        self.huggingFaceClient = huggingFaceClient
        self.validator = validator
        self.storage = storage
        self.loader = loader

        // Load last selected model from storage
        if let lastSelected = UserDefaults.standard.string(forKey: "lastSelectedModel") {
            self.selectedModelId = lastSelected
        }
    }

    // MARK: - Model Selection

    /// Select a model by ID, preparing it for use without loading into memory
    /// - Parameter modelId: The model identifier (e.g., "TheBloke/Mistral-7B-v0.1-GGUF")
    /// - Throws: ModelManagerError if model validation fails
    func selectModel(_ modelId: String) async throws {
        // Check if model exists locally
        let storedModels = await storage.getAllStoredModels()
        let modelExists = storedModels.contains { $0.modelId == modelId }

        if !modelExists {
            throw ModelManagerError.modelNotFound(modelId)
        }

        // Validate the selected model
        let validationResult = await validator.validateModelFile(
            modelId: modelId,
            storagePath: await storage.getModelsDirectory().appendingPathComponent(modelId)
        )

        if case .failed(let reason) = validationResult {
            throw ModelManagerError.validationFailed(reason)
        }

        // Update selection
        selectedModelId = modelId
        UserDefaults.standard.set(modelId, forKey: "lastSelectedModel")
    }

    /// Switch to a different model, unloading the current one if needed
    /// - Parameter modelId: The model to switch to
    /// - Throws: ModelManagerError if switching fails
    func switchToModel(_ modelId: String) async throws {
        // First unload the currently loaded model
        if let currentModelId = loadedModelId {
            await loader.unloadModel(currentModelId)
            loadedModelId = nil
        }

        // Then load the new model
        do {
            let modelPath = await storage.getModelsDirectory().appendingPathComponent(modelId)
            _ = try await loader.loadModel(modelId, fromPath: modelPath)
            loadedModelId = modelId
            selectedModelId = modelId
            UserDefaults.standard.set(modelId, forKey: "lastSelectedModel")
        } catch {
            throw ModelManagerError.switchingFailed(error.localizedDescription)
        }
    }

    // MARK: - Model Retrieval

    /// Get information about the currently selected model
    /// - Returns: ModelInfo for the selected model
    /// - Throws: ModelManagerError if no model is selected
    func getSelectedModel() async throws -> ModelInfo {
        guard let modelId = selectedModelId else {
            throw ModelManagerError.noModelSelected
        }

        let storedModels = await storage.getAllStoredModels()
        guard let modelMetadata = storedModels.first(where: { $0.modelId == modelId }) else {
            throw ModelManagerError.modelNotFound(modelId)
        }

        return ModelInfo(
            modelId: modelMetadata.modelId,
            name: modelMetadata.modelName,
            description: modelMetadata.modelDescription,
            size: modelMetadata.fileSizeBytes,
            taskType: modelMetadata.taskType,
            isSelected: true,
            isLoaded: loadedModelId == modelId,
            lastUsed: modelMetadata.lastAccessedDate
        )
    }

    /// Get all available models
    /// - Returns: Array of ModelInfo for all stored models
    func getAvailableModels() async -> [ModelInfo] {
        let storedModels = await storage.getAllStoredModels()

        return storedModels.map { metadata in
            ModelInfo(
                modelId: metadata.modelId,
                name: metadata.modelName,
                description: metadata.modelDescription,
                size: metadata.fileSizeBytes,
                taskType: metadata.taskType,
                isSelected: selectedModelId == metadata.modelId,
                isLoaded: loadedModelId == metadata.modelId,
                lastUsed: metadata.lastAccessedDate
            )
        }.sorted { a, b in
            // Sort by: selected first, then loaded, then recently used
            if a.isSelected != b.isSelected {
                return a.isSelected
            }
            if a.isLoaded != b.isLoaded {
                return a.isLoaded
            }
            if let aDate = a.lastUsed, let bDate = b.lastUsed {
                return aDate > bDate
            }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    /// Get model details including size and requirements
    /// - Parameter modelId: The model ID to get details for
    /// - Returns: HuggingFaceModelDetail if available
    /// - Throws: ModelManagerError if model cannot be retrieved
    func getModelDetails(_ modelId: String) async throws -> HuggingFaceModelDetail {
        if let cached = modelCache[modelId] {
            return cached
        }

        do {
            let details = try await huggingFaceClient.getModelInfo(modelId)
            modelCache[modelId] = details
            return details
        } catch {
            throw ModelManagerError.loadingFailed("Could not fetch model details: \(error.localizedDescription)")
        }
    }

    // MARK: - Model Activation

    /// Load a model into memory for inference
    /// - Parameter modelId: The model to load (if nil, uses selected model)
    /// - Throws: ModelManagerError if loading fails
    func loadModelForInference(_ modelId: String? = nil) async throws {
        let targetModelId = modelId ?? selectedModelId
        guard let modelId = targetModelId else {
            throw ModelManagerError.noModelSelected
        }

        // Unload previous model if different
        if let current = loadedModelId, current != modelId {
            await loader.unloadModel(current)
        }

        let modelPath = await storage.getModelsDirectory().appendingPathComponent(modelId)
        do {
            _ = try await loader.loadModel(modelId, fromPath: modelPath)
            loadedModelId = modelId
        } catch {
            throw ModelManagerError.loadingFailed(error.localizedDescription)
        }
    }

    /// Unload the currently loaded model from memory
    func unloadModel() async {
        if let modelId = loadedModelId {
            await loader.unloadModel(modelId)
            loadedModelId = nil
        }
    }

    // MARK: - Memory Management

    /// Get current memory usage report
    /// - Returns: MemoryReport with model-specific breakdown
    func getMemoryReport() async -> ModelLoader.MemoryReport {
        await loader.getMemoryReport()
    }

    /// Optimize memory usage if needed
    func optimizeMemory() async {
        await loader.optimizeMemory()
    }

    // MARK: - Cache Management

    /// Clear the model info cache
    func clearCache() {
        modelCache.removeAll()
    }

    /// Update model last used timestamp
    /// - Parameter modelId: The model that was just used
    func recordModelUsage(_ modelId: String) async {
        await storage.recordModelAccess(modelId)
    }
}

// MARK: - TCA Dependencies

extension DependencyValues {
    var modelManager: ModelManager {
        get { self[ModelManagerKey.self] }
        set { self[ModelManagerKey.self] = newValue }
    }
}

private enum ModelManagerKey: DependencyKey {
    static let liveValue: ModelManager = .init(
        huggingFaceClient: HuggingFaceClient(),
        validator: ModelValidator(),
        storage: LocalModelStorage(),
        loader: ModelLoader()
    )

    static let previewValue: ModelManager = .init(
        huggingFaceClient: HuggingFaceClient(),
        validator: ModelValidator(),
        storage: LocalModelStorage(),
        loader: ModelLoader()
    )

    static let testValue: ModelManager = .init(
        huggingFaceClient: HuggingFaceClient(),
        validator: ModelValidator(),
        storage: LocalModelStorage(),
        loader: ModelLoader()
    )
}
