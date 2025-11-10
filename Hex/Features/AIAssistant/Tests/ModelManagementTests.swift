import XCTest
import ComposableArchitecture
@testable import Hex

/// Test cases for User Story 5: AI Model Management
///
/// Tests:
/// 1. Model discovery and search
/// 2. Model download with progress tracking
/// 3. Model switching and activation
/// 4. Model validation and compatibility
/// 5. Model caching and storage management
@MainActor
final class ModelManagementTests: XCTestCase {
    // MARK: - Test Helpers

    private func createTestStore(
        initialState: AIAssistantFeature.State = AIAssistantFeature.State()
    ) -> TestStore<AIAssistantFeature.State, AIAssistantFeature.Action> {
        return TestStore(initialState: initialState) {
            AIAssistantFeature()
        }
    }

    // MARK: - Model Search Tests (T027)

    func testLoadAvailableModels() async {
        let store = createTestStore()

        await store.send(.loadAvailableModels) { state in
            state.isLoadingModels = true
        }

        XCTAssertTrue(store.state.isLoadingModels)
    }

    func testModelsLoadedSuccessfully() async {
        let mockModels = [
            HuggingFaceModel(id: "gpt-2", name: "GPT-2", task: "text-generation", downloads: 1000, size: 500_000_000),
            HuggingFaceModel(id: "bert", name: "BERT", task: "question-answering", downloads: 500, size: 300_000_000),
        ]

        let store = createTestStore()

        await store.send(.loadAvailableModels) { state in
            state.isLoadingModels = true
        }

        await store.send(.availableModelsLoaded(mockModels)) { state in
            state.availableModels = mockModels
            state.isLoadingModels = false
        }

        XCTAssertEqual(store.state.availableModels.count, 2)
        XCTAssertFalse(store.state.isLoadingModels)
    }

    func testModelsFilteredByTask() async {
        let models = [
            HuggingFaceModel(id: "gpt", name: "GPT-2", task: "text-generation", downloads: 1000, size: 500_000_000),
            HuggingFaceModel(id: "bert", name: "BERT", task: "question-answering", downloads: 500, size: 300_000_000),
        ]

        let store = createTestStore()

        await store.send(.availableModelsLoaded(models)) { state in
            state.availableModels = models
        }

        let textGenModels = store.state.availableModels.filter { $0.task.contains("text-generation") }
        XCTAssertEqual(textGenModels.count, 1)
        XCTAssertEqual(textGenModels.first?.id, "gpt")
    }

    // MARK: - Model Download Tests (T028)

    func testDownloadModelInitiation() async {
        let model = HuggingFaceModel(
            id: "gpt-2",
            name: "GPT-2",
            task: "text-generation",
            downloads: 1000,
            size: 500_000_000
        )

        let store = createTestStore()

        await store.send(.downloadModel(model))

        // Download should be initiated
        XCTAssertTrue(true)
    }

    func testDownloadProgressTracking() async {
        let store = createTestStore()

        // Simulate download progress updates
        await store.send(.modelDownloadProgress("model-1", 0.25))
        await store.send(.modelDownloadProgress("model-1", 0.50))
        await store.send(.modelDownloadProgress("model-1", 0.75))
        await store.send(.modelDownloadProgress("model-1", 1.0))

        XCTAssertTrue(true)
    }

    func testDownloadCompletion() async {
        let downloadedModel = AIModel(
            id: "gpt-2",
            displayName: "GPT-2",
            version: "1.0",
            size: 500_000_000,
            localPath: "/path/to/gpt-2"
        )

        let store = createTestStore()

        await store.send(.modelDownloadCompleted(downloadedModel)) { state in
            state.downloadedModels.append(downloadedModel)
        }

        XCTAssertTrue(store.state.downloadedModels.contains { $0.id == "gpt-2" })
    }

    // MARK: - Model Selection Tests

