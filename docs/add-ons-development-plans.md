# Hex Add-ons Development Plans

## Overview

This document outlines plans for two major add-ons to the Hex voice-to-text application:

1. **AI Agent Add-on**: A conversational AI assistant that can perform system tasks and provide information
2. **Context Menu Add-on**: Right-click functionality for text manipulation using local AI models

## Add-on 1: AI Agent Assistant

### Vision

Transform Hex from a simple transcription tool into a comprehensive voice-powered AI assistant that can control your Mac, perform calculations, search the web, and manage tasks through natural voice commands.

### Core Features

#### 1.1 System Control Commands

- **App Management**: "Open Safari", "Close Mail", "Switch to Finder"
- **Window Management**: "Maximize window", "Split screen", "Hide all windows"
- **System Actions**: "Empty trash", "Show desktop", "Lock screen"

#### 1.2 Information & Search

- **Web Search**: "Search Google for SwiftUI tutorials"
- **Local Search**: "Find files containing 'project proposal'"
- **Information Queries**: "What's the weather today?", "Show my calendar events"

#### 1.3 Productivity Tools

- **Timer/Reminders**: "Set a 25-minute timer", "Remind me to call mom at 3pm"
- **Calculations**: "What's 15% of 250?", "Calculate mortgage payment"
- **Notes**: "Create a note about the meeting", "Add to my todo list"

#### 1.4 Smart Automation

- **Workflow Triggers**: "Start my morning routine" (opens email, calendar, news)
- **Context Awareness**: Adapts responses based on current app, time of day, user patterns

### Technical Architecture

#### 1.4.1 AI Model Integration

- **Primary Model**: Use existing WhisperKit infrastructure for speech-to-text
- **Secondary Model**: Integrate smaller LLM (like Phi-2 or Llama-2-7B) for command understanding
- **Fallback**: Cloud API integration (OpenAI/Claude) for complex queries

#### 1.4.2 Command Processing Pipeline

```
Voice Input → WhisperKit → Intent Classification → Command Execution → Voice Feedback
```

#### 1.4.3 System Integration

- **AppleScript Bridge**: Execute system commands via AppleScript
- **Accessibility API**: UI automation for app control
- **Native APIs**: Calendar, Reminders, Timer access via EventKit, UserNotifications

### Implementation Phases

#### Phase 1: Core Infrastructure (2-3 weeks)

- [ ] Set up local LLM integration (model download, inference pipeline)
- [ ] Create command parser and intent classification system
- [ ] Implement basic AppleScript execution framework
- [ ] Add voice feedback system (TTS integration)

#### Phase 2: System Commands (2 weeks)

- [ ] App launching/closing functionality
- [ ] Window management commands
- [ ] Basic system actions (trash, desktop, etc.)
- [ ] Error handling and user feedback

#### Phase 3: Information Features (2 weeks)

- [ ] Web search integration (browser automation)
- [ ] Local file search capabilities
- [ ] Basic calculation engine
- [ ] Weather and time information

#### Phase 4: Advanced Features (3 weeks)

- [ ] Timer and reminder system
- [ ] Note-taking integration
- [ ] Workflow automation
- [ ] Context-aware responses

### User Experience Considerations

#### 1.5.1 Voice Feedback

- **Confirmation**: "Opening Safari" before executing
- **Results**: "Found 3 files matching your search"
- **Errors**: "I couldn't find that application"

#### 1.5.2 Privacy & Security

- **Local Processing**: Keep sensitive commands local
- **Permission Model**: Clear consent for system access
- **Audit Trail**: Optional logging of AI actions

#### 1.5.3 Accessibility

- **Visual Feedback**: Show what the AI is doing
- **Cancellation**: Voice commands to stop actions
- **Fallback**: Manual confirmation for destructive actions

## Add-on 2: Context Menu Text Manipulation

### Vision

Add intelligent text manipulation capabilities accessible via right-click context menus, powered by local AI models for privacy and speed.

### Core Features

#### 2.1 Text Enhancement

- **Rewrite**: Rephrase selected text for clarity or style
- **Proofread**: Grammar and style corrections
- **Tone Adjustment**: Make text more formal, casual, or professional
- **Length Modification**: Shorten or expand text while preserving meaning

#### 2.2 Formatting Tools

