# Research Findings: Local AI Assistant

**Date**: November 6, 2025
**Feature**: Local AI Assistant
**Research Focus**: Local AI model inference on macOS, Hugging Face integration, Swift implementation patterns

## Decision: Use Core ML for Local AI Inference

**Rationale**: Core ML provides native macOS support for running ML models locally with hardware acceleration. It integrates seamlessly with Swift and supports various model formats including those from Hugging Face.

**Alternatives Considered**:

- Direct MLX framework: More flexible but requires more custom implementation
- Python-based inference: Would require embedding Python runtime, increasing complexity
- Third-party Swift ML libraries: Less mature and less optimized for macOS

## Decision: Hugging Face Model Hub Integration via Core ML

**Rationale**: Hugging Face provides Core ML compatible models that can be downloaded and run locally. Use their Swift client or custom implementation for model discovery and download.

**Alternatives Considered**:

- Custom model hosting: Would require maintaining own model repository
- Pre-bundled models: Limits user choice and increases app size
- Cloud-based inference: Violates local-only requirement

## Decision: Reuse TranscriptionFeature Hotkey Pattern

**Rationale**: The existing TranscriptionFeature already implements hotkey listening and audio recording. Reuse this pattern for the AI assistant hotkey to maintain consistency and reduce development time.

**Alternatives Considered**:

- Separate hotkey implementation: Would duplicate code and increase maintenance
- Global hotkey system: More complex and potentially conflicting with system hotkeys

## Decision: SQLite/CoreData for Local Data Storage

**Rationale**: CoreData is already used in the project for settings. Extend it for notes, todos, and reminders to maintain consistency.

**Alternatives Considered**:

- File-based JSON storage: Simpler but less robust for concurrent access
- External database: Unnecessary complexity for local single-user app

## Decision: Swift Async/Await for Asynchronous Operations

**Rationale**: Modern Swift concurrency patterns are already used in the codebase. Use async/await for model downloads, inference, and API calls.

**Alternatives Considered**:

- Completion handlers: Legacy pattern, harder to maintain
- Combine framework: Good but async/await is more straightforward for this use case

## Decision: Visual Feedback with NSStatusItem Animation

**Rationale**: Use macOS native status bar item with animation to indicate listening state, similar to existing transcription indicator but differentiated.

**Alternatives Considered**:

- Modal overlay: Too intrusive for voice commands
- System notifications: Not immediate enough for real-time feedback
- No visual feedback: Poor user experience

## Performance Benchmarks Established

- Model download: Target <5 minutes for typical model sizes (100MB-1GB)
- Inference latency: <2 seconds for text generation tasks
- Voice processing: Maintain existing <3 second response time
- Memory usage: <500MB additional for loaded models