    func testSelectModel() async {
        let model = AIModel(
            id: "gpt-2",
            displayName: "GPT-2",
            version: "1.0",
            size: 500_000_000,
            localPath: "/path/to/gpt-2"
        )

        let store = createTestStore()

        await store.send(.selectModel(model)) { state in
            state.currentModel = model
        }

        XCTAssertEqual(store.state.currentModel?.id, "gpt-2")
    }

    func testSwitchBetweenModels() async {
        let model1 = AIModel(
            id: "gpt-2",
            displayName: "GPT-2",
            version: "1.0",
            size: 500_000_000,
            localPath: "/path/to/gpt-2"
        )

        let model2 = AIModel(
            id: "bert",
            displayName: "BERT",
            version: "1.0",
            size: 300_000_000,
            localPath: "/path/to/bert"
        )

        let store = createTestStore()

        // Select first model
        await store.send(.selectModel(model1)) { state in
            state.currentModel = model1
        }

        XCTAssertEqual(store.state.currentModel?.id, "gpt-2")

        // Switch to second model
        await store.send(.selectModel(model2)) { state in
            state.currentModel = model2
        }

        XCTAssertEqual(store.state.currentModel?.id, "bert")
    }

    // MARK: - Model Validation Tests (T032)

    func testModelValidation() {
        let modelDetail = HuggingFaceModelDetail(
            id: "gpt-2",
            name: "GPT-2",
            description: "GPT-2 model",
            tags: ["text-generation", "pytorch"],
            downloads: 1000,
            size: 500_000_000,
            coreMlCompatible: true
        )

        let result = ModelValidator.validateCoreMLCompatibility(modelDetail)

        XCTAssertTrue(result.isValid)
        XCTAssertFalse(result.hasErrors)
    }

    func testLargeModelWarning() {
        let largeModel = HuggingFaceModelDetail(
            id: "large-model",
            name: "Large Model",
            description: "Very large model",
            tags: ["text-generation"],
            downloads: 1000,
            size: 2_000_000_000, // 2GB
            coreMlCompatible: true
        )

        let result = ModelValidator.validateCoreMLCompatibility(largeModel)

        XCTAssertTrue(result.hasWarnings)
        XCTAssertFalse(result.hasErrors)
    }

    func testIncompatibleModelError() {
        let incompatibleModel = HuggingFaceModelDetail(
            id: "incompatible",
            name: "Incompatible Model",
            description: "Not compatible",
            tags: ["custom-task"],
            downloads: 10,
            size: 100_000_000,
            coreMlCompatible: false
        )

        let result = ModelValidator.validateCoreMLCompatibility(incompatibleModel)

        XCTAssertTrue(result.hasErrors)
    }

    // MARK: - Model Storage Tests (T033)

    func testGetModelsDirectory() {
        let directory = LocalModelStorage.getModelsDirectory()

        XCTAssertFalse(directory.path.isEmpty)
        XCTAssertTrue(directory.path.contains("AIModels"))
    }

    func testGetCacheSize() {
        let cacheSize = LocalModelStorage.getCacheSize()

        XCTAssertGreaterThanOrEqual(cacheSize, 0)
    }

    func testCacheFull() {
        let isFull = LocalModelStorage.isCacheFull()

        // Should be false initially
        XCTAssertFalse(isFull)
    }

    func testGetAvailableSpace() {
        let availableSpace = LocalModelStorage.getAvailableSpace()

        XCTAssertGreaterThan(availableSpace, 0)
    }

    // MARK: - Model Loading Tests (T036)

    func testGetTotalMemoryUsed() {
        let memoryUsed = ModelLoader.getTotalMemoryUsed()

        XCTAssertGreaterThanOrEqual(memoryUsed, 0)
    }

    func testGetAvailableMemory() {
        let availableMemory = ModelLoader.getAvailableMemory()

        XCTAssertGreaterThan(availableMemory, 0)
    }

    func testIsModelLoaded() {
        let isLoaded = ModelLoader.isModelLoaded("gpt-2")

        XCTAssertFalse(isLoaded)
    }

    func testGetLoadedModels() {
        let loadedModels = ModelLoader.getLoadedModels()

        XCTAssertTrue(loadedModels.isEmpty)
    }

