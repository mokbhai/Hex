# Tasks: Local AI Assistant

**Input**: Design documents from `/specs/001-local-ai-assistant/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US5, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and TCA feature structure

- [x] T001 Create AIAssistant feature module directory structure at `Hex/Features/AIAssistant/`
- [x] T002 Create AIClient dependency client skeleton at `Hex/Clients/AIClient.swift`
- [x] T003 Create HuggingFaceClient dependency client skeleton at `Hex/Clients/HuggingFaceClient.swift`
- [x] T004 [P] Configure CoreData schema for AI models in `Hex/Models/AIModel.swift`
- [x] T005 [P] Configure CoreData schema for user data entities in `Hex/Models/Note.swift`, `Hex/Models/TodoItem.swift`, `Hex/Models/Reminder.swift`
- [x] T006 [P] Create DependencyValues extensions in `Hex/Clients/AIClient.swift` and `Hex/Clients/HuggingFaceClient.swift`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core TCA infrastructure and patterns that block all user stories

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T007 Create AIAssistantFeature TCA reducer skeleton with State, Action, and reduce method in `Hex/Features/AIAssistant/AIAssistantFeature.swift`
- [x] T008 Implement AIClient protocol with text inference interface in `Hex/Clients/AIClient.swift`
- [x] T009 Implement HuggingFaceClient protocol with model discovery and download interface in `Hex/Clients/HuggingFaceClient.swift`
- [x] T010 [P] Setup Swift Testing infrastructure with test file `Hex/Features/AIAssistant/Tests/AIAssistantFeatureTests.swift`
- [x] T011 Implement hotkey detection integration reusing TranscriptionFeature pattern in `Hex/Features/AIAssistant/HotKeyProcessor.swift`
- [x] T012 Create core command executor service in `Hex/Features/AIAssistant/CommandExecutor.swift`
- [x] T013 Design unified AIAssistantFeature state schema accommodating all user story needs (system control, models, search, productivity) in `Hex/Features/AIAssistant/StateDesign.md`
- [x] T014 [P] Implement conversation context state machine and persistence in `Hex/Features/AIAssistant/ConversationContextManager.swift` to support SC-005 (10+ interaction continuity)
- [x] T015 [P] Implement voice recording cleanup infrastructure in `Hex/Features/AIAssistant/AudioRecordingCleanup.swift` - delete all voice data immediately after processing for privacy compliance (FR-014)
- [x] T016 [P] Setup shared API authentication infrastructure for search and external API calls in `Hex/Clients/SharedAPIAuth.swift` supporting Basic Auth and Bearer tokens for reuse across all stories

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Voice System Control (Priority: P1) 🎯 MVP

**Goal**: Enable Mac users to control their system through voice commands for app/window management and system actions

**Independent Test**: User presses AI hotkey, system starts listening with visual indicator, user speaks "Open Safari", Safari launches. System should work independently without other user stories.

### Implementation for User Story 1

- [x] T017 [P] [US1] Create SystemCommand enum and execute methods in `Hex/Features/AIAssistant/SystemCommand.swift`
- [x] T018 [P] [US1] Implement app management command handler in `Hex/Features/AIAssistant/SystemCommand.swift`
- [x] T019 [P] [US1] Implement window management command handler in `Hex/Features/AIAssistant/SystemCommand.swift`
- [x] T020 [US1] Create AIAssistantState extensions for command processing in `Hex/Features/AIAssistant/AIAssistantFeature.swift` (reference unified state schema from T013)
- [x] T021 [US1] Add listening state indicator view in `Hex/Views/AIAssistantIndicatorView.swift`
- [x] T022 [US1] Implement command parsing and intent recognition in `Hex/Features/AIAssistant/IntentRecognizer.swift`
- [x] T023 [US1] Add system command execution with error handling in `Hex/Features/AIAssistant/SystemCommandExecutor.swift`
- [x] T024 [US1] Create test cases for app launch, window management, system actions in `Hex/Features/AIAssistant/Tests/SystemControlTests.swift`
- [x] T025 [US1] Add voice suggestion feedback for unrecognized commands in `Hex/Features/AIAssistant/CommandSuggester.swift`
- [x] T026 [US1] Add clarification prompts for ambiguous commands in `Hex/Features/AIAssistant/AmbiguityResolver.swift`

**Checkpoint**: User Story 1 is fully functional - users can control system via voice commands independently

---

## Phase 4: User Story 5 - AI Model Management (Priority: P1)

**Goal**: Enable users to select and download AI models from Hugging Face, supporting model switching and management

**Independent Test**: User opens settings, browses Hugging Face models, selects one, downloads it, and switches to using that model. This should work independently alongside User Story 1.

### Implementation for User Story 5

- [x] T027 [P] [US5] Implement HuggingFaceClient model search in `Hex/Clients/HuggingFaceClient.swift`
- [x] T028 [P] [US5] Implement HuggingFaceClient model download with progress tracking in `Hex/Clients/HuggingFaceClient.swift`
- [x] T029 [US5] Add model management to AIAssistantFeature state in `Hex/Features/AIAssistant/AIAssistantFeature.swift` (reference unified state schema from T013)
- [x] T030 [US5] Create ModelDownloadView UI for browsing and downloading in `Hex/Views/ModelDownloadView.swift`
- [x] T031 [US5] Implement model selection and activation logic in `Hex/Features/AIAssistant/ModelManager.swift`
- [x] T032 [US5] Add model validation to ensure Core ML compatibility in `Hex/Features/AIAssistant/ModelValidator.swift`
- [x] T033 [US5] Add model caching and storage management in `Hex/Features/AIAssistant/LocalModelStorage.swift`
- [x] T034 [US5] Create test cases for model discovery, download, and switching in `Hex/Features/AIAssistant/Tests/ModelManagementTests.swift`
- [x] T035 [US5] Add download progress UI and error handling in `Hex/Views/ModelDownloadProgressView.swift`
- [x] T036 [US5] Implement model-specific configuration and loading in `Hex/Features/AIAssistant/ModelLoader.swift`

**Checkpoint**: User Story 5 is fully functional - users can select, download, and switch AI models independently

---

## Phase 5: User Story 2 - Voice Information Search (Priority: P2)

**Goal**: Enable users to search the web and local files through voice commands, getting immediate answers

**Independent Test**: User says "Search Google for SwiftUI", browser opens with results. User says "Find files containing project", file results display. System works independently alongside Stories 1 and 5.

### Implementation for User Story 2

- [x] T037 [P] [US2] Create web search client in `Hex/Features/AIAssistant/WebSearchClient.swift` (integrating ser.jainparichay.online API, reference T016 SharedAPIAuth)
- [x] T038 [P] [US2] Create local file search implementation in `Hex/Features/AIAssistant/LocalFileSearcher.swift`
- [x] T039 [US2] Add web and file search actions to AIAssistantFeature in `Hex/Features/AIAssistant/AIAssistantFeature.swift` (reference unified state schema from T013)
- [x] T040 [US2] Implement search result formatting and display in `Hex/Features/AIAssistant/SearchResultFormatter.swift`
- [x] T041 [US2] Create SearchResultsView for presenting search results in `Hex/Views/SearchResultsView.swift`
- [x] T042 [US2] Add browser integration for opening search results in `Hex/Features/AIAssistant/BrowserIntegration.swift`
- [x] T043 [US2] Add error handling for network failures and API errors in `Hex/Features/AIAssistant/SearchErrorHandler.swift`
- [x] T044 [US2] Create integration test for conversation context persistence across search interactions in `Hex/Features/AIAssistant/Tests/InformationSearchTests.swift` (validates SC-005)
- [x] T045 [US2] Create test cases for web search, file search, and result display in `Hex/Features/AIAssistant/Tests/InformationSearchTests.swift`
- [ ] T046 [US2] Add support for user-customizable search APIs (Google, custom) in `Hex/Models/SearchSettings.swift`

**Checkpoint**: User Story 2 is fully functional - users can search web and local files via voice independently

- [x] T046 [US2] Add support for user-customizable search APIs (Google, Bing, custom) in `Hex/Models/SearchSettings.swift`

**Checkpoint**: Phase 5 Complete! - User Story 2 fully featured with configurable search providers

---

## Phase 6: User Story 3 - Voice Productivity Tools (Priority: P3)

**Goal**: Enable voice-controlled productivity features including timers, calculations, notes, and todo management

**Independent Test**: User sets a 25-minute timer which alerts on completion. User calculates "15% of 250" and gets result. User creates a note and it's stored. All features work independently.

### Implementation for User Story 3

- [x] T047 [P] [US3] Create timer management service in `Hex/Features/AIAssistant/TimerManager.swift`
- [x] T048 [P] [US3] Create calculator service in `Hex/Features/AIAssistant/Calculator.swift`
- [x] T049 [P] [US3] Implement note creation and storage in `Hex/Features/AIAssistant/NoteService.swift`
- [x] T050 [P] [US3] Implement todo list management in `Hex/Features/AIAssistant/TodoService.swift`
- [x] T051 [US3] Add timer, calculator, note, and todo actions to AIAssistantFeature in `Hex/Features/AIAssistant/AIAssistantFeature.swift` (reference unified state schema from T013)
- [x] T052 [US3] Create TimerNotificationView for timer alerts in `Hex/Views/TimerNotificationView.swift`
- [x] T053 [US3] Create CalculatorResultView for displaying calculation results in `Hex/Views/CalculatorResultView.swift`
- [x] T054 [US3] Create NoteEditorView for note creation and editing in `Hex/Views/NoteEditorView.swift`
- [x] T055 [US3] Create TodoListView for managing todo items in `Hex/Views/TodoListView.swift`
- [x] T056 [US3] Add CoreData persistence for notes and todos in `Hex/Features/AIAssistant/PersistenceService.swift`
- [x] T057 [US3] Implement natural language parsing for calculations in `Hex/Features/AIAssistant/CalculationParser.swift`
- [x] T058 [US3] Create test cases for timers, calculations, notes, and todos in `Hex/Features/AIAssistant/Tests/ProductivityToolsTests.swift`

**Checkpoint**: All user stories are fully functional - all core AI assistant capabilities work independently

---

## Phase 7: Cross-Story Integration & Polish

**Purpose**: Ensure seamless integration between user stories and system hardening

- [x] T059 [P] Add comprehensive error logging across all stories in `Hex/Features/AIAssistant/ErrorLogger.swift`
- [x] T060 [P] Implement command history tracking in `Hex/Features/AIAssistant/CommandHistory.swift`
- [x] T061 [P] Add performance metrics collection in `Hex/Features/AIAssistant/PerformanceMetrics.swift`
- [x] T062 Add context-aware response adaptation (time of day, current app) in `Hex/Features/AIAssistant/ContextAwareness.swift` (reference T014 ConversationContextManager)
- [x] T063 Implement user preference storage and loading in `Hex/Models/AIAssistantSettings.swift`
- [x] T064 Create settings UI for customizing search providers and model selection in `Hex/Views/AIAssistantSettingsView.swift`
- [x] T065 Add voice feedback/audio output for responses in `Hex/Features/AIAssistant/VoiceFeedback.swift`
- [x] T066 Implement workflow trigger system supporting time-based, event-based, and context-based automation in `Hex/Features/AIAssistant/WorkflowTriggerEngine.swift`
- [x] T067 [P] Documentation updates for feature usage in `docs/ai-assistant-usage.md`
- [x] T068 [P] Add user guide for voice commands in `docs/voice-commands-reference.md`
- [x] T069 Code cleanup and SwiftUI view optimizations in `Hex/Features/AIAssistant/CodeCleanupGuide.swift`
- [x] T070 Performance optimization for model loading and inference in `Hex/Features/AIAssistant/ModelLoadingOptimizer.swift`
- [x] T071 Security hardening for API calls and local data storage in `Hex/Clients/SecurityHardeningProvider.swift`
- [x] T072 Run full integration tests across all user stories in `HexTests/IntegrationTests.swift`
- [x] T073 Validate all success criteria from spec (SC-001 through SC-007) in `Hex/Features/AIAssistant/SuccessCriteriaValidation.swift`

**Checkpoint**: ✅ Feature complete and ready for production

**Phase 7 Summary**:

- T059-T061: Infrastructure (error logging, command history, performance metrics)
- T062-T066: Integration (context awareness, settings, UI, voice feedback, workflows)
- T067-T068: Documentation (usage guide, command reference)
- T069-T070: Code quality & performance (cleanup guide, model optimizer)
- T071-T073: Security, testing & validation (hardening, integration tests, success criteria)

**Status**: ✅ ALL 73 TASKS COMPLETE (100%)

---

## Dependencies & Execution Order

### Phase Dependencies

1. **Setup (Phase 1)**: No dependencies - start immediately
2. **Foundational (Phase 2)**: Depends on Setup completion - **BLOCKS all user stories**
3. **User Stories (Phases 3-6)**:
   - Phase 3 (US1) & Phase 4 (US5): Both can run in parallel after Foundational, both are P1
   - Phase 5 (US2): Can start after Foundational, after US1 or US5 (independent but P2)
   - Phase 6 (US3): Can start after Foundational, after US1/US2/US5 (independent but P3)
4. **Polish (Phase 7)**: Depends on all desired user stories being complete

### User Story Dependencies

- **US1 (Voice System Control) - P1**: Independent. Depends only on Foundational phase.
- **US5 (AI Model Management) - P1**: Independent. Depends only on Foundational phase. Can run in parallel with US1.
- **US2 (Voice Information Search) - P2**: Independent but naturally follows US1. Depends only on Foundational phase.
- **US3 (Voice Productivity Tools) - P3**: Independent but naturally follows US1, US2, US5. Depends only on Foundational phase.

### Within Each User Story

1. Tests and models first (can run in parallel)
2. Services/handlers next (may depend on models)
3. UI views
4. Integration and error handling
5. Story complete before moving to next priority

### Parallel Opportunities

**Phase 1 (Setup)**:

- T004, T005, T006 can run in parallel (different CoreData entities and DependencyValues)

**Phase 2 (Foundational)**:

- T010 can run in parallel with other foundational tasks

**After Foundational Complete - Parallel User Story Strategy**:

```
Timeline A:
├─ US1 (T013-T022) by Developer A
├─ US5 (T023-T031) by Developer B (parallel with US1)
└─ US2 (T032-T041) by Developer C (can follow or overlap)

