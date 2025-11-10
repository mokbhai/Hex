import Foundation
import ComposableArchitecture

/// AIAssistantFeature is the main TCA reducer for the AI Assistant functionality.
/// It manages all user story features: system control, model management, information search, and productivity tools.
public struct AIAssistantFeature: Reducer {
    // MARK: - State

    /// Unified state schema accommodating all user story needs
    public struct State: Equatable {
        // MARK: Listening & Recording
        public var isListening: Bool = false
        public var recordingStartTime: Date?
        public var currentAudioData: Data?

        // MARK: Models (User Story 5)
        public var currentModel: AIModel?
        public var downloadedModels: [AIModel] = []
        public var availableModels: [HuggingFaceModel] = []
        public var isLoadingModels: Bool = false

        // MARK: Commands & System Control (User Story 1)
        public var lastRecognizedCommand: String?
        public var commandHistory: [CommandRecord] = []
        public var isExecutingCommand: Bool = false

        // MARK: Search (User Story 2)
        public var lastSearchQuery: String?
        public var searchResults: [SearchResult] = []
        public var isSearching: Bool = false

        // MARK: Productivity Tools (User Story 3)
        public var activeTimer: TimerState?
        public var notes: [Note] = []
        public var todos: [TodoItem] = []
        public var reminders: [Reminder] = []

        // MARK: Conversation Context (SC-005)
        public var conversationContext: ConversationContext = .init()

        // MARK: Error Handling
        public var lastError: AIAssistantError?
        public var errorHistory: [AIAssistantError] = []

        // MARK: Settings
        public var settings: AIAssistantSettings = .default
    }

    // MARK: - Conversation Context (for SC-005 support)

    public struct ConversationContext: Equatable {
        public var interactions: [Interaction] = []
        public var totalInteractions: Int { interactions.count }
        public var maxInteractions: Int = 10 // Support 10+ interactions

        public struct Interaction: Equatable, Identifiable {
            public let id: UUID
            public let timestamp: Date
            public let userInput: String
            public let aiResponse: String
            public let context: String?

            public init(id: UUID = UUID(), timestamp: Date = Date(), userInput: String, aiResponse: String, context: String? = nil) {
                self.id = id
                self.timestamp = timestamp
                self.userInput = userInput
                self.aiResponse = aiResponse
                self.context = context
            }
        }

        public mutating func addInteraction(userInput: String, aiResponse: String, context: String? = nil) {
            let interaction = Interaction(userInput: userInput, aiResponse: aiResponse, context: context)
            interactions.append(interaction)
            // Keep only the last maxInteractions
            if interactions.count > maxInteractions {
                interactions.removeFirst(interactions.count - maxInteractions)
            }
        }

        public mutating func reset() {
            interactions.removeAll()
        }
    }

    // MARK: - Supporting State Types

    public struct TimerState: Equatable {
        public let id: UUID
        public let duration: TimeInterval
        public let startTime: Date
        public var remainingTime: TimeInterval {
            max(0, duration - Date().timeIntervalSince(startTime))
        }
        public let label: String?

        public init(id: UUID = UUID(), duration: TimeInterval, startTime: Date = Date(), label: String? = nil) {
            self.id = id
            self.duration = duration
            self.startTime = startTime
            self.label = label
        }

        public var isExpired: Bool {
            remainingTime <= 0
        }
    }

    public struct CommandRecord: Equatable, Identifiable {
        public let id: UUID
        public let timestamp: Date
        public let command: String
        public let result: CommandResult

        public enum CommandResult: Equatable {
            case success
            case failure(String)
            case unrecognized
        }

        public init(id: UUID = UUID(), timestamp: Date = Date(), command: String, result: CommandResult) {
            self.id = id
            self.timestamp = timestamp
            self.command = command
            self.result = result
        }
    }

    public struct SearchResult: Equatable, Identifiable {
        public let id: UUID
        public let title: String
        public let url: String?
        public let snippet: String
        public let source: SearchSource

        public enum SearchSource: String, Equatable {
            case web
            case local
        }

