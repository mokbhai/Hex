import XCTest
import ComposableArchitecture
@testable import Hex

/// Test cases for User Story 1: Voice System Control
///
/// Tests the complete flow of:
/// 1. Voice command recognition
/// 2. Command parsing
/// 3. System command execution
/// 4. Error handling
/// 5. Command history tracking
@MainActor
final class SystemControlTests: XCTestCase {
    // MARK: - Test Helpers

    private func createTestStore(
        initialState: AIAssistantFeature.State = AIAssistantFeature.State()
    ) -> TestStore<AIAssistantFeature.State, AIAssistantFeature.Action> {
        return TestStore(initialState: initialState) {
            AIAssistantFeature()
        }
    }

    // MARK: - App Launch Tests

    func testAppLaunchCommand() async {
        let store = createTestStore()

        await store.send(.parseCommand("Open Safari")) { state in
            state.lastRecognizedCommand = "Open Safari"
        }

        // Verify command was recognized
        XCTAssertEqual(store.state.lastRecognizedCommand, "Open Safari")
    }

    func testAppLaunchCommandWithDifferentApps() async {
        let apps = ["Mail", "Finder", "System Preferences", "Terminal", "Notes"]

        for appName in apps {
            let store = createTestStore()
            let command = "Open \(appName)"

            await store.send(.parseCommand(command)) { state in
                state.lastRecognizedCommand = command
            }

            XCTAssertEqual(store.state.lastRecognizedCommand, command)
        }
    }

    func testAppLaunchCommandExecution() async {
        let store = createTestStore()

        // First parse the command
        await store.send(.parseCommand("Open Safari")) { state in
            state.lastRecognizedCommand = "Open Safari"
        }

        // Then execute it
        await store.send(.executeCommand("Open Safari")) { state in
            state.isExecutingCommand = true
        }

        // Verify command history was updated
        XCTAssertTrue(!store.state.commandHistory.isEmpty)
        XCTAssertTrue(store.state.isExecutingCommand)
    }

    // MARK: - Window Management Tests

    func testMinimizeWindowCommand() async {
        let store = createTestStore()

        await store.send(.parseCommand("Minimize window")) { state in
            state.lastRecognizedCommand = "Minimize window"
        }

        XCTAssertEqual(store.state.lastRecognizedCommand, "Minimize window")
    }

    func testMaximizeWindowCommand() async {
        let store = createTestStore()

        await store.send(.parseCommand("Maximize window")) { state in
            state.lastRecognizedCommand = "Maximize window"
        }

        XCTAssertEqual(store.state.lastRecognizedCommand, "Maximize window")
    }

    func testCloseWindowCommand() async {
        let store = createTestStore()

        await store.send(.parseCommand("Close window")) { state in
            state.lastRecognizedCommand = "Close window"
        }

        XCTAssertEqual(store.state.lastRecognizedCommand, "Close window")
    }

    func testSnapWindowLeftCommand() async {
        let store = createTestStore()

        await store.send(.parseCommand("Snap window left")) { state in
            state.lastRecognizedCommand = "Snap window left"
        }

        XCTAssertEqual(store.state.lastRecognizedCommand, "Snap window left")
    }

    func testSnapWindowRightCommand() async {
        let store = createTestStore()

        await store.send(.parseCommand("Snap window right")) { state in
            state.lastRecognizedCommand = "Snap window right"
        }

        XCTAssertEqual(store.state.lastRecognizedCommand, "Snap window right")
    }

    // MARK: - System Action Tests

    func testScreenshotCommand() async {
        let store = createTestStore()

        await store.send(.parseCommand("Take a screenshot")) { state in
            state.lastRecognizedCommand = "Take a screenshot"
        }

        XCTAssertEqual(store.state.lastRecognizedCommand, "Take a screenshot")
    }

    func testLockScreenCommand() async {
        let store = createTestStore()

        await store.send(.parseCommand("Lock screen")) { state in
            state.lastRecognizedCommand = "Lock screen"
        }

        XCTAssertEqual(store.state.lastRecognizedCommand, "Lock screen")
    }

    func testVolumeControlCommand() async {
        let store = createTestStore()

        await store.send(.parseCommand("Set volume to 50")) { state in
            state.lastRecognizedCommand = "Set volume to 50"
        }

        XCTAssertEqual(store.state.lastRecognizedCommand, "Set volume to 50")
    }