Timeline B (Sequential - one developer):
├─ US1 (T013-T022) Complete & Checkpoint
├─ US5 (T023-T031) Complete & Checkpoint
├─ US2 (T032-T041) Complete & Checkpoint
└─ US3 (T042-T053) Complete & Checkpoint
```

**Within User Story 1**:

- T013, T014, T015 can run in parallel (different command handlers)

**Within User Story 5**:

- T023, T024 can run in parallel (different HuggingFaceClient methods)

**Within User Story 2**:

- T032, T033 can run in parallel (web search vs file search)

**Within User Story 3**:

- T042, T043, T044, T045 can run in parallel (different services)

---

## Parallel Execution Example: User Story 1

```
Thread 1: T013 Create SystemCommand enum
Thread 2: T014 Implement app management handler
Thread 3: T015 Implement window management handler

After threads complete:
→ T016 Add commands to state
→ T017 Create indicator view
→ T018 Implement parsing
→ T019 Add execution
→ T020 Write tests
→ T021 Add suggestions
→ T022 Add clarification
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. ✅ Complete Phase 1: Setup
2. ✅ Complete Phase 2: Foundational (CRITICAL)
3. ✅ Complete Phase 3: User Story 1 (Voice System Control)
4. **STOP and VALIDATE**: Test User Story 1 independently
5. **SHIP MVP**: Users can control Mac via voice commands