        public init(id: UUID = UUID(), title: String, url: String? = nil, snippet: String, source: SearchSource) {
            self.id = id
            self.title = title
            self.url = url
            self.snippet = snippet
            self.source = source
        }
    }

    // MARK: - Actions

    public enum Action: Equatable {
        // Lifecycle
        case onAppear

        // Listening & Recording (User Story 1)
        case startListening
        case stopListening
        case audioDataReceived(Data)
        case processingAudioCompleted(String) // Speech to text result
        case listeningStateChanged(Bool)

        // Command Processing (User Story 1)
        case parseCommand(String)
        case executeCommand(String)
        case commandExecutionCompleted(CommandRecord)

        // Model Management (User Story 5)
        case loadAvailableModels
        case availableModelsLoaded([HuggingFaceModel])
        case selectModel(AIModel)
        case downloadModel(HuggingFaceModel)
        case modelDownloadProgress(String, Double) // model id, progress
        case modelDownloadCompleted(AIModel)

        // Search (User Story 2)
        case searchWeb(String)
        case searchLocal(String)
        case searchCompleted([SearchResult])

        // Productivity Tools (User Story 3)
        case startTimer(TimeInterval, String?)
        case timerUpdated(TimerState?)
        case addNote(String, [String])
        case addTodo(String, Int32)
        case addReminder(String, Date)

        // Conversation Context (SC-005)
        case addContextInteraction(String, String, String?)
        case resetConversation

        // Error Handling
        case errorOccurred(AIAssistantError)

        // Settings
        case updateSettings(AIAssistantSettings)
    }

    // MARK: - Errors

    public enum AIAssistantError: LocalizedError, Equatable {
        case audioCaptureFailed(String)
        case commandParseFailed(String)
        case commandExecutionFailed(String)
        case modelLoadFailed(String)
        case searchFailed(String)

        public var errorDescription: String? {
            switch self {
            case .audioCaptureFailed(let reason):
                return "Failed to capture audio: \(reason)"
            case .commandParseFailed(let reason):
                return "Failed to parse command: \(reason)"
            case .commandExecutionFailed(let reason):
                return "Failed to execute command: \(reason)"
            case .modelLoadFailed(let reason):
                return "Failed to load model: \(reason)"
            case .searchFailed(let reason):
                return "Search failed: \(reason)"
            }
        }
    }

    // MARK: - Reducer

    @Dependency(\.aiClient) var aiClient
    @Dependency(\.huggingFaceClient) var huggingFaceClient

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none

            case .startListening:
                state.isListening = true
                state.recordingStartTime = Date()
                // TODO: Integrate with TranscriptionFeature hotkey pattern
                return .none

            case .stopListening:
                state.isListening = false
                state.recordingStartTime = nil
                // TODO: Stop recording
                return .none

            case .audioDataReceived(let data):
                state.currentAudioData = data
                // TODO: Process audio data
                return .none

            case .processingAudioCompleted(let text):
                state.conversationContext.addInteraction(userInput: text, aiResponse: "Processing...", context: nil)
                return .send(.parseCommand(text))

            case .listeningStateChanged(let isListening):
                state.isListening = isListening
                return .none

            case .parseCommand(let text):
                state.lastRecognizedCommand = text
                // Parse command using IntentRecognizer
                let intent = IntentRecognizer.recognize(text)
                
                // Route based on recognized intent
                switch intent {
                case .systemCommand:
                    return .send(.executeCommand(text))
                case .search(let query, let type):
                    switch type {
                    case .web:
                        return .send(.searchWeb(query))
                    case .local:
                        return .send(.searchLocal(query))
                    }
                case .productivity:
                    // Route to productivity handler
                    return .none
                case .ambiguous(let possibilities):
                    // Trigger ambiguity resolution
                    let message = AmbiguityResolver.generateClarificationPrompt(
                        possibilities.compactMap { possibility in
                            AmbiguityResolver.detectAmbiguity(possibility)?.first
                        }
                    )
                    return .none
                case .unknown:
                    // Get suggestions for unrecognized command
                    let suggestions = CommandSuggester.suggestCommands(for: text)
                    return .none
                }

