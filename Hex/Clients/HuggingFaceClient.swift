import Foundation
import ComposableArchitecture

/// HuggingFaceClient protocol defines the interface for model discovery and download from Hugging Face Hub.
public protocol HuggingFaceClientProtocol: Sendable {
    /// Search for models on Hugging Face Hub
    /// - Parameters:
    ///   - query: Search query string
    ///   - task: Optional task filter (e.g., "text-generation")
    ///   - limit: Maximum number of results (default: 10)
    /// - Returns: Array of model metadata
    /// - Throws: HuggingFaceClientError if search fails
    func searchModels(
        query: String,
        task: String?,
        limit: Int
    ) async throws -> [HuggingFaceModel]

    /// Get detailed information about a specific model
    /// - Parameter modelId: Hugging Face model identifier (e.g., "microsoft/DialoGPT-medium")
    /// - Returns: Detailed model information including Core ML compatibility
    /// - Throws: HuggingFaceClientError if model not found
    func getModelInfo(modelId: String) async throws -> HuggingFaceModelDetail

    /// Initiate model download
    /// - Parameters:
    ///   - modelId: Hugging Face model identifier
    ///   - destination: Local file path where model should be saved
    /// - Returns: Download ID for tracking progress
    /// - Throws: HuggingFaceClientError if download cannot be started
    func startDownload(
        modelId: String,
        destination: String
    ) async throws -> String

    /// Check download progress
    /// - Parameter downloadId: ID returned from startDownload
    /// - Returns: Download progress information
    /// - Throws: HuggingFaceClientError if download not found
    func getDownloadProgress(downloadId: String) async throws -> HuggingFaceDownloadProgress

    /// Cancel an ongoing download
    /// - Parameter downloadId: ID of download to cancel
    /// - Throws: HuggingFaceClientError if download not found
    func cancelDownload(downloadId: String) async throws
}

/// Metadata for a Hugging Face model (search result)
public struct HuggingFaceModel: Codable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let task: String
    public let downloads: Int
    public let size: Int64

    public init(id: String, name: String, task: String, downloads: Int, size: Int64) {
        self.id = id
        self.name = name
        self.task = task
        self.downloads = downloads
        self.size = size
    }
}

/// Detailed model information
public struct HuggingFaceModelDetail: Codable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let tags: [String]
    public let downloads: Int
    public let size: Int64
    public let coreMlCompatible: Bool

    public init(
        id: String,
        name: String,
        description: String,
        tags: [String],
        downloads: Int,
        size: Int64,
        coreMlCompatible: Bool
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.tags = tags
        self.downloads = downloads
        self.size = size
        self.coreMlCompatible = coreMlCompatible
    }
}

/// Download progress information
public struct HuggingFaceDownloadProgress: Sendable {
    public let downloadId: String
    public let status: DownloadStatus
    public let progress: Double // 0.0 to 1.0
    public let bytesDownloaded: Int64
    public let totalBytes: Int64

    public init(
        downloadId: String,
        status: DownloadStatus,
        progress: Double,
        bytesDownloaded: Int64,
        totalBytes: Int64
    ) {
        self.downloadId = downloadId
        self.status = status
        self.progress = progress
        self.bytesDownloaded = bytesDownloaded
        self.totalBytes = totalBytes
    }
}

/// Status of a download
public enum DownloadStatus: String, Codable, Sendable {
    case started
    case downloading
    case completed
    case failed
    case cancelled
}

/// Errors that can occur in HuggingFaceClient operations
public enum HuggingFaceClientError: LocalizedError, Sendable {
    case networkError(String)
    case modelNotFound(String)
    case downloadFailed(String)
    case invalidModel(String)
    case storageError(String)

    public var errorDescription: String? {
        switch self {
        case .networkError(let reason):
            return "Network error: \(reason)"
        case .modelNotFound(let id):
            return "Model not found: \(id)"
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .invalidModel(let reason):
            return "Invalid model: \(reason)"
        case .storageError(let reason):
            return "Storage error: \(reason)"
        }
    }
}

/// Mock implementation for testing
public struct HuggingFaceClientMock: HuggingFaceClientProtocol {
    private let mockModels: [HuggingFaceModel]

