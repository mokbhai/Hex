# AIAssistantFeature State Design

**Date**: November 10, 2025
**Feature**: Local AI Assistant
**Purpose**: Document the unified state schema accommodating all user stories

## State Architecture Overview

The `AIAssistantFeature.State` is designed to support all four user stories while maintaining a clean, composable architecture. Each user story's state is grouped logically to allow independent development and testing.

## State Structure

### 1. Listening & Recording (Foundational)

- `isListening: Bool` - Whether audio is being captured
- `recordingStartTime: Date?` - When recording started
- `currentAudioData: Data?` - Raw audio data being processed

**Rationale**: Shared across all user stories that require voice input. Reuses TranscriptionFeature patterns.

### 2. Models (User Story 5 - AI Model Management)

- `currentModel: AIModel?` - Currently selected AI model
- `downloadedModels: [AIModel]` - Available downloaded models
- `availableModels: [HuggingFaceModel]` - Models available from Hugging Face
- `isLoadingModels: Bool` - Whether fetching available models

**Rationale**: Centralized model state allows all user stories to access the same AI inference engine. Independent of specific use cases.

### 3. Commands & System Control (User Story 1 - Voice System Control)

- `lastRecognizedCommand: String?` - Most recent command recognized
- `commandHistory: [CommandRecord]` - Historical commands for auditing
- `isExecutingCommand: Bool` - Whether a command is being executed

**Rationale**: Tracks system commands execution. Isolated from other user story states.

### 4. Search (User Story 2 - Voice Information Search)

- `lastSearchQuery: String?` - Most recent search query
- `searchResults: [SearchResult]` - Current search results
- `isSearching: Bool` - Whether search is in progress

**Rationale**: Independent search state. No dependencies on other user story states.

### 5. Productivity Tools (User Story 3 - Voice Productivity Tools)

- `activeTimer: TimerState?` - Currently running timer
- `notes: [Note]` - User-created notes
- `todos: [TodoItem]` - Todo list items
- `reminders: [Reminder]` - Scheduled reminders

**Rationale**: Grouped productivity features. Persisted to CoreData, independent of other stories.

### 6. Conversation Context (SC-005 Support)

- `conversationContext: ConversationContext` - Multi-turn conversation state
  - `interactions: [Interaction]` - Array of user inputs and AI responses
  - `maxInteractions: Int` - Keeps 10+ interactions for continuity

**Rationale**: Enables context-aware responses. Supports SC-005 (10+ interaction continuity). Can be persisted or transient based on privacy settings.

### 7. Error Handling (Cross-Story)

- `lastError: AIAssistantError?` - Most recent error
- `errorHistory: [AIAssistantError]` - Last 50 errors for debugging

**Rationale**: Shared error state for all user stories. Limited to 50 entries to prevent memory bloat.

### 8. Settings (Cross-Story)

- `settings: AIAssistantSettings` - User preferences
  - `searchProvider: String` - Which search engine to use
  - `voiceFeedbackEnabled: Bool` - Audio feedback on/off
  - `commandHistoryEnabled: Bool` - Track command usage
  - `contextPersistenceEnabled: Bool` - Save conversation context
  - `privacyMode: Bool` - Enhanced privacy (no conversation storage)

**Rationale**: Global settings affecting multiple stories. Can be persisted to CoreData.

## Design Decisions

### 1. Flat State Over Nested Reducers

**Decision**: Use flat state structure rather than sub-reducers for each user story.
**Rationale**:

- Simpler to test each story independently
- Easier to share state between stories (e.g., current model)
- Cleaner effects when stories need to coordinate
- No complex reducer composition needed

### 2. Separate Types for Each Domain

**Decision**: Define separate types for `CommandRecord`, `SearchResult`, `TimerState`.
**Rationale**:

- Type safety and clarity
- Easier to test and validate
- Can evolve independently
- Supports Codable/Equatable conformance for persistence

### 3. Conversation Context as First-Class State

**Decision**: Make conversation context a core part of state, not ephemeral.
**Rationale**:

- SC-005 requires 10+ interaction continuity
- Need to support context-aware responses
- Should be testable and debuggable
- Privacy mode allows disabling without changing architecture

### 4. Error History with Limit

**Decision**: Keep last 50 errors, not unlimited.
**Rationale**:

- Support debugging and auditing
- Prevent unbounded memory growth
- 50 is enough for troubleshooting sessions
- Can be persisted to disk for long-term analysis

## Independence Properties

Each user story state section is **independently testable**:

- **US1 (Commands)**: Can test command parsing/execution without models, search, or productivity
- **US5 (Models)**: Can test model selection/download without executing commands
- **US2 (Search)**: Can test search without any other features
- **US3 (Productivity)**: Can test timers/notes/todos without other features

## Extensibility

Future state additions follow the same pattern:

1. **Add group of related properties** (e.g., `// MARK: - Feature X`)
2. **Create supporting types** (e.g., `FeatureXState`)
3. **Add related actions** to `Action` enum
4. **Add reducer cases** to handle new actions
5. **Tests remain independent** - other stories unaffected

## Persistence Strategy

**CoreData Entities** map directly to state types:

- `AIModelEntity` ↔ `AIModel`
- `NoteEntity` ↔ `Note`
- `TodoItemEntity` ↔ `TodoItem`
- `ReminderEntity` ↔ `Reminder`
- `WorkflowEntity` ↔ Workflow (future)
- `UserPatternEntity` ↔ UserPattern (future)

**Volatile State** (ephemeral, not persisted):

- `isListening`, `currentAudioData`, `isExecutingCommand`, `isSearching`, `isLoadingModels`

**Optional Persistence** (based on settings):

- `conversationContext` - Only if `contextPersistenceEnabled && !privacyMode`
- `commandHistory` - Only if `commandHistoryEnabled`

## Testing Implications

State design enables:

1. **Unit Tests**: Each user story action/reducer in isolation
2. **Integration Tests**: Multiple stories interacting (e.g., command triggers search)
3. **State Snapshot Tests**: Verify state transitions
4. **Reducer Tests**: All actions in isolated test store
5. **Persistence Tests**: CoreData roundtrips
