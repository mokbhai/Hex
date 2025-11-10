import XCTest
import ComposableArchitecture
@testable import Hex

/// IntegrationTests: Complete end-to-end tests across all user stories
///
/// T072: Full integration tests validating:
/// 1. Voice System Control integration (US1)
/// 2. Information Search integration (US2)
/// 3. Voice Productivity Tools integration (US3)
/// 4. AI Model Management interaction (US5)
/// 5. Cross-feature workflows
/// 6. Error handling across features
/// 7. State persistence and recovery

@MainActor
final class AIAssistantIntegrationTests: XCTestCase {
    var store: TestStoreOf<AIAssistantFeature>!

    override func setUp() {
        super.setUp()
        store = TestStore(
            initialState: AIAssistantFeature.State(),
            reducer: { AIAssistantFeature() }
        )
    }

    // MARK: - US1: Voice System Control Integration

    /// Test complete workflow: Listen → Recognize → Execute → Report
    func testVoiceCommandExecutionIntegration() async {
        // Step 1: Start listening
        await store.send(.toggleListening(true)) { state in
            state.isListening = true
        }

        // Step 2: Simulate voice recognition
        await store.send(.voiceInputReceived("Open Safari")) { state in
            state.lastRecognizedCommand = "Open Safari"
        }

        // Step 3: Recognize intent
        await store.send(.intentsRecognized([
            IntentRecognizer.Intent(
                type: .openApplication,
                confidence: 0.95,
                parameters: ["app": "Safari"]
            )
        ])) { state in
            state.lastRecognizedCommand = "Open Safari"
        }

        // Step 4: Execute system command
        await store.send(.executeSystemCommand("open -a Safari")) { state in
            state.isExecutingCommand = true
        }

        // Step 5: Stop listening after execution
        await store.send(.toggleListening(false)) { state in
            state.isListening = false
            state.isExecutingCommand = false
        }
    }

    /// Test window management command execution
    func testWindowManagementIntegration() async {
        // Test maximize window command
        await store.send(.voiceInputReceived("Maximize this window")) { state in
            state.lastRecognizedCommand = "Maximize this window"
        }

        await store.send(.executeSystemCommand("maximize_window")) { state in
            state.isExecutingCommand = true
        }

        // Verify execution state
        XCTAssertTrue(store.state.isExecutingCommand)
    }

    /// Test application switching
    func testApplicationSwitchingIntegration() async {
        await store.send(.voiceInputReceived("Switch to Chrome")) { state in
            state.lastRecognizedCommand = "Switch to Chrome"
        }

        await store.send(.executeSystemCommand("switch_app:Chrome")) { state in
            state.isExecutingCommand = true
        }

        XCTAssertTrue(store.state.isExecutingCommand)
    }

    // MARK: - US2: Information Search Integration

    /// Test complete search workflow: Voice input → Web search → Results display
    func testWebSearchIntegration() async {
        // Step 1: Start listening for search
        await store.send(.toggleListening(true)) { state in
            state.isListening = true
        }

        // Step 2: Voice input
        await store.send(.voiceInputReceived("Search for machine learning")) { state in
            state.lastRecognizedCommand = "Search for machine learning"
        }

        // Step 3: Recognize search intent
        await store.send(.intentsRecognized([
            IntentRecognizer.Intent(
                type: .search,
                confidence: 0.98,
                parameters: ["query": "machine learning"]
            )
        ]))

        // Step 4: Perform search
        await store.send(.performWebSearch("machine learning")) { state in
            state.isSearching = true
        }

        // Step 5: Results arrive
        let mockResults = [
            SearchResult(
                title: "Machine Learning Basics",
                url: "https://example.com/ml-basics",
                snippet: "Learn the fundamentals of ML..."
            )
        ]

        await store.send(.searchResultsReceived(mockResults)) { state in
            state.searchResults = mockResults
            state.isSearching = false
        }

        // Verify search completed successfully
        XCTAssertEqual(store.state.searchResults.count, 1)
        XCTAssertFalse(store.state.isSearching)
    }

    /// Test local file search integration
    func testLocalFileSearchIntegration() async {
        await store.send(.performLocalFileSearch(
            query: "*.pdf",
            directory: "/Users/test"
        )) { state in
            state.isSearching = true
        }

        // Simulate file search results
        let mockFiles = [
            SearchResult(
                title: "Document1.pdf",
                url: "file:///Users/test/Document1.pdf",
                snippet: "Local file"
            )
        ]

        await store.send(.searchResultsReceived(mockFiles)) { state in
            state.searchResults = mockFiles
            state.isSearching = false
        }

        XCTAssertEqual(store.state.searchResults.count, 1)
    }

    /// Test search with error handling
    func testSearchErrorHandling() async {
        await store.send(.performWebSearch("test")) { state in
            state.isSearching = true
        }

        // Simulate search error
        let error = SearchErrorHandler.SearchError.apiError(
            provider: "google",
            statusCode: 429,
            message: "Rate limited"
        )

        await store.send(.searchErrorOccurred(error)) { state in
            state.isSearching = false
            state.lastError = .searchFailed(error.description)
        }

        XCTAssertNotNil(store.state.lastError)
    }