- **Bullet Points**: Convert paragraphs to structured lists
- **Summary**: Create concise summaries of selected text
- **Action Items**: Extract tasks and todos from text
- **Email Formatting**: Structure text as professional emails

#### 2.3 Specialized Tools

- **Code Comments**: Generate documentation for code snippets
- **Meeting Notes**: Convert speech-to-text into structured meeting notes
- **Social Media**: Adapt text for different platforms (Twitter, LinkedIn, etc.)

### Technical Architecture

#### 2.4.1 Local AI Integration

- **Model Selection**: Use efficient local models (DistilBERT, T5-small, or custom fine-tuned models)
- **On-Device Inference**: Leverage CoreML for fast, private processing
- **Model Management**: Download and update models seamlessly

#### 2.4.2 Context Menu Integration

- **System Extension**: macOS Service extension for global right-click access
- **Text Selection**: Capture selected text from any application
- **UI Framework**: SwiftUI-based popup menu with live preview

#### 2.4.3 Processing Pipeline

```
Text Selection → Preprocessing → AI Model → Post-processing → Replace/Insert
```

### Implementation Phases

#### Phase 1: Foundation (2 weeks)

- [ ] Create macOS Service extension for context menu
- [ ] Implement text selection capture from any app
- [ ] Set up CoreML model integration framework
- [ ] Design context menu UI with SwiftUI

#### Phase 2: Core Text Tools (3 weeks)

- [ ] Implement text rewriting functionality
- [ ] Add grammar and proofreading capabilities
- [ ] Create bullet point conversion feature
- [ ] Build summary generation system

#### Phase 3: Advanced Features (2 weeks)

- [ ] Tone adjustment and style transfer
- [ ] Specialized formatters (emails, social media)
- [ ] Code documentation generation
- [ ] Meeting note structuring

#### Phase 4: Polish & Integration (2 weeks)

- [ ] Performance optimization for large text blocks
- [ ] Undo/redo functionality
- [ ] Keyboard shortcuts integration
- [ ] Settings and customization options

### User Experience Considerations

#### 2.5.1 Performance

- **Speed**: Sub-second processing for typical text selections
- **Offline**: Full functionality without internet connection
- **Resource Management**: Efficient memory usage for long documents

#### 2.5.2 Privacy & Security

- **Local Processing**: All text processing happens on-device
- **No Data Transmission**: Selected text never leaves the user's Mac

#### 2.5.3 Integration

- **Universal Access**: Works in any macOS application
- **Preview**: Show changes before applying
- **Multi-language**: Support for multiple languages
- **Accessibility**: Full VoiceOver and keyboard navigation support

## Add-on 3: Real-Time AI Voice Enhancement

### Vision

When users dictate, run the draft transcript through an on-device or low-latency LLM pass before it appears in the editor. The model cleans up punctuation, fixes transcription errors, enforces style/tone preferences, and streams improved text back so the experience still feels instantaneous.

### Core Features

#### 3.1 Continuous Text Enhancement

- **Smart Punctuation**: Insert commas, periods, and capitalization in-line with natural speech pauses.
- **Grammar & Spelling Repair**: Detect and resolve homophones, filler words, and tense mismatches typical in raw dictation.
- **Clarity & Brevity Options**: Toggle between literal transcription and concise, edited prose per utterance.

#### 3.2 Personalization Controls

- **Tone Presets**: Friendly/professional/technical presets that adjust vocabulary and structure.
- **Domain Boosting**: Custom dictionaries and few-shot prompts for legal, medical, coding, etc.
- **Adaptive Memory**: Optional user-specific corrections (names, acronyms) stored locally for future sessions.

#### 3.3 Safety & Transparency

- **Original vs Enhanced View**: Split-view or diff of raw transcription versus LLM output.
- **Revert/Accept Gestures**: Keyboard shortcut or voice command (“use original”) to undo aggressive edits.
- **Privacy Guardrails**: Local-first processing with user opt-in before falling back to cloud LLMs.

### Technical Architecture

#### 3.4.1 Processing Pipeline

```
Voice Input → WhisperKit Transcript → Chunker/Buffer → LLM Enhancement → Streaming Merge → Editor Output
```

- **Chunker**: Buffer 1–2 sentences to give the LLM enough context without noticeable latency.
- **LLM Layer**: Prefer quantized local model (Phi-3-mini, Llama 3.1 8B) with optional cloud escalation for long-form edits.
- **Streaming Merge**: Diff/patch engine so upgraded text can overwrite the in-progress editor buffer without cursor jumps.