    public init(mockModels: [HuggingFaceModel] = []) {
        self.mockModels = mockModels
    }

    public func searchModels(
        query: String,
        task: String?,
        limit: Int
    ) async throws -> [HuggingFaceModel] {
        return Array(mockModels.prefix(limit))
    }

    public func getModelInfo(modelId: String) async throws -> HuggingFaceModelDetail {
        return HuggingFaceModelDetail(
            id: modelId,
            name: "Mock Model",
            description: "Mock description",
            tags: ["mock"],
            downloads: 1000,
            size: 512_000_000,
            coreMlCompatible: true
        )
    }

    public func startDownload(
        modelId: String,
        destination: String
    ) async throws -> String {
        return UUID().uuidString
    }

    public func getDownloadProgress(downloadId: String) async throws -> HuggingFaceDownloadProgress {
        return HuggingFaceDownloadProgress(
            downloadId: downloadId,
            status: .completed,
            progress: 1.0,
            bytesDownloaded: 512_000_000,
            totalBytes: 512_000_000
        )
    }

    public func cancelDownload(downloadId: String) async throws {
        // Mock: always succeeds
    }
}

/// Live implementation of HuggingFaceClient (API calls)
/// 
/// This is a placeholder for Hugging Face Hub integration.
/// Future implementation will:
/// 1. Make REST API calls to https://huggingface.co/api
/// 2. Support model search with task and query filtering
/// 3. Provide model metadata (size, downloads, compatibility)
/// 4. Handle model downloads with progress tracking
/// 5. Support Core ML compatible model formats
public struct HuggingFaceClient: HuggingFaceClientProtocol {
    private let baseURL = "https://huggingface.co/api"
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func searchModels(
        query: String,
        task: String?,
        limit: Int
    ) async throws -> [HuggingFaceModel] {
        // TODO: Implement Hugging Face API search
        // 1. Construct URL with query parameters
        // 2. Add task filter if provided
        // 3. Make GET request to /api/models
        // 4. Parse JSON response
        // 5. Filter for Core ML compatible models
        // 6. Return array of HuggingFaceModel
        throw HuggingFaceClientError.networkError("Not implemented: API integration pending")
    }

    public func getModelInfo(modelId: String) async throws -> HuggingFaceModelDetail {
        // TODO: Implement Hugging Face API model info
        // 1. Validate modelId format
        // 2. Make GET request to /api/models/{modelId}
        // 3. Parse JSON response
        // 4. Check Core ML compatibility
        // 5. Return detailed model information
        throw HuggingFaceClientError.modelNotFound(modelId)
    }

    public func startDownload(
        modelId: String,
        destination: String
    ) async throws -> String {
        // TODO: Implement download initiation
        // 1. Validate modelId and destination path
        // 2. Create destination directory if needed
        // 3. Fetch model file from Hugging Face
        // 4. Support resume on interrupted downloads
        // 5. Return unique download ID for tracking
        throw HuggingFaceClientError.downloadFailed("Not implemented: Download API pending")
    }

    public func getDownloadProgress(downloadId: String) async throws -> HuggingFaceDownloadProgress {
        // TODO: Implement progress tracking
        // 1. Query download state by ID
        // 2. Calculate progress percentage
        // 3. Return current bytes downloaded vs total
        // 4. Handle completed/failed states
        throw HuggingFaceClientError.downloadFailed("Not implemented: Progress tracking pending")
    }

    public func cancelDownload(downloadId: String) async throws {
        // TODO: Implement download cancellation
        // 1. Find download task by ID
        // 2. Stop URLSessionDownloadTask
        // 3. Optionally clean up partial file
        // 4. Update download state
    }
}

// MARK: - TCA Dependency

extension DependencyValues {
    public var huggingFaceClient: HuggingFaceClientProtocol {
        get { self[HuggingFaceClientKey.self] }
        set { self[HuggingFaceClientKey.self] = newValue }
    }
}

private enum HuggingFaceClientKey: DependencyKey {
    static let liveValue: HuggingFaceClientProtocol = HuggingFaceClient()
    static let previewValue: HuggingFaceClientProtocol = HuggingFaceClientMock()
    static let testValue: HuggingFaceClientProtocol = HuggingFaceClientMock()
}