            case .executeCommand(let command):
                state.isExecutingCommand = true
                
                // Parse the command string to SystemCommand
                if let systemCommand = SystemCommand.parse(command) {
                    return .run { send in
                        let result = await SystemCommandExecutor.execute(systemCommand)
                        
                        let record = CommandRecord(
                            command: command,
                            result: result.success ? .success : .failure(result.message)
                        )
                        
                        await send(.commandExecutionCompleted(record))
                    }
                } else {
                    // Command not recognized as system command
                    let record = CommandRecord(command: command, result: .unrecognized)
                    state.commandHistory.append(record)
                    return .send(.commandExecutionCompleted(record))
                }

            case .commandExecutionCompleted(let record):
                state.isExecutingCommand = false
                state.commandHistory.append(record)
                return .none

            case .loadAvailableModels:
                state.isLoadingModels = true
                // TODO: Load models from HuggingFaceClient
                return .none

            case .availableModelsLoaded(let models):
                state.availableModels = models
                state.isLoadingModels = false
                return .none

            case .selectModel(let model):
                state.currentModel = model
                // TODO: Load model for inference
                return .none

            case .downloadModel(let model):
                // TODO: Initiate model download using HuggingFaceClient
                return .none

            case .modelDownloadProgress(let modelId, let progress):
                // TODO: Update download progress UI
                return .none

            case .modelDownloadCompleted(let model):
                state.downloadedModels.append(model)
                // TODO: Make model available for inference
                return .none

            case .searchWeb(let query):
                state.lastSearchQuery = query
                state.isSearching = true
                // TODO: Perform web search
                return .none

            case .searchLocal(let query):
                state.lastSearchQuery = query
                state.isSearching = true
                // TODO: Perform local file search
                return .none

            case .searchCompleted(let results):
                state.searchResults = results
                state.isSearching = false
                return .none

            case .startTimer(let duration, let label):
                state.activeTimer = TimerState(duration: duration, label: label)
                // TODO: Start timer with notifications
                return .none

            case .timerUpdated(let timerState):
                state.activeTimer = timerState
                return .none

            case .addNote(let content, let tags):
                // TODO: Create note entity
                return .none

            case .addTodo(let description, let priority):
                // TODO: Create todo entity
                return .none

            case .addReminder(let message, let date):
                // TODO: Create reminder entity
                return .none

            case .addContextInteraction(let userInput, let aiResponse, let context):
                state.conversationContext.addInteraction(
                    userInput: userInput,
                    aiResponse: aiResponse,
                    context: context
                )
                return .none

            case .resetConversation:
                state.conversationContext.reset()
                return .none

            case .errorOccurred(let error):
                state.lastError = error
                state.errorHistory.append(error)
                // Keep only last 50 errors
                if state.errorHistory.count > 50 {
                    state.errorHistory.removeFirst(state.errorHistory.count - 50)
                }
                return .none

            case .updateSettings(let settings):
                state.settings = settings
                return .none
            }
        }
    }
}

// MARK: - Supporting Types

public struct AIModel: Equatable, Identifiable {
    public let id: String
    public let displayName: String
    public let version: String
    public let size: Int64
    public let localPath: String?
    public let downloadDate: Date?
    public let lastUsed: Date?
    public let capabilities: [String]
    public var isDownloaded: Bool { localPath != nil }

    public init(
        id: String,
        displayName: String,
        version: String,
        size: Int64,
        localPath: String? = nil,
        downloadDate: Date? = nil,
        lastUsed: Date? = nil,
        capabilities: [String] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.version = version
        self.size = size
        self.localPath = localPath
        self.downloadDate = downloadDate
        self.lastUsed = lastUsed
        self.capabilities = capabilities
    }
}

public struct AIAssistantSettings: Equatable {
    public var searchProvider: String = "google"
    public var voiceFeedbackEnabled: Bool = true
    public var commandHistoryEnabled: Bool = true
    public var contextPersistenceEnabled: Bool = true
    public var privacyMode: Bool = false // When true, don't store conversation history

    public static let `default` = AIAssistantSettings()
}
