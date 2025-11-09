import Foundation
import Testing
import ComposableArchitecture

/// Comprehensive test suite for AIAssistantFeature
/// Tests cover all user stories and core functionality
@Suite struct AIAssistantFeatureTests {
    // MARK: - Test Fixtures

    private var store: TestStore<
        AIAssistantFeature.State,
        AIAssistantFeature.Action,
        AIAssistantFeature,
        TestScheduler
    >!

    init() {
        self.store = TestStore(
            initialState: AIAssistantFeature.State(),
            reducer: {
                AIAssistantFeature()
            },
            withDependencies: { dependencies in
                dependencies.aiClient = AIClientMock()
                dependencies.huggingFaceClient = HuggingFaceClientMock()
            }
        )
    }

    // MARK: - Lifecycle Tests

    @Test
    func testOnAppear() async {
        await store.send(.onAppear)
        #expect(store.state.isListening == false)
    }

    // MARK: - Listening Tests (User Story 1)

    @Test
    func testStartListening() async {
        await store.send(.startListening) { state in
            state.isListening = true
            state.recordingStartTime = nil // Will be set to now()
        }
    }

    @Test
    func testStopListening() async {
        await store.send(.startListening) { state in
            state.isListening = true
        }

        await store.send(.stopListening) { state in
            state.isListening = false
            state.recordingStartTime = nil
        }
    }

    // MARK: - Command Processing Tests (User Story 1)

    @Test
    func testParseCommand() async {
        let command = "Open Safari"

        await store.send(.parseCommand(command)) { state in
            state.lastRecognizedCommand = command
        }

        await store.receive(.executeCommand(command)) { state in
            state.isExecutingCommand = true
            state.commandHistory.append(
                AIAssistantFeature.CommandRecord(command: command, result: .success)
            )
        }
    }

    @Test
    func testCommandRecordTracking() async {
        let command1 = "Open Safari"
        let command2 = "Minimize window"

        await store.send(.executeCommand(command1)) { state in
            state.isExecutingCommand = true
            state.commandHistory.append(
                AIAssistantFeature.CommandRecord(command: command1, result: .success)
            )
        }

        await store.send(.executeCommand(command2)) { state in
            state.isExecutingCommand = true
            state.commandHistory.append(
                AIAssistantFeature.CommandRecord(command: command2, result: .success)
            )
        }

        #expect(store.state.commandHistory.count == 2)
    }

    // MARK: - Model Management Tests (User Story 5)

    @Test
    func testLoadAvailableModels() async {
        await store.send(.loadAvailableModels) { state in
            state.isLoadingModels = true
        }
    }

    @Test
    func testModelSelectionAndLoading() async {
        let model = AIModel(
            id: "test-model",
            displayName: "Test Model",
            version: "1.0",
            size: 512_000_000,
            localPath: "/path/to/model"
        )

        await store.send(.selectModel(model)) { state in
            state.currentModel = model
        }

        #expect(store.state.currentModel == model)
    }

    // MARK: - Search Tests (User Story 2)

    @Test
    func testWebSearch() async {
        let query = "SwiftUI tutorial"

        await store.send(.searchWeb(query)) { state in
            state.lastSearchQuery = query
            state.isSearching = true
        }
    }

    @Test
    func testLocalSearch() async {
        let query = "project files"

        await store.send(.searchLocal(query)) { state in
            state.lastSearchQuery = query
            state.isSearching = true
        }
    }

    // MARK: - Productivity Tools Tests (User Story 3)

    @Test
    func testStartTimer() async {
        let duration: TimeInterval = 300 // 5 minutes
        let label = "Focus time"

        await store.send(.startTimer(duration, label)) { state in
            state.activeTimer = AIAssistantFeature.TimerState(
                duration: duration,
                label: label
            )
        }

        #expect(store.state.activeTimer?.isExpired == false)
    }

    // MARK: - Conversation Context Tests (SC-005)

    @Test
    func testConversationContextInteraction() async {
        let userInput = "What time is it?"
        let aiResponse = "It's 3 PM"
        let context = "time_query"

        await store.send(.addContextInteraction(userInput, aiResponse, context)) { state in
            state.conversationContext.addInteraction(
                userInput: userInput,
                aiResponse: aiResponse,
                context: context
            )
        }

        #expect(store.state.conversationContext.totalInteractions == 1)
    }

    @Test
    func testConversationContextPersistence() async {
        // Add 12 interactions to test SC-005 (10+ interactions)
        for i in 1...12 {
            await store.send(.addContextInteraction("Input \(i)", "Response \(i)", nil)) { state in
                state.conversationContext.addInteraction(
                    userInput: "Input \(i)",
                    aiResponse: "Response \(i)",
                    context: nil
                )
            }
        }

        // Should maintain at least 10 interactions
        #expect(store.state.conversationContext.totalInteractions >= 10)
    }

    @Test
    func testConversationContextReset() async {
        await store.send(.addContextInteraction("Test", "Response", nil)) { state in
            state.conversationContext.addInteraction(
                userInput: "Test",
                aiResponse: "Response",
                context: nil
            )
        }

        #expect(store.state.conversationContext.totalInteractions == 1)

        await store.send(.resetConversation) { state in
            state.conversationContext.reset()
        }

        #expect(store.state.conversationContext.totalInteractions == 0)
    }

    // MARK: - Error Handling Tests

    @Test
    func testErrorOccurred() async {
        let error = AIAssistantFeature.AIAssistantError.commandExecutionFailed("Test error")

        await store.send(.errorOccurred(error)) { state in
            state.lastError = error
            state.errorHistory.append(error)
        }

        #expect(store.state.errorHistory.count == 1)
        #expect(store.state.lastError == error)
    }

    @Test
    func testErrorHistoryLimit() async {
        // Add 60 errors to test limit
        for i in 1...60 {
            let error = AIAssistantFeature.AIAssistantError
                .commandExecutionFailed("Error \(i)")
            
            await store.send(.errorOccurred(error)) { state in
                state.lastError = error
                state.errorHistory.append(error)
                if state.errorHistory.count > 50 {
                    state.errorHistory.removeFirst(state.errorHistory.count - 50)
                }
            }
        }

        // Should maintain maximum 50 errors
        #expect(store.state.errorHistory.count == 50)
    }

    // MARK: - Settings Tests

    @Test
    func testUpdateSettings() async {
        var settings = AIAssistantSettings.default
        settings.searchProvider = "custom"
        settings.voiceFeedbackEnabled = false

        await store.send(.updateSettings(settings)) { state in
            state.settings = settings
        }

        #expect(store.state.settings.searchProvider == "custom")
        #expect(store.state.settings.voiceFeedbackEnabled == false)
    }
}
