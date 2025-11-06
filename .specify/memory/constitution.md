<!--
Sync Impact Report:
- Version change: 0.0.0 → 1.0.0
- List of modified principles: None (initial creation)
- Added sections: Core Principles, Development Workflow, Governance
- Removed sections: None
- Templates requiring updates:
  - ✅ .specify/templates/plan-template.md
  - ✅ .specify/templates/spec-template.md
  - ✅ .specify/templates/tasks-template.md
- Follow-up TODOs: None
-->
# Hex Constitution

## Core Principles

### I. TCA-centric Development
The Composable Architecture (TCA) is the primary framework for state management and feature development. All new features must be implemented as TCA reducers, and state changes must be managed through actions and reducers. This ensures a predictable and testable application architecture.

### II. Dependency-Managed Clients
External dependencies (e.g., WhisperKit, Sauce) and system frameworks (e.g., AVAudioRecorder, NSPasteboard) must be wrapped in dependency clients and injected into TCA features using the `@Dependency` property wrapper. This promotes testability and modularity by isolating side effects.

### III. SwiftUI for UI
The user interface is built exclusively with SwiftUI. Views should be lightweight and primarily responsible for presenting state provided by a TCA `ViewStore`.

### IV. Swift Testing Framework
All unit and integration tests must be written using the Swift Testing framework. Tests should be co-located with the feature they are testing.

### V. Modular Features
Features should be organized into modular components, each with its own reducer, state, actions, and view. This promotes code reuse and simplifies maintenance.

## Development Workflow

All development should follow a feature-driven approach. New features or significant changes should be developed in separate branches and merged into `main` via pull requests. Pull requests must be reviewed and pass all CI checks before being merged.

## Governance

This constitution is the single source of truth for architectural and development practices. All code contributions must adhere to these principles. Amendments to this constitution require a pull request and approval from the project maintainers.

**Version**: 1.0.0 | **Ratified**: 2025-11-06 | **Last Amended**: 2025-11-06