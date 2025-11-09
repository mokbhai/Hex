# Implementation Plan: Local AI Assistant

**Branch**: `001-local-ai-assistant` | **Date**: November 6, 2025 | **Spec**: specs/001-local-ai-assistant/spec.md
**Input**: Feature specification from `/specs/001-local-ai-assistant/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Transform Hex from a transcription tool into a comprehensive voice-powered AI assistant that performs system tasks, searches information, and manages productivity through natural voice commands. The implementation will reuse existing TranscriptionFeature patterns, run all AI models locally on macOS, and follow TCA architecture with SwiftUI.

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

## Technical Context

**Language/Version**: Swift 5.9  
**Primary Dependencies**: TCA, SwiftUI, Hugging Face models (via custom client), AVFoundation, CoreData for local storage  
**Storage**: CoreData for user data (notes, todos), local file system for downloaded AI models  
**Testing**: Swift Testing framework  
**Target Platform**: macOS 13+  
**Project Type**: macOS native application  
**Performance Goals**: Voice recognition with 95% accuracy in quiet environments, command execution in under 3 seconds, model downloads in under 5 minutes  
**Constraints**: All AI models run locally, voice recordings deleted immediately after processing, reuse existing code patterns  
**Scale/Scope**: Single user application, support for multiple local AI models, local data storage## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

- **I. TCA-centric Development**: ✅ Yes, the feature will be implemented using TCA reducers and state management
- **II. Dependency-Managed Clients**: ✅ Yes, external dependencies (Hugging Face, AVFoundation) will be wrapped in clients and injected
- **III. SwiftUI for UI**: ✅ Yes, UI will be built with SwiftUI
- **IV. Swift Testing Framework**: ✅ Yes, tests will use Swift Testing framework
- **V. Modular Features**: ✅ Yes, the feature will be organized as a modular AIAssistant component

## Project Structure

### Documentation (this feature)

```text
specs/001-local-ai-assistant/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
Hex/
├── Features/
│   ├── AIAssistant/           # New feature module
│   │   ├── AIAssistantFeature.swift
│   │   ├── AIAssistantView.swift
│   │   ├── ModelDownloadView.swift
│   │   └── Tests/
│   │       └── AIAssistantFeatureTests.swift
│   └── Transcription/         # Existing, reuse patterns
├── Clients/
│   ├── AIClient.swift         # New client for local AI inference
│   ├── HuggingFaceClient.swift # New client for model downloads
│   └── TranscriptionClient.swift # Existing, reference for patterns
├── Models/
│   ├── AIModel.swift          # New model for AI model metadata
│   ├── Note.swift             # Existing or new for notes
│   ├── TodoItem.swift         # New for todos
│   └── Reminder.swift         # New for reminders
└── Views/
    ├── AIAssistantIndicatorView.swift # New visual indicator
    └── ModelSelectionView.swift # New for model management
```

**Structure Decision**: Following the existing Hex modular structure with Features/, Clients/, Models/, and Views/ directories. The AIAssistant feature reuses TranscriptionFeature patterns for hotkey handling and audio processing, while adding new components for AI inference and model management.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation                  | Why Needed         | Simpler Alternative Rejected Because |
| -------------------------- | ------------------ | ------------------------------------ |
| [e.g., 4th project]        | [current need]     | [why 3 projects insufficient]        |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient]  |
