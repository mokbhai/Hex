import XCTest
import ComposableArchitecture
@testable import Hex

/// Test cases for User Story 2: Voice Information Search
///
/// Tests:
/// 1. Web search functionality
/// 2. Local file search
/// 3. Search result formatting and display
/// 4. Conversation context persistence across searches
@MainActor
final class InformationSearchTests: XCTestCase {
    // MARK: - Test Helpers

    private func createTestStore(
        initialState: AIAssistantFeature.State = AIAssistantFeature.State()
    ) -> TestStore<AIAssistantFeature.State, AIAssistantFeature.Action> {
        return TestStore(initialState: initialState) {
            AIAssistantFeature()
        }
    }

    // MARK: - Web Search Tests (T037)

    func testWebSearchInitiation() async {
        let store = createTestStore()

        await store.send(.searchWeb("SwiftUI")) { state in
            state.lastSearchQuery = "SwiftUI"
            state.isSearching = true
        }

        XCTAssertEqual(store.state.lastSearchQuery, "SwiftUI")
        XCTAssertTrue(store.state.isSearching)
    }

    func testWebSearchCompletion() async {
        let mockResults = [
            AIAssistantFeature.SearchResult(
                id: UUID(),
                title: "SwiftUI Documentation",
                url: "https://developer.apple.com/swiftui",
                snippet: "Declarative UI framework",
                source: .web
            ),
            AIAssistantFeature.SearchResult(
                id: UUID(),
                title: "Learn SwiftUI",
                url: "https://example.com",
                snippet: "SwiftUI tutorial",
                source: .web
            ),
        ]

        let store = createTestStore()

        await store.send(.searchWeb("SwiftUI")) { state in
            state.lastSearchQuery = "SwiftUI"
            state.isSearching = true
        }

        await store.send(.searchCompleted(mockResults)) { state in
            state.searchResults = mockResults
            state.isSearching = false
        }

        XCTAssertEqual(store.state.searchResults.count, 2)
        XCTAssertFalse(store.state.isSearching)
    }

    func testMultipleWebSearches() async {
        let store = createTestStore()

        let queries = ["SwiftUI", "Combine", "Swift Concurrency"]

        for query in queries {
            await store.send(.searchWeb(query)) { state in
                state.lastSearchQuery = query
                state.isSearching = true
            }

            await store.send(.searchCompleted([])) { state in
                state.searchResults = []
                state.isSearching = false
            }

            XCTAssertEqual(store.state.lastSearchQuery, query)
        }
    }

    // MARK: - Local File Search Tests (T038)

    func testLocalFileSearchInitiation() async {
        let store = createTestStore()

        await store.send(.searchLocal("*.swift")) { state in
            state.lastSearchQuery = "*.swift"
            state.isSearching = true
        }

        XCTAssertEqual(store.state.lastSearchQuery, "*.swift")
        XCTAssertTrue(store.state.isSearching)
    }

    func testLocalFileSearchResults() async {
        let mockResults = [
            AIAssistantFeature.SearchResult(
                id: UUID(),
                title: "ContentView.swift",
                url: "/Users/user/Projects/MyApp/ContentView.swift",
                snippet: "struct ContentView: View",
                source: .local
            ),
            AIAssistantFeature.SearchResult(
                id: UUID(),
                title: "AppDelegate.swift",
                url: "/Users/user/Projects/MyApp/AppDelegate.swift",
                snippet: "class AppDelegate:",
                source: .local
            ),
        ]

        let store = createTestStore()

        await store.send(.searchLocal("swift")) { state in
            state.lastSearchQuery = "swift"
            state.isSearching = true
        }

        await store.send(.searchCompleted(mockResults)) { state in
            state.searchResults = mockResults
            state.isSearching = false
        }

        XCTAssertEqual(store.state.searchResults.count, 2)
        let localResults = store.state.searchResults.filter { $0.source == .local }
        XCTAssertEqual(localResults.count, 2)
    }

    func testFileSearchByName() async {
        let store = createTestStore()

        let mockResults = [
            AIAssistantFeature.SearchResult(
                id: UUID(),
                title: "README.md",
                url: "/Projects/README.md",
                snippet: "Project documentation",
                source: .local
            ),
        ]

        await store.send(.searchLocal("README")) { state in
            state.lastSearchQuery = "README"
            state.isSearching = true
        }

        await store.send(.searchCompleted(mockResults)) { state in
            state.searchResults = mockResults
            state.isSearching = false
        }

        XCTAssertEqual(store.state.searchResults.first?.title, "README.md")
    }

