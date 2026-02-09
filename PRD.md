# Hex Voice - Product Requirements Document

## Core Features

### Voice Recording
- **Hotkey-triggered recording** with press-and-hold or double-tap modes
- **Visual recording indicator** in menu bar (pulsing red when active)
- **Real-time audio metering** with visual feedback
- **Escape key cancellation** to stop recording
- **Modifier-only hotkey support** (e.g., Option key) with anti-accidental-trigger threshold
- **Force quit voice command** - "force quit hex now" for emergency exit

### Transcription
- **On-device speech-to-text** using Core ML models
- **Automatic transcription** after recording ends
- **Transcription indicator** (blue when processing)
- **Source application detection** - tracks which app was active during recording
- **60+ language support** with auto-detection option

### Text Output
- **Auto-paste** - inserts transcribed text into active application
- **Clipboard insertion mode** - fast clipboard paste vs. simulated keypresses
- **Copy to clipboard** - copies text in addition to pasting
- **Paste last transcript hotkey** - dedicated shortcut to re-paste last transcription

## AI Features

### Text Refinement
- **OpenAI-powered text refinement** using GPT models for grammar and clarity improvement
- **Auto-refine transcriptions** - automatically refine all transcriptions
- **Manual refinement hotkey** - refine selected text on-demand
- **In-place text replacement** - replaces selected text with refined version
- **Configurable refinement parameters**:
  - Model selection (GPT-4o-mini, GPT-4o, GPT-4.1, or custom model name)
  - Base URL configuration (supports OpenAI-compatible endpoints like OpenRouter, DeepSeek, etc.)
  - Temperature slider (0-1)
  - Max tokens (64-4096)
- **API key management** - secure storage of API key for configured endpoint

## History

### Transcription History
- **Persistent storage** of all transcriptions
- **Audio playback** - listen to original recordings
- **Copy to clipboard** from history entries
- **Delete individual entries** or clear all history
- **Source app tracking** - shows which app received the transcription
- **Timestamp and duration** display for each entry
- **Automatic cleanup** - removes oldest entries when limit reached
- **Configurable history limit** - unlimited, 50, 100, 200, 500, or 1000 entries
- **Toggle history on/off**

## Models

### Transcription Models
- **Curated model selection**:
  - Parakeet TDT v2 (English, 650MB) - "BEST FOR ENGLISH"
  - Parakeet TDT v3 (Multilingual, 650MB) - "BEST FOR MULTILINGUAL"
  - Whisper Tiny (73MB)
  - Whisper Base (140MB)
  - Whisper Large v3 (1.5GB)
- **Model download management** with progress tracking
- **Delete models** to free up space
- **Show in Finder** - locate model files
- **Model availability detection**

## Settings

### Hotkey Configuration
- **Main recording hotkey** - custom modifier + key combination
- **Modifier side selection** - left/right/either for modifiers
- **Double-tap only mode toggle**
- **Minimum key time slider** (0-2 seconds) for modifier-only shortcuts
- **0.3s threshold** for modifier-only hotkeys to prevent accidental triggers

### Microphone Selection
- **Input device picker** with all available microphones
- **System default option** (shows device name)
- **Refresh device list** button
- **Automatic fallback** to system default if selected device disconnected

### Audio Behavior
- **Sound effects** toggle with volume slider (0-100%)
- **Prevent system sleep** while recording
- **Audio behavior during recording**:
  - Pause media playback
  - Mute system volume
  - Do nothing

### General Settings
- **Open on login** - launch at startup
- **Show dock icon** toggle
- **Use clipboard to insert** - fast clipboard vs. simulated keypresses

### Word Transformations
- **Word removals** - regex pattern matching to remove specific words
- **Word remappings** - replace words with alternatives
- **Case-insensitive matching**
- **Enable/disable individual transformations**
- **Live preview scratchpad** to test transformations

## Permissions

### Required Permissions
- **Microphone permission** - for audio recording
- **Accessibility permission** - for text capture and refinement
- **Input monitoring permission** - for hotkey detection
- **Permission status indicators** showing granted/denied state

## Updates

### Auto-Updates
- **Sparkle integration** for automatic updates
- **Changelog view** showing version history
- **About view** with app information
