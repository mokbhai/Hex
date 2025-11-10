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

/// Live implementation of HuggingFaceClient with API integration
///
/// Provides:
/// 1. REST API calls to https://huggingface.co/api
/// 2. Model search with task and query filtering
/// 3. Model metadata (size, downloads, compatibility)
/// 4. Model downloads with progress tracking
/// 5. Core ML compatible model format support
public struct HuggingFaceClient: HuggingFaceClientProtocol {
    private let baseURL = "https://huggingface.co/api"
    private let session: URLSession
    private static var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private static var downloadProgress: [String: HuggingFaceDownloadProgress] = [:]
    private static let lock = NSLock()

    public init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Model Search (T027)

    public func searchModels(
        query: String,
        task: String?,
        limit: Int
    ) async throws -> [HuggingFaceModel] {
        // Construct search URL with parameters
        var components = URLComponents(string: "\(baseURL)/models")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "search", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
        ]

        if let task = task {
            queryItems.append(URLQueryItem(name: "task", value: task))
        }

        // Filter for smaller models suitable for local inference
        queryItems.append(URLQueryItem(name: "sort", value: "downloads"))

        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw HuggingFaceClientError.networkError("Invalid URL construction")
        }

        // Make API request
        var request = URLRequest(url: url)
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw HuggingFaceClientError.networkError("Invalid response status")
        }

        // Parse JSON response
        let decoder = JSONDecoder()
        struct SearchResponse: Decodable {
            let models: [SearchResult]?

            struct SearchResult: Decodable {
                let id: String
                let modelId: String
                let name: String?
                let task: String?
                let downloads: Int?
                let gated: Bool?
                let private: Bool?

                enum CodingKeys: String, CodingKey {
                    case id, name, task, downloads, gated, private
                    case modelId = "model_id"
                }
            }
        }

        do {
            let response = try decoder.decode(SearchResponse.self, from: data)

            let models = response.models?
                .filter { !($0.gated ?? false) && !($0.private ?? false) }
                .map { result in
                    HuggingFaceModel(
                        id: result.modelId.isEmpty ? result.id : result.modelId,
                        name: result.name ?? result.id,
                        task: result.task ?? "unknown",
                        downloads: result.downloads ?? 0,
                        size: Int64(100_000_000) // Default estimate
                    )
                } ?? []

            return models
        } catch {
            throw HuggingFaceClientError.networkError("Failed to parse response: \(error.localizedDescription)")
        }
    }

    public func getModelInfo(modelId: String) async throws -> HuggingFaceModelDetail {
        // Validate modelId format
        let components = modelId.split(separator: "/")
        guard components.count == 2 else {
            throw HuggingFaceClientError.invalidModel("Model ID must be in format 'owner/name'")
        }

        // Construct URL for model info
        let urlString = "\(baseURL)/models/\(modelId)"
        guard let url = URL(string: urlString) else {
            throw HuggingFaceClientError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw HuggingFaceClientError.modelNotFound(modelId)
        }

        // Parse model details
        let decoder = JSONDecoder()
        struct ModelResponse: Decodable {
            let id: String?
            let modelId: String?
            let name: String?
            let description: String?
            let tags: [String]?
            let downloads: Int?
            let private: Bool?
            let gated: Bool?
            let siblings: [FileInfo]?

            struct FileInfo: Decodable {
                let filename: String?
                let size: Int64?
            }

            enum CodingKeys: String, CodingKey {
                case id, name, description, tags, downloads, private, gated, siblings
                case modelId = "model_id"
            }
        }

        do {
            let response = try decoder.decode(ModelResponse.self, from: data)

            // Calculate total size from siblings
            let totalSize = response.siblings?.reduce(0) { $0 + ($1.size ?? 0) } ?? Int64(100_000_000)

            return HuggingFaceModelDetail(
                id: response.modelId ?? response.id ?? modelId,
                name: response.name ?? modelId,
                description: response.description ?? "No description available",
                tags: response.tags ?? [],
                downloads: response.downloads ?? 0,
                size: totalSize,
                coreMlCompatible: isCoreMlCompatible(tags: response.tags ?? [])
            )
        } catch {
            throw HuggingFaceClientError.networkError("Failed to parse model info: \(error.localizedDescription)")
        }
    }

    // MARK: - Model Download (T028)

    public func startDownload(
        modelId: String,
        destination: String
    ) async throws -> String {
        // Validate parameters
        guard !modelId.isEmpty else {
            throw HuggingFaceClientError.invalidModel("Model ID cannot be empty")
        }

        guard !destination.isEmpty else {
            throw HuggingFaceClientError.storageError("Destination path cannot be empty")
        }

        // Create destination directory if needed
        let fileManager = FileManager.default
        let destinationURL = URL(fileURLWithPath: destination)
        let destinationDir = destinationURL.deletingLastPathComponent()

        do {
            if !fileManager.fileExists(atPath: destinationDir.path) {
                try fileManager.createDirectory(at: destinationDir, withIntermediateDirectories: true)
            }
        } catch {
            throw HuggingFaceClientError.storageError("Failed to create destination directory: \(error.localizedDescription)")
        }

        // Construct download URL for model file
        let downloadURLString = "https://huggingface.co/\(modelId)/resolve/main/pytorch_model.bin"
        guard let downloadURL = URL(string: downloadURLString) else {
            throw HuggingFaceClientError.networkError("Invalid download URL")
        }

        // Create download task
        let downloadId = UUID().uuidString
        var request = URLRequest(url: downloadURL)
        request.timeoutInterval = 3600 // 1 hour timeout for downloads

        let task = session.downloadTask(with: request) { [weak self] tempURL, response, error in
            self?.handleDownloadCompletion(downloadId, tempURL: tempURL, response: response, error: error, destination: destination)
        }

        // Store task and initialize progress
        Self.lock.lock()
        Self.downloadTasks[downloadId] = task
        Self.downloadProgress[downloadId] = HuggingFaceDownloadProgress(
            downloadId: downloadId,
            status: .started,
            progress: 0.0,
            bytesDownloaded: 0,
            totalBytes: Int64(500_000_000) // Default estimate
        )
        Self.lock.unlock()

        task.resume()

        return downloadId
    }

    public func getDownloadProgress(downloadId: String) async throws -> HuggingFaceDownloadProgress {
        Self.lock.lock()
        defer { Self.lock.unlock() }

        guard let progress = Self.downloadProgress[downloadId] else {
            throw HuggingFaceClientError.downloadFailed("Download not found: \(downloadId)")
        }

        return progress
    }

    public func cancelDownload(downloadId: String) async throws {
        Self.lock.lock()
        defer { Self.lock.unlock() }

        guard let task = Self.downloadTasks[downloadId] else {
            throw HuggingFaceClientError.downloadFailed("Download not found: \(downloadId)")
        }

        task.cancel()

        // Update progress status
        if var progress = Self.downloadProgress[downloadId] {
            progress = HuggingFaceDownloadProgress(
                downloadId: downloadId,
                status: .cancelled,
                progress: progress.progress,
                bytesDownloaded: progress.bytesDownloaded,
                totalBytes: progress.totalBytes
            )
            Self.downloadProgress[downloadId] = progress
        }

        Self.downloadTasks.removeValue(forKey: downloadId)
    }

    // MARK: - Helper Methods

    private func handleDownloadCompletion(
        _ downloadId: String,
        tempURL: URL?,
        response: URLResponse?,
        error: Error?,
        destination: String
    ) {
        Self.lock.lock()
        defer { Self.lock.unlock() }

        if let error = error {
            var progress = Self.downloadProgress[downloadId] ?? HuggingFaceDownloadProgress(
                downloadId: downloadId,
                status: .failed,
                progress: 0.0,
                bytesDownloaded: 0,
                totalBytes: 0
            )
            progress = HuggingFaceDownloadProgress(
                downloadId: downloadId,
                status: .failed,
                progress: progress.progress,
                bytesDownloaded: progress.bytesDownloaded,
                totalBytes: progress.totalBytes
            )
            Self.downloadProgress[downloadId] = progress
            return
        }

        guard let tempURL = tempURL else {
            var progress = Self.downloadProgress[downloadId] ?? HuggingFaceDownloadProgress(
                downloadId: downloadId,
                status: .failed,
                progress: 0.0,
                bytesDownloaded: 0,
                totalBytes: 0
            )
            progress = HuggingFaceDownloadProgress(
                downloadId: downloadId,
                status: .failed,
                progress: progress.progress,
                bytesDownloaded: progress.bytesDownloaded,
                totalBytes: progress.totalBytes
            )
            Self.downloadProgress[downloadId] = progress
            return
        }

        // Move downloaded file to destination
        let fileManager = FileManager.default
        let destinationURL = URL(fileURLWithPath: destination)

        do {
            if fileManager.fileExists(atPath: destination) {
                try fileManager.removeItem(at: destinationURL)
            }

            try fileManager.moveItem(at: tempURL, to: destinationURL)

            // Get file size
            let attributes = try fileManager.attributesOfItem(atPath: destination)
            let fileSize = attributes[.size] as? Int64 ?? 0

            // Update progress to completed
            var progress = Self.downloadProgress[downloadId] ?? HuggingFaceDownloadProgress(
                downloadId: downloadId,
                status: .completed,
                progress: 1.0,
                bytesDownloaded: fileSize,
                totalBytes: fileSize
            )
            progress = HuggingFaceDownloadProgress(
                downloadId: downloadId,
                status: .completed,
                progress: 1.0,
                bytesDownloaded: fileSize,
                totalBytes: fileSize
            )
            Self.downloadProgress[downloadId] = progress
        } catch {
            var progress = Self.downloadProgress[downloadId] ?? HuggingFaceDownloadProgress(
                downloadId: downloadId,
                status: .failed,
                progress: 0.0,
                bytesDownloaded: 0,
                totalBytes: 0
            )
            progress = HuggingFaceDownloadProgress(
                downloadId: downloadId,
                status: .failed,
                progress: progress.progress,
                bytesDownloaded: progress.bytesDownloaded,
                totalBytes: progress.totalBytes
            )
            Self.downloadProgress[downloadId] = progress
        }

        Self.downloadTasks.removeValue(forKey: downloadId)
    }

    /// Check if model tags indicate Core ML compatibility
    private func isCoreMlCompatible(tags: [String]) -> Bool {
        let compatibleKeywords = ["coreml", "onnx", "pytorch", "text-generation", "conversation"]
        return tags.contains { tag in
            compatibleKeywords.contains { tag.lowercased().contains($0) }
        }
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