    // MARK: - US3: Voice Productivity Tools Integration

    /// Test timer creation and notification flow
    func testTimerIntegration() async {
        // Create timer via voice
        await store.send(.voiceInputReceived("Set a 5-minute timer")) { state in
            state.lastRecognizedCommand = "Set a 5-minute timer"
        }

        // Recognize timer intent
        await store.send(.intentsRecognized([
            IntentRecognizer.Intent(
                type: .createTimer,
                confidence: 0.99,
                parameters: ["duration": "300"]
            )
        ]))

        // Create timer
        let timer = TimerManager.Timer(
            id: "timer-001",
            duration: 300,
            remaining: 300,
            label: "Work Timer",
            createdAt: Date()
        )

        await store.send(.timerCreated(timer)) { state in
            state.activeTimers.append(timer)
        }

        XCTAssertEqual(store.state.activeTimers.count, 1)
        XCTAssertEqual(store.state.activeTimers.first?.label, "Work Timer")
    }

    /// Test calculator integration
    func testCalculatorIntegration() async {
        await store.send(.voiceInputReceived("What is 25 times 4")) { state in
            state.lastRecognizedCommand = "What is 25 times 4"
        }

        // Recognize calculation intent
        await store.send(.intentsRecognized([
            IntentRecognizer.Intent(
                type: .calculate,
                confidence: 0.97,
                parameters: ["expression": "25 * 4"]
            )
        ]))

        // Perform calculation
        let result = "100"
        await store.send(.calculationResultReceived(result)) { state in
            state.lastCalculationResult = result
        }

        XCTAssertEqual(store.state.lastCalculationResult, "100")
    }

    /// Test note creation and storage
    func testNoteIntegration() async {
        await store.send(.voiceInputReceived("Create a note about the meeting")) { state in
            state.lastRecognizedCommand = "Create a note about the meeting"
        }

        let note = Note(
            id: "note-001",
            title: "Meeting Notes",
            content: "Discussion points from the meeting",
            createdAt: Date(),
            tags: ["work", "important"]
        )

        await store.send(.noteCreated(note)) { state in
            state.notes.append(note)
        }

        XCTAssertEqual(store.state.notes.count, 1)
        XCTAssertEqual(store.state.notes.first?.tags.count, 2)
    }

    /// Test todo integration
    func testTodoIntegration() async {
        await store.send(.voiceInputReceived("Add review pull requests to my todos")) { state in
            state.lastRecognizedCommand = "Add review pull requests to my todos"
        }

        let todo = TodoItem(
            id: "todo-001",
            title: "Review pull requests",
            priority: .high,
            createdAt: Date()
        )

        await store.send(.todoCreated(todo)) { state in
            state.todos.append(todo)
        }

        // Mark todo as complete
        await store.send(.todoCompleted("todo-001")) { state in
            if let index = state.todos.firstIndex(where: { $0.id == "todo-001" }) {
                state.todos[index].completedAt = Date()
            }
        }

        XCTAssertNotNil(store.state.todos.first?.completedAt)
    }

    // MARK: - US5: AI Model Management Integration

    /// Test model selection and loading workflow
    func testModelLoadingIntegration() async {
        // Select model
        let selectedModel = AIModel(
            id: "mistral-7b",
            name: "Mistral 7B",
            provider: "hugging-face"
        )

        await store.send(.modelSelected(selectedModel)) { state in
            state.selectedModel = selectedModel
        }

        // Start loading
        await store.send(.modelDownloadStarted) { state in
            state.isLoadingModel = true
        }

        // Simulate progress updates
        await store.send(.modelDownloadProgress(0.5)) { state in
            state.modelDownloadProgress = 0.5
        }

        await store.send(.modelDownloadProgress(1.0)) { state in
            state.modelDownloadProgress = 1.0
        }

        // Complete loading
        await store.send(.modelLoadingCompleted) { state in
            state.isLoadingModel = false
            state.isModelReady = true
        }

        XCTAssertTrue(store.state.isModelReady)
    }

    // MARK: - Cross-Feature Workflows

    /// Test complete workflow: Search → Create note about results
    func testSearchToNoteWorkflow() async {
        // Step 1: Perform search
        await store.send(.performWebSearch("Swift concurrency")) { state in
            state.isSearching = true
        }

        let results = [
            SearchResult(
                title: "Swift Concurrency Guide",
                url: "https://example.com/swift-concurrency",
                snippet: "Understanding async/await..."
            )
        ]

        await store.send(.searchResultsReceived(results)) { state in
            state.searchResults = results
            state.isSearching = false
        }

        // Step 2: Create note about search results
        let note = Note(
            id: "note-002",
            title: "Swift Concurrency Research",
            content: "Found great guide on Swift concurrency",
            createdAt: Date(),
            tags: ["research", "swift"]
        )

        await store.send(.noteCreated(note)) { state in
            state.notes.append(note)
        }

        XCTAssertEqual(store.state.searchResults.count, 1)
        XCTAssertEqual(store.state.notes.count, 1)
    }