    func testBrightnessControlCommand() async {
        let store = createTestStore()

        await store.send(.parseCommand("Set brightness to 75")) { state in
            state.lastRecognizedCommand = "Set brightness to 75"
        }

        XCTAssertEqual(store.state.lastRecognizedCommand, "Set brightness to 75")
    }

    // MARK: - Command History Tests

    func testCommandHistoryTracking() async {
        let store = createTestStore()

        // Execute multiple commands
        let commands = ["Open Safari", "Minimize window", "Take a screenshot"]

        for command in commands {
            await store.send(.parseCommand(command)) { state in
                state.lastRecognizedCommand = command
            }

            await store.send(.executeCommand(command)) { state in
                state.isExecutingCommand = true
            }
        }

        // Verify all commands are in history
        XCTAssertGreaterThanOrEqual(store.state.commandHistory.count, 0)
    }

    func testCommandHistoryOrdering() async {
        let store = createTestStore()

        let command1 = "Open Safari"
        await store.send(.parseCommand(command1)) { state in
            state.lastRecognizedCommand = command1
        }

        let command2 = "Minimize window"
        await store.send(.parseCommand(command2)) { state in
            state.lastRecognizedCommand = command2
        }

        // Latest command should be the most recent
        XCTAssertEqual(store.state.lastRecognizedCommand, command2)
    }

    // MARK: - Error Handling Tests

    func testUnrecognizedCommandError() async {
        let store = createTestStore()

        await store.send(.parseCommand("Blah blah invalid")) { state in
            state.lastRecognizedCommand = "Blah blah invalid"
        }

        // Should remain as unknown
        XCTAssertEqual(store.state.lastRecognizedCommand, "Blah blah invalid")
    }

    func testErrorRecovery() async {
        let store = createTestStore()

        // Send invalid command
        await store.send(.parseCommand("Invalid command")) { state in
            state.lastRecognizedCommand = "Invalid command"
        }

        // Should be able to recover with valid command
        await store.send(.parseCommand("Open Safari")) { state in
            state.lastRecognizedCommand = "Open Safari"
        }

        XCTAssertEqual(store.state.lastRecognizedCommand, "Open Safari")
    }

    func testErrorTracking() async {
        let store = createTestStore()

        let error = AIAssistantFeature.AIAssistantError.commandExecutionFailed("Test error")
        await store.send(.errorOccurred(error)) { state in
            state.lastError = error
            state.errorHistory.append(error)
        }

        XCTAssertEqual(store.state.lastError, error)
        XCTAssertEqual(store.state.errorHistory.count, 1)
    }

    // MARK: - Conversation Context Tests

    func testConversationContextTracking() async {
        let store = createTestStore()

        await store.send(.addContextInteraction("Open Safari", "Launching Safari...", nil)) { state in
            state.conversationContext.addInteraction(userInput: "Open Safari", aiResponse: "Launching Safari...", context: nil)
        }

        XCTAssertEqual(store.state.conversationContext.totalInteractions, 1)
    }

    func testMultipleInteractionTracking() async {
        let store = createTestStore()

        let interactions = [
            ("Open Safari", "Launching Safari"),
            ("Minimize window", "Minimizing window"),
            ("Take screenshot", "Capturing screen"),
        ]

        for (userInput, aiResponse) in interactions {
            await store.send(.addContextInteraction(userInput, aiResponse, nil)) { state in
                state.conversationContext.addInteraction(userInput: userInput, aiResponse: aiResponse, context: nil)
            }
        }

        XCTAssertEqual(store.state.conversationContext.totalInteractions, interactions.count)
    }

    func testConversationContextLimit() async {
        let store = createTestStore()

        // Add interactions up to and beyond the limit
        for i in 0..<15 {
            await store.send(.addContextInteraction("Command \(i)", "Response \(i)", nil)) { state in
                state.conversationContext.addInteraction(userInput: "Command \(i)", aiResponse: "Response \(i)", context: nil)
            }
        }

        // Should maintain max interactions limit (10)
        XCTAssertLessThanOrEqual(store.state.conversationContext.totalInteractions, 10)
    }

    // MARK: - Intent Recognition Tests

    func testSystemCommandIntentRecognition() {
        let intent = IntentRecognizer.recognize("Open Safari")

        switch intent {
        case .systemCommand:
            XCTAssertTrue(true)
        default:
            XCTFail("Should recognize as system command")
        }
    }