    // MARK: - Unified Search Tests

    func testMixedWebAndLocalResults() async {
        let mixedResults = [
            AIAssistantFeature.SearchResult(
                id: UUID(),
                title: "SwiftUI Docs",
                url: "https://apple.com",
                snippet: "Official documentation",
                source: .web
            ),
            AIAssistantFeature.SearchResult(
                id: UUID(),
                title: "MySwiftUIProject.swift",
                url: "/Users/user/Code/MySwiftUIProject.swift",
                snippet: "struct MainView",
                source: .local
            ),
        ]

        let store = createTestStore()

        await store.send(.searchWeb("SwiftUI")) { state in
            state.isSearching = true
        }

        // Results combine web and local
        await store.send(.searchCompleted(mixedResults)) { state in
            state.searchResults = mixedResults
            state.isSearching = false
        }

        let webResults = store.state.searchResults.filter { $0.source == .web }
        let localResults = store.state.searchResults.filter { $0.source == .local }

        XCTAssertEqual(webResults.count, 1)
        XCTAssertEqual(localResults.count, 1)
    }

    // MARK: - Context Persistence Tests (T044 - SC-005)

    func testContextPersistenceAcrossSearches() async {
        let store = createTestStore()

        // First search with context
        await store.send(.addContextInteraction("Search for SwiftUI", "Searching web...", "web_search")) { state in
            state.conversationContext.addInteraction(
                userInput: "Search for SwiftUI",
                aiResponse: "Searching web...",
                context: "web_search"
            )
        }

        XCTAssertEqual(store.state.conversationContext.totalInteractions, 1)

        // Second search
        await store.send(.addContextInteraction("Find local projects", "Searching files...", "local_search")) { state in
            state.conversationContext.addInteraction(
                userInput: "Find local projects",
                aiResponse: "Searching files...",
                context: "local_search"
            )
        }

        XCTAssertEqual(store.state.conversationContext.totalInteractions, 2)

        // Context should be maintained
        let interactions = store.state.conversationContext.interactions
        XCTAssertEqual(interactions.count, 2)
        XCTAssertEqual(interactions[0].userInput, "Search for SwiftUI")
        XCTAssertEqual(interactions[1].userInput, "Find local projects")
    }

    func testContext10InteractionLimit() async {
        let store = createTestStore()

        // Add 15 interactions
        for i in 0..<15 {
            await store.send(.addContextInteraction("Query \(i)", "Response \(i)", nil)) { state in
                state.conversationContext.addInteraction(
                    userInput: "Query \(i)",
                    aiResponse: "Response \(i)",
                    context: nil
                )
            }
        }

        // Should maintain max 10 interactions
        XCTAssertLessThanOrEqual(store.state.conversationContext.totalInteractions, 10)
    }

    // MARK: - Search Result Formatting Tests

    func testSearchResultFormatting() {
        let results = [
            WebSearchResult(
                title: "SwiftUI Tutorial",
                url: "https://example.com",
                snippet: "Learn SwiftUI basics",
                rank: 1
            ),
        ]

        let formatted = WebSearchClient.formatResults(results)

        XCTAssertEqual(formatted.count, 1)
        XCTAssertTrue(formatted[0].contains("SwiftUI Tutorial"))
        XCTAssertTrue(formatted[0].contains("https://example.com"))
    }

    // MARK: - Integration Tests

    func testCompleteWebSearchFlow() async {
        let store = createTestStore()

        // 1. User speaks search command
        await store.send(.processingAudioCompleted("Search Google for SwiftUI")) { state in
            state.conversationContext.addInteraction(
                userInput: "Search Google for SwiftUI",
                aiResponse: "Searching...",
                context: nil
            )
        }

        // 2. Command is recognized as search
        await store.send(.parseCommand("Search Google for SwiftUI")) { state in
            state.lastRecognizedCommand = "Search Google for SwiftUI"
        }

        // 3. Web search is initiated
        await store.send(.searchWeb("SwiftUI")) { state in
            state.lastSearchQuery = "SwiftUI"
            state.isSearching = true
        }

        // 4. Results are returned
        let mockResults = [
            AIAssistantFeature.SearchResult(
                id: UUID(),
                title: "SwiftUI Documentation",
                url: "https://developer.apple.com/swiftui",
                snippet: "Official Apple documentation",
                source: .web
            ),
        ]

        await store.send(.searchCompleted(mockResults)) { state in
            state.searchResults = mockResults
            state.isSearching = false
        }

        // Verify final state
        XCTAssertEqual(store.state.lastSearchQuery, "SwiftUI")
        XCTAssertFalse(store.state.isSearching)
        XCTAssertEqual(store.state.searchResults.count, 1)
        XCTAssertGreaterThan(store.state.conversationContext.totalInteractions, 0)
    }