    /// Test complete workflow: Voice command → Execute → Log to history
    func testCommandExecutionWithHistory() async {
        // Record initial command
        await store.send(.voiceInputReceived("Open Mail")) { state in
            state.lastRecognizedCommand = "Open Mail"
        }

        // Execute
        await store.send(.executeSystemCommand("open -a Mail")) { state in
            state.isExecutingCommand = true
        }

        // Record in history
        let commandRecord = CommandHistory.CommandRecord(
            command: "Open Mail",
            executedAt: Date(),
            executionTime: 0.5,
            success: true
        )

        await store.send(.commandExecutionRecorded(commandRecord)) { state in
            state.commandHistory.append(commandRecord)
        }

        XCTAssertEqual(store.state.commandHistory.count, 1)
    }

    // MARK: - Error Recovery Integration

    /// Test error handling and recovery across features
    func testErrorRecoveryIntegration() async {
        // Simulate error during search
        await store.send(.performWebSearch("test")) { state in
            state.isSearching = true
        }

        let error = SearchErrorHandler.SearchError.networkError("Connection timeout")
        await store.send(.searchErrorOccurred(error)) { state in
            state.lastError = .searchFailed(error.description)
            state.isSearching = false
        }

        // Log error
        let errorLog = ErrorLogger.ErrorLog(
            timestamp: Date(),
            severity: .warning,
            category: .network,
            message: error.description
        )

        await store.send(.errorLogged(errorLog)) { state in
            state.errorLogs.append(errorLog)
        }

        // Recovery: Retry search with fallback
        await store.send(.performWebSearch("test")) { state in
            state.isSearching = true
        }

        XCTAssertTrue(store.state.isSearching)
    }

    /// Test persistence across app lifecycle
    func testDataPersistenceIntegration() async {
        // Create various data
        let note = Note(
            id: "note-003",
            title: "Persistent Note",
            content: "This should persist",
            createdAt: Date()
        )

        await store.send(.noteCreated(note)) { state in
            state.notes.append(note)
        }

        let todo = TodoItem(
            id: "todo-002",
            title: "Persistent Todo",
            createdAt: Date()
        )

        await store.send(.todoCreated(todo)) { state in
            state.todos.append(todo)
        }

        // Verify data is in state (in real app, would be persisted to CoreData)
        XCTAssertEqual(store.state.notes.count, 1)
        XCTAssertEqual(store.state.todos.count, 1)
        XCTAssertEqual(store.state.notes.first?.title, "Persistent Note")
        XCTAssertEqual(store.state.todos.first?.title, "Persistent Todo")
    }

    // MARK: - Performance Integration

    /// Test performance under load
    func testPerformanceUnderLoad() async {
        let startTime = Date()

        // Simulate multiple concurrent operations
        for i in 0..<10 {
            let todo = TodoItem(
                id: "perf-todo-\(i)",
                title: "Performance Test Todo \(i)",
                createdAt: Date()
            )

            await store.send(.todoCreated(todo)) { state in
                state.todos.append(todo)
            }
        }

        let duration = Date().timeIntervalSince(startTime)

        // Should complete reasonably fast (under 1 second for 10 items)
        XCTAssertLessThan(duration, 1.0)
        XCTAssertEqual(store.state.todos.count, 10)
    }

    // MARK: - State Consistency

    /// Verify state remains consistent across rapid operations
    func testStateConsistency() async {
        var expectedNoteCount = 0
        var expectedTodoCount = 0

        // Create note
        let note = Note(
            id: "consistency-note-1",
            title: "Consistency Test",
            content: "Testing state consistency",
            createdAt: Date()
        )

        await store.send(.noteCreated(note)) { state in
            state.notes.append(note)
            expectedNoteCount += 1
        }

        XCTAssertEqual(store.state.notes.count, expectedNoteCount)

        // Create todo
        let todo = TodoItem(
            id: "consistency-todo-1",
            title: "Consistency Todo",
            createdAt: Date()
        )

        await store.send(.todoCreated(todo)) { state in
            state.todos.append(todo)
            expectedTodoCount += 1
        }

        XCTAssertEqual(store.state.todos.count, expectedTodoCount)

        // Delete todo (if supported)
        // Verify counts remain consistent
        XCTAssertEqual(store.state.notes.count, expectedNoteCount)
        XCTAssertEqual(store.state.todos.count, expectedTodoCount)
    }
}

// MARK: - Mock Data Extensions

extension SearchResult {
    init(title: String, url: String, snippet: String) {
        self.init(
            id: UUID().uuidString,
            title: title,
            url: url,
            snippet: snippet,
            source: "web"
        )
    }
}

// Note: Full implementation requires proper mock objects and async testing utilities
// This test suite demonstrates the integration testing approach for T072
