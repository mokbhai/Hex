import Foundation

/// LocalFileSearcher performs full-text search on local files and directories
///
/// Features:
/// - Search files by name and content
/// - Support for multiple file types
/// - Exclude hidden/system files
/// - Metadata extraction
/// - Search result ranking
///
/// Used by User Story 2: Voice Information Search (T038)
public struct LocalFileSearcher {
    private let searchPaths: [String]
    private let excludedPaths: Set<String>
    private let fileManager: FileManager

    public init(
        searchPaths: [String] = [FileManager.default.homeDirectoryForCurrentUser.path],
        excludedPaths: Set<String> = [".git", ".Trash", ".cache", "node_modules"]
    ) {
        self.searchPaths = searchPaths
        self.excludedPaths = excludedPaths
        self.fileManager = FileManager.default
    }

    // MARK: - File Search

    /// Search for files matching a query
    /// - Parameters:
    ///   - query: Search query (filename or content)
    ///   - limit: Maximum number of results
    /// - Returns: Array of search results
    public func search(query: String, limit: Int = 20) -> [LocalSearchResult] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return []
        }

        var results: [LocalSearchResult] = []

        for searchPath in searchPaths {
            guard fileManager.fileExists(atPath: searchPath) else {
                continue
            }

            let pathResults = searchDirectory(at: searchPath, query: query, limit: limit - results.count)
            results.append(contentsOf: pathResults)

            if results.count >= limit {
                break
            }
        }

        // Sort by relevance
        return results.sorted { $0.relevance > $1.relevance }.prefix(limit).map { $0 }
    }

    // MARK: - Helper Methods

    private func searchDirectory(at path: String, query: String, limit: Int) -> [LocalSearchResult] {
        var results: [LocalSearchResult] = []

        guard let enumerator = fileManager.enumerator(atPath: path) else {
            return results
        }

        let queryLower = query.lowercased()

        for case let file as String in enumerator {
            guard results.count < limit else { break }

            let fullPath = (path as NSString).appendingPathComponent(file)

            // Skip excluded paths
            if shouldExclude(fullPath) {
                enumerator.skipDescendants()
                continue
            }

            // Check filename match
            let filename = (file as NSString).lastPathComponent.lowercased()
            if filename.contains(queryLower) {
                if let result = createSearchResult(path: fullPath, query: query, matchType: .filename) {
                    results.append(result)
                }
            }

            // Check content for text files
            if isTextFile(fullPath) && results.count < limit {
                if let result = searchFileContent(at: fullPath, query: query) {
                    results.append(result)
                }
            }
        }

        return results
    }

    private func searchFileContent(at path: String, query: String) -> LocalSearchResult? {
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            let queryLower = query.lowercased()
            let contentLower = content.lowercased()

            guard contentLower.contains(queryLower) else {
                return nil
            }

            // Extract snippet
            if let range = contentLower.range(of: queryLower) {
                let startIndex = max(0, content.distance(from: content.startIndex, to: range.lowerBound) - 50)
                let endIndex = min(content.count, startIndex + 150)

                let snippet = String(content[content.index(content.startIndex, offsetBy: startIndex)..<content.index(content.startIndex, offsetBy: endIndex)])
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                return LocalSearchResult(
                    path: path,
                    filename: (path as NSString).lastPathComponent,
                    type: getFileType(path),
                    snippet: snippet,
                    matchType: .content,
                    relevance: 0.7
                )
            }

            return nil
        } catch {
            return nil
        }
    }

    private func createSearchResult(path: String, query: String, matchType: LocalSearchResult.MatchType) -> LocalSearchResult? {
        let filename = (path as NSString).lastPathComponent

        // Get file snippet
        var snippet = ""
        if isTextFile(path) {
            do {
                let content = try String(contentsOfFile: path, encoding: .utf8)
                let lines = content.split(separator: "\n", maxSplits: 1)
                snippet = String(lines.first ?? "")
            } catch {
                snippet = ""
            }
        }

        return LocalSearchResult(
            path: path,
            filename: filename,
            type: getFileType(path),
            snippet: snippet.isEmpty ? "File: \(filename)" : snippet,
            matchType: matchType,
            relevance: matchType == .filename ? 0.9 : 0.7
        )
    }

    private func shouldExclude(_ path: String) -> Bool {
        let components = path.split(separator: "/")

        for component in components {
            if excludedPaths.contains(String(component)) {
                return true
            }

            // Skip hidden files/folders
            if String(component).hasPrefix(".") {
                return true
            }
        }

        return false
    }

    private func isTextFile(_ path: String) -> Bool {
        let textExtensions = ["txt", "md", "swift", "py", "js", "json", "xml", "yaml", "yml", "toml", "csv"]
        let ext = (path as NSString).pathExtension.lowercased()
        return textExtensions.contains(ext)
    }

    private func getFileType(_ path: String) -> LocalSearchResult.FileType {
        let ext = (path as NSString).pathExtension.lowercased()

        switch ext {
        case "swift": return .sourceCode
        case "py", "js", "go", "rb": return .sourceCode
        case "txt", "md", "rst": return .document
        case "pdf": return .document
        case "jpg", "png", "gif", "svg": return .image
        case "mp3", "m4a", "wav": return .audio
        case "mp4", "mov", "avi": return .video
        case "zip", "tar", "gz": return .archive
        default: return .other
        }
    }
}

// MARK: - Result Types

public struct LocalSearchResult: Equatable {
    public let path: String
    public let filename: String
    public let type: FileType
    public let snippet: String
    public let matchType: MatchType
    public let relevance: Double // 0.0-1.0

    public enum FileType: String {
        case sourceCode
        case document
        case image
        case audio
        case video
        case archive
        case other
    }

    public enum MatchType {
        case filename
        case content
    }

    public init(
        path: String,
        filename: String,
        type: FileType,
        snippet: String,
        matchType: MatchType,
        relevance: Double
    ) {
        self.path = path
        self.filename = filename
        self.type = type
        self.snippet = snippet
        self.matchType = matchType
        self.relevance = min(1.0, max(0.0, relevance))
    }
}

// MARK: - Mock Implementation

public struct LocalFileSearcherMock: Sendable {
    private let mockResults: [LocalSearchResult]

    public init(mockResults: [LocalSearchResult] = []) {
        self.mockResults = mockResults
    }

    public func search(query: String, limit: Int = 20) -> [LocalSearchResult] {
        return Array(mockResults.prefix(limit))
    }
}