    func testCompleteLocalSearchFlow() async {
        let store = createTestStore()

        // 1. User speaks search command
        await store.send(.processingAudioCompleted("Find my swift files")) { state in
            state.conversationContext.addInteraction(
                userInput: "Find my swift files",
                aiResponse: "Searching local files...",
                context: nil
            )
        }

        // 2. Local search is initiated
        await store.send(.searchLocal("swift")) { state in
            state.lastSearchQuery = "swift"
            state.isSearching = true
        }

        // 3. Local results are returned
        let mockResults = [
            AIAssistantFeature.SearchResult(
                id: UUID(),
                title: "ContentView.swift",
                url: "/Users/user/Projects/ContentView.swift",
                snippet: "struct ContentView",
                source: .local
            ),
        ]

        await store.send(.searchCompleted(mockResults)) { state in
            state.searchResults = mockResults
            state.isSearching = false
        }

        // Verify final state
        XCTAssertEqual(store.state.lastSearchQuery, "swift")
        XCTAssertFalse(store.state.isSearching)
        XCTAssertEqual(store.state.searchResults.count, 1)
    }

    func testConsecutiveSearches() async {
        let store = createTestStore()

        let searches = ["SwiftUI", "Combine", "Async Await"]

        for search in searches {
            await store.send(.searchWeb(search)) { state in
                state.lastSearchQuery = search
                state.isSearching = true
            }

            let mockResults = [
                AIAssistantFeature.SearchResult(
                    id: UUID(),
                    title: "Result for \(search)",
                    url: "https://example.com",
                    snippet: "Information about \(search)",
                    source: .web
                ),
            ]

            await store.send(.searchCompleted(mockResults)) { state in
                state.searchResults = mockResults
                state.isSearching = false
            }

            // Add to context
            await store.send(.addContextInteraction("Search for \(search)", "Found results", nil)) { state in
                state.conversationContext.addInteraction(
                    userInput: "Search for \(search)",
                    aiResponse: "Found results",
                    context: nil
                )
            }
        }

        // All searches should be in context
        XCTAssertGreaterThanOrEqual(store.state.conversationContext.totalInteractions, searches.count)
    }
}

// MARK: - Web Search Client Tests

final class WebSearchClientTests: XCTestCase {
    func testWebSearchResultCreation() {
        let result = WebSearchResult(
            title: "Test Result",
            url: "https://example.com",
            snippet: "This is a test",
            rank: 1
        )

        XCTAssertEqual(result.title, "Test Result")
        XCTAssertEqual(result.url, "https://example.com")
        XCTAssertEqual(result.rank, 1)
    }

    func testFormattedResultsContainExpectedInfo() {
        let results = [
            WebSearchResult(
                title: "Title 1",
                url: "http://url1.com",
                snippet: "Snippet 1",
                rank: 1
            ),
        ]

        let formatted = WebSearchClient.formatResults(results)

        XCTAssertTrue(formatted[0].contains("Title 1"))
        XCTAssertTrue(formatted[0].contains("http://url1.com"))
        XCTAssertTrue(formatted[0].contains("Snippet 1"))
    }
}

// MARK: - Local File Searcher Tests

final class LocalFileSearcherTests: XCTestCase {
    func testLocalSearchResultCreation() {
        let result = LocalSearchResult(
            path: "/Users/user/file.swift",
            filename: "file.swift",
            type: .sourceCode,
            snippet: "struct MyStruct",
            matchType: .filename,
            relevance: 0.9
        )

        XCTAssertEqual(result.filename, "file.swift")
        XCTAssertEqual(result.type, .sourceCode)
        XCTAssertEqual(result.relevance, 0.9)
    }

    func testRelevanceNormalization() {
        let result1 = LocalSearchResult(
            path: "/path",
            filename: "file",
            type: .document,
            snippet: "",
            matchType: .filename,
            relevance: 1.5 // Should be clamped to 1.0
        )

        let result2 = LocalSearchResult(
            path: "/path",
            filename: "file",
            type: .document,
            snippet: "",
            matchType: .filename,
            relevance: -0.5 // Should be clamped to 0.0
        )

        XCTAssertEqual(result1.relevance, 1.0)
        XCTAssertEqual(result2.relevance, 0.0)
    }
}