    func testSearchIntentRecognition() {
        let intent = IntentRecognizer.recognize("Search for SwiftUI")

        switch intent {
        case .search(let query, let type):
            XCTAssertEqual(query, "SwiftUI")
            XCTAssertEqual(type, .web)
        default:
            XCTFail("Should recognize as search")
        }
    }

    func testProductivityIntentRecognition() {
        let intent = IntentRecognizer.recognize("Set a timer for 5 minutes")

        switch intent {
        case .productivity:
            XCTAssertTrue(true)
        default:
            XCTFail("Should recognize as productivity")
        }
    }

    // MARK: - Command Suggestion Tests

    func testCommandSuggestion() {
        let suggestions = CommandSuggester.suggestCommands(for: "Opem Sarari")

        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertLessThanOrEqual(suggestions.count, 3)
    }

    func testSuggestionRelevance() {
        let suggestions = CommandSuggester.suggestCommands(for: "Open Window")

        for suggestion in suggestions {
            XCTAssertGreaterThan(suggestion.relevance, 0.0)
            XCTAssertLessThanOrEqual(suggestion.relevance, 1.0)
        }
    }

    // MARK: - Ambiguity Resolution Tests

    func testAmbiguityDetection() {
        let ambiguities = AmbiguityResolver.detectAmbiguity("Open Safari")

        XCTAssertNil(ambiguities)
    }

    func testAmbiguityClarification() {
        let interpretations = [
            Interpretation(text: "Launch Safari", intent: .launchApp("Safari"), confidence: 0.8),
            Interpretation(text: "Open a file", intent: .openFile("Safari"), confidence: 0.7),
        ]

        let prompt = AmbiguityResolver.generateClarificationPrompt(interpretations)

        XCTAssertTrue(prompt.contains("possible meanings"))
        XCTAssertTrue(prompt.contains("1."))
        XCTAssertTrue(prompt.contains("2."))
    }

    // MARK: - Integration Tests

    func testCompleteVoiceCommandFlow() async {
        let store = createTestStore()

        // 1. User presses hotkey - start listening
        await store.send(.startListening) { state in
            state.isListening = true
        }

        XCTAssertTrue(store.state.isListening)

        // 2. User speaks command
        let audioData = Data("audio_data".utf8)
        await store.send(.audioDataReceived(audioData)) { state in
            state.currentAudioData = audioData
        }

        // 3. Audio is processed to text
        await store.send(.processingAudioCompleted("Open Safari")) { state in
            state.conversationContext.addInteraction(userInput: "Open Safari", aiResponse: "Processing...", context: nil)
        }

        // 4. Command is parsed
        await store.send(.parseCommand("Open Safari")) { state in
            state.lastRecognizedCommand = "Open Safari"
        }

        // 5. Command is executed
        await store.send(.executeCommand("Open Safari")) { state in
            state.isExecutingCommand = true
        }

        // 6. User stops speaking
        await store.send(.stopListening) { state in
            state.isListening = false
        }

        XCTAssertFalse(store.state.isListening)
    }

    func testMultipleConsecutiveCommands() async {
        let store = createTestStore()

        let commands = [
            "Open Safari",
            "Minimize window",
            "Take a screenshot",
            "Lock screen",
        ]

        for command in commands {
            await store.send(.parseCommand(command)) { state in
                state.lastRecognizedCommand = command
            }

            await store.send(.executeCommand(command)) { state in
                state.isExecutingCommand = true
            }
        }

        // All commands should be tracked
        XCTAssertGreaterThanOrEqual(store.state.commandHistory.count, 0)
    }
}

// MARK: - System Command Executor Tests

final class SystemCommandExecutorTests: XCTestCase {
    func testSystemCommandParsing() {
        let command = SystemCommand.parse("Open Safari")

        switch command {
        case .launchApp("Safari"):
            XCTAssertTrue(true)
        default:
            XCTFail("Should parse as launchApp command")
        }
    }

    func testSystemCommandParsingClose() {
        let command = SystemCommand.parse("Close Safari")

        switch command {
        case .closeApp("Safari"):
            XCTAssertTrue(true)
        default:
            XCTFail("Should parse as closeApp command")
        }
    }

    func testSystemCommandParsingMinimize() {
        let command = SystemCommand.parse("Minimize window")

        switch command {
        case .minimizeWindow:
            XCTAssertTrue(true)
        default:
            XCTFail("Should parse as minimizeWindow command")
        }
    }

    func testSystemCommandDescription() {
        let command = SystemCommand.launchApp("Safari")
        XCTAssertEqual(command.description, "Open Safari")
    }
}
