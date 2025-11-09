# Quick Start: Local AI Assistant

**Feature**: Local AI Assistant
**Date**: November 6, 2025

## Overview

This guide helps developers quickly understand and start working on the Local AI Assistant feature, which transforms Hex into a voice-powered AI companion.

## Prerequisites

- macOS 13+
- Xcode 15+
- Swift 5.9+
- Access to Hugging Face Hub (for model downloads)

## Architecture Overview

The feature follows Hex's TCA architecture:

- **AIAssistantFeature**: Main TCA reducer managing state and actions
- **AIClient**: Dependency client for local AI inference
- **HuggingFaceClient**: Client for model discovery and downloads
- **CoreData**: Local storage for user data and model metadata

## Key Components

### 1. Hotkey Integration

Reuses `TranscriptionFeature` pattern for hotkey listening:

```swift
// Similar to existing transcription hotkey
let aiHotkey = HotKey(key: .space, modifiers: [.command, .shift])
```

### 2. Voice Processing Pipeline

1. Hotkey press → Start listening with visual indicator
2. Audio capture → Local speech-to-text
3. Text processing → AI inference for intent recognition
4. Command execution → System actions or responses
5. Cleanup → Delete audio data immediately

### 3. Model Management

- Browse models on Hugging Face
- Download Core ML compatible models
- Load/unload models based on usage
- Cache management for performance

## Development Workflow

### 1. Set Up Feature Module

```bash
# Create feature directory
mkdir -p Hex/Features/AIAssistant

# Add to Xcode project
# (Follow existing Transcription feature structure)
```

### 2. Implement Core TCA Structure

```swift
public struct AIAssistantFeature: Reducer {
    public struct State {
        var isListening = false
        var currentModel: AIModel?
        var downloadedModels: [AIModel] = []
    }

    public enum Action {
        case startListening
        case stopListening
        case processAudio(Data)
        case executeCommand(String)
    }
}
```

### 3. Add Client Dependencies

```swift
extension DependencyValues {
    var aiClient: AIClient {
        get { self[AIClient.self] }
        set { self[AIClient.self] = newValue }
    }

    var huggingFaceClient: HuggingFaceClient {
        get { self[HuggingFaceClient.self] }
        set { self[HuggingFaceClient.self] = newValue }
    }
}
```

### 4. Test Implementation

```swift
@Test
func testVoiceCommandExecution() async {
    let store = TestStore(initialState: AIAssistantFeature.State()) {
        AIAssistantFeature()
    }

    await store.send(.startListening)
    // Verify listening state
}
```

## Common Patterns

### Reusing Transcription Code

```swift
// Reference TranscriptionFeature for hotkey handling
// Reuse audio recording logic
// Adapt transcription result processing
```

### Error Handling

```swift
// Follow existing error patterns
// Use Swift's Result type for async operations
// Provide user-friendly error messages
```

### State Management

```swift
// Use TCA patterns consistently
// Separate UI state from business logic
// Handle async operations with effects
```

## Testing Strategy

- **Unit Tests**: TCA reducers, client interfaces
- **Integration Tests**: End-to-end voice command flows
- **Performance Tests**: Model loading, inference latency
- **UI Tests**: Voice interaction scenarios

## Deployment Notes

- Models downloaded on-demand (not bundled)
- Core ML models optimized for Apple Silicon
- Local inference ensures privacy
- Graceful fallback when models unavailable

## Next Steps

1. Review the [implementation plan](plan.md)
2. Examine the [data model](data-model.md)
3. Check the [API contracts](contracts/)
4. Start with the TCA feature structure
5. Implement hotkey integration first