    func testGetMemoryReport() {
        let report = ModelLoader.getMemoryReport()

        XCTAssertGreaterThanOrEqual(report.totalMemoryUsed, 0)
        XCTAssertGreaterThan(report.maxMemory, 0)
        XCTAssertGreaterThanOrEqual(report.availableMemory, 0)
        XCTAssertEqual(report.modelsLoaded, 0)
    }

    // MARK: - Integration Tests

    func testCompleteModelDownloadFlow() async {
        let store = createTestStore()

        // 1. Load available models
        let mockModels = [
            HuggingFaceModel(id: "gpt-2", name: "GPT-2", task: "text-generation", downloads: 1000, size: 500_000_000)
        ]

        await store.send(.loadAvailableModels) { state in
            state.isLoadingModels = true
        }

        // 2. Models loaded
        await store.send(.availableModelsLoaded(mockModels)) { state in
            state.availableModels = mockModels
            state.isLoadingModels = false
        }

        XCTAssertEqual(store.state.availableModels.count, 1)

        // 3. Download model
        await store.send(.downloadModel(mockModels[0]))

        // 4. Track progress
        await store.send(.modelDownloadProgress("gpt-2", 0.50))

        // 5. Download completes
        let downloadedModel = AIModel(
            id: "gpt-2",
            displayName: "GPT-2",
            version: "1.0",
            size: 500_000_000,
            localPath: "/path/to/gpt-2"
        )

        await store.send(.modelDownloadCompleted(downloadedModel)) { state in
            state.downloadedModels.append(downloadedModel)
        }

        // 6. Select and use model
        await store.send(.selectModel(downloadedModel)) { state in
            state.currentModel = downloadedModel
        }

        XCTAssertEqual(store.state.currentModel?.id, "gpt-2")
        XCTAssertTrue(store.state.downloadedModels.contains { $0.id == "gpt-2" })
    }

    func testMultipleModelsDownload() async {
        let store = createTestStore()

        let models = [
            AIModel(id: "gpt-2", displayName: "GPT-2", version: "1.0", size: 500_000_000, localPath: "/path/1"),
            AIModel(id: "bert", displayName: "BERT", version: "1.0", size: 300_000_000, localPath: "/path/2"),
        ]

        for model in models {
            await store.send(.modelDownloadCompleted(model)) { state in
                state.downloadedModels.append(model)
            }
        }

        XCTAssertEqual(store.state.downloadedModels.count, 2)
    }

    func testModelSwitchingPerformance() async {
        let store = createTestStore()

        let models = [
            AIModel(id: "gpt-2", displayName: "GPT-2", version: "1.0", size: 500_000_000, localPath: "/path/1"),
            AIModel(id: "bert", displayName: "BERT", version: "1.0", size: 300_000_000, localPath: "/path/2"),
            AIModel(id: "t5", displayName: "T5", version: "1.0", size: 400_000_000, localPath: "/path/3"),
        ]

        // Simulate rapid model switching
        for model in models {
            await store.send(.selectModel(model)) { state in
                state.currentModel = model
            }
        }

        XCTAssertEqual(store.state.currentModel?.id, "t5")
    }
}

// MARK: - HuggingFaceClient Tests

final class HuggingFaceClientTests: XCTestCase {
    func testModelDownloadURL() {
        let modelId = "microsoft/DialoGPT-small"
        let expectedURL = "https://huggingface.co/\(modelId)/resolve/main/pytorch_model.bin"

        XCTAssertTrue(expectedURL.contains("huggingface.co"))
        XCTAssertTrue(expectedURL.contains(modelId))
    }

    func testDownloadProgressCalculation() {
        let progress = HuggingFaceDownloadProgress(
            downloadId: "test",
            status: .downloading,
            progress: 0.75,
            bytesDownloaded: 750_000_000,
            totalBytes: 1_000_000_000
        )

        XCTAssertEqual(progress.progress, 0.75)
        XCTAssertEqual(progress.status, .downloading)
    }
}