#### 3.4.2 Real-Time Transport

- **Async Pipeline**: Dedicated enhancement queue to avoid blocking WhisperKit recognition thread.
- **Fallback Logic**: If the LLM stalls, bypass enhancement and show raw transcript to maintain responsiveness.
- **Telemetry Hooks**: Measure latency, edit distance between raw/enhanced text, and user reverts for tuning.

### Implementation Phases

#### Phase 1: Prototype (1 week)

- [ ] Build text-only prototype: feed sample transcripts through chosen LLM and evaluate output quality.
- [ ] Define prompt templates plus tone/domain parameters.
- [ ] Instrument latency and quality metrics.

#### Phase 2: Streaming Integration (2 weeks)

- [ ] Implement transcript chunker and queue.
- [ ] Integrate LLM inference (local CoreML pipeline + optional remote API abstraction).
- [ ] Build merge algorithm that replaces text in-place while keeping caret position.

#### Phase 3: UX & Controls (1 week)

- [ ] Add toolbar toggle for “Enhanced dictation” with tone presets.
- [ ] Provide raw/enhanced diff view and quick revert actions.
- [ ] Surface inline indicators when AI edits a phrase.

#### Phase 4: Optimization & Safety (1-2 weeks)

- [ ] Cache user-specific corrections securely on-device.
- [ ] Add content filters/toxicity guardrails before text insertion.
- [ ] Tune models/prompts based on telemetry and user feedback loops.

### User Experience Considerations

#### 3.5.1 Latency Budget

- **Target**: <150 ms added delay per sentence; fall back automatically if exceeded.
- **Graceful Degradation**: Flash subtle “draft” indicator until enhanced text replaces placeholder.

#### 3.5.2 Trust & Control

- **Explicit Toggle**: Users can disable enhancement globally or per-app.
- **Audit Trail**: Optional log showing AI edits for compliance-heavy workflows.

#### 3.5.3 Privacy

- **Local Storage Only**: Custom dictionaries and tone settings remain on device.
- **Cloud Opt-In**: Prompt before sending text to remote LLM; redact sensitive entities when possible.
- **Model Encryption**: Optional encryption for sensitive AI models

## Shared Technical Considerations

### 3.1 Model Management

- **Storage**: Efficient model caching and updates
- **Versioning**: Handle model updates without breaking functionality
- **Fallback**: Graceful degradation when models are unavailable

### 3.2 Performance Optimization

- **Memory Management**: Efficient loading/unloading of AI models
- **Background Processing**: Non-blocking UI during AI operations
- **Caching**: Smart caching of frequent operations

### 3.3 User Interface

- **Consistent Design**: Match Hex's existing SwiftUI design language
- **Feedback Systems**: Clear progress indicators and error messages
- **Settings Integration**: Unified settings panel for both add-ons

### 3.4 Testing Strategy

- **Unit Tests**: Core logic and AI model integration
- **Integration Tests**: End-to-end workflows
- **Performance Tests**: Memory usage and processing speed
- **User Testing**: Real-world usage scenarios

## Timeline & Resources

### Estimated Timeline

- **AI Agent**: 8-10 weeks total development
- **Context Menu**: 6-8 weeks total development
- **Parallel Development**: 10-12 weeks for both

### Resource Requirements

- **AI/ML Engineer**: For model integration and optimization
- **macOS Developer**: For system integration and extensions
- **UX Designer**: For intuitive user interfaces
- **QA Tester**: For comprehensive testing across macOS versions

### Success Metrics

- **AI Agent**: 90%+ command success rate, <2 second response time
- **Context Menu**: <1 second processing for typical selections, 95%+ user satisfaction
- **Performance**: No significant impact on system resources

## Risk Assessment & Mitigation

### Technical Risks

- **AI Model Performance**: Mitigated by model selection and optimization
- **System Integration Complexity**: Addressed with phased implementation
- **macOS Compatibility**: Regular testing across target OS versions

### Business Risks

- **Privacy Concerns**: Emphasize local processing and data security
- **Performance Impact**: Careful resource management and optimization
- **User Adoption**: Intuitive UX design and clear value proposition

---

_This document serves as a high-level roadmap for Hex add-on development. Implementation details may evolve based on technical discoveries and user feedback._