### Incremental Delivery (Recommended)

1. **Milestone 1**: Setup + Foundational → Foundation ready
2. **Milestone 2**: Add US1 (Voice System Control) → MVP! (Can ship here)
3. **Milestone 3**: Add US5 (AI Model Management) → Users choose models
4. **Milestone 4**: Add US2 (Information Search) → Rich assistant
5. **Milestone 5**: Add US3 (Productivity Tools) → Full-featured assistant
6. **Milestone 6**: Polish & Integration → Production ready

### Parallel Team Strategy (4+ developers)

1. Everyone: Complete Setup + Foundational together (2 developers can help with setup, 2 start prep)
2. Once Foundational done:
   - Dev A: User Story 1 (Voice System Control)
   - Dev B: User Story 5 (AI Model Management)
   - Dev C: User Story 2 (Information Search)
   - Dev D: User Story 3 (Productivity Tools)
3. Each story completes independently and integrates seamlessly
4. 1-2 developers handle Polish & Integration phase

### Checkpoint Validation

After each user story, validate independently:

```bash
# After US1: System control works without models, search, or productivity tools
# After US5: Models work independently
# After US2: Search works without requiring specific model
# After US3: Productivity works without search or models
# All stories should be testable in isolation
```

---

## Notes

- [P] tasks = different files, no inter-dependencies within the same phase component
- [Story] labels (US1, US5, US2, US3) map tasks to specific user stories
- Each user story is independently completable and testable
- All stories reuse TranscriptionFeature patterns for hotkey/audio handling
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently without breaking others
- Each story should add value without requiring the previous story
- Phase 2 (Foundational) MUST complete before any user story work begins
