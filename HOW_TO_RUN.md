# How to Run Hex - Local AI Assistant

## 🚀 Quick Start

### Prerequisites

Before you begin, ensure you have:

- **macOS 13 or later** (Apple Silicon or Intel)
- **Xcode 15.0 or later** ([Download from App Store](https://apps.apple.com/us/app/xcode/id497799835?mt=12))
- **Swift 5.9 or later** (included with Xcode 15+)
- **Git** (for cloning the repository)
- **At least 15-20 GB free disk space** (for AI models)

### System Requirements

| Component | Requirement |
|-----------|-------------|
| **OS** | macOS 13+ |
| **Architecture** | Apple Silicon (M1+) or Intel |
| **RAM** | 8 GB minimum, 16 GB recommended |
| **Disk Space** | 20 GB (for models) |
| **Xcode** | 15.0+ |
| **Swift** | 5.9+ |

---

## 📋 Step-by-Step Setup

### Step 1: Clone the Repository

```bash
# Clone the Hex repository
git clone https://github.com/mokbhai/Hex.git
cd Hex

# Switch to the AI Assistant feature branch
git checkout 001-local-ai-assistant
```

### Step 2: Open the Project in Xcode

```bash
# Open the Xcode project
open Hex.xcodeproj

# Or open the workspace if available
open Hex.xcworkspace
```

### Step 3: Configure Xcode

1. **Select Target**: In Xcode, select the **Hex** target (not tests)
2. **Select Scheme**: Select **Hex** scheme from the scheme dropdown
3. **Select Destination**: 
   - For **Apple Silicon Mac**: Select "My Mac (Apple Silicon)"
   - For **Intel Mac**: Select "My Mac (Intel)"

### Step 4: Build the Project

```bash
# Build using Xcode UI
# ⌘ + B (Command + B)

# Or build from terminal
xcodebuild -scheme Hex -destination 'generic/platform=macOS'
```

**First Build Note**: The first build may take 2-5 minutes as Xcode resolves Swift Package dependencies.

### Step 5: Run the Application

```bash
# Run using Xcode UI
# ⌘ + R (Command + R)

# Or run from terminal
xcodebuild -scheme Hex -destination 'platform=macOS' -configuration Debug
```

**First Run Note**: On first launch, the app downloads and compiles the Whisper model, which may take 5-15 minutes. You'll see high CPU usage from `ANECompilerService` (Apple's Neural Engine compiler) — this is normal.

---

## ✅ Post-Launch Configuration

### 1. Grant Permissions

When Hex first launches, you'll be prompted for two permissions:

#### ✓ Microphone Permission
- **Purpose**: Record your voice commands
- **Action**: Click "Allow" or grant in System Preferences → Security & Privacy → Microphone

#### ✓ Accessibility Permission
- **Purpose**: Control your Mac and paste text
- **Action**: Click "Allow" or grant in System Preferences → Security & Privacy → Accessibility

### 2. Configure Hotkey

1. **Open Settings** in Hex
2. **Go to "Hotkeys"** section
3. **Click "Record Hotkey"**
4. **Press your preferred key combination** (e.g., Command+Space)
5. **Click "Save"**

**Recommended Hotkeys**:
- `⌘ + Space` (Command + Space)
- `⌘ + Shift + Space` (Command + Shift + Space)
- `⌘ + Option + Space` (Command + Option + Space)

### 3. Select AI Model

1. **Open Settings**
2. **Go to "AI Models"** section
3. **Browse Available Models** from Hugging Face:
   - **Mistral 7B** (fastest, recommended for first-time users)
   - **Llama 2 7B** (good balance)
   - **Neural Chat 7B** (best quality)
4. **Click "Download"** to download the selected model
5. **Wait for download** (may take 3-10 minutes on typical internet)
6. **Activate Model** once download completes

### 4. Configure Search Provider (Optional)

1. **Open Settings**
2. **Go to "Search Providers"** section
3. **Choose Provider**:
   - **Google Search** (requires API key)
   - **Bing Search** (requires API key)
   - **Custom API** (default: ser.jainparichay.online)
4. **Enter API Key** if using Google or Bing
5. **Save Settings**

---

## 🎤 Using Hex - Voice Commands

### Recording Modes

#### Mode 1: Press-and-Hold
1. **Press and hold** your configured hotkey
2. **Speak your command** (e.g., "Open Safari")
3. **Release the hotkey** to process the command
4. **Wait for response** (typically 1-3 seconds)

#### Mode 2: Toggle (Double-Tap)
1. **Double-tap** your hotkey to start recording
2. **Speak your command**
3. **Tap the hotkey once** more to stop recording and process

### Example Voice Commands

#### System Control
- "Open Safari"
- "Close Mail"
- "Maximize window"
- "Lock screen"
- "Set volume to 50%"

#### Information Search
- "Search for Swift async/await"
- "Find files named project"
- "What's the weather?"

#### Productivity
- "Set a 5-minute timer"
- "Calculate 15% of 250"
- "Create a note about the meeting"
- "Add buy groceries to my todos"

---

## 🐛 Development & Testing

### Running Tests

#### Unit Tests
```bash
# Run all tests
⌘ + U (Command + U in Xcode)

# Or from terminal
xcodebuild test -scheme Hex -destination 'platform=macOS'
```

#### Specific Test Suite
```bash
# Run AI Assistant tests only
xcodebuild test -scheme Hex -destination 'platform=macOS' -only-testing HexTests/AIAssistantFeatureTests

# Run System Control tests
xcodebuild test -scheme Hex -destination 'platform=macOS' -only-testing HexTests/SystemControlTests

# Run Integration tests
xcodebuild test -scheme Hex -destination 'platform=macOS' -only-testing HexTests/IntegrationTests
```

### Debugging

#### Enable Debug Logging
Add to your code:
```swift
import os.log

let logger = Logger(subsystem: "com.hex.ai-assistant", category: "Debug")
logger.debug("Debug message: \(value)")
```

#### Debug in Xcode
1. Set breakpoints by clicking line numbers
2. Run with ⌘ + R
3. Use Debug navigator to inspect variables
4. Use Console to print debug output

#### View Logs
```bash
# Stream live logs from Hex
log stream --predicate 'process == "Hex"' --level debug

# Or in Console.app (Applications → Utilities)
```

---

## 📁 Project Structure for Development

```
Hex/
├── Hex/
│   ├── App/
│   │   ├── HexApp.swift              # Main app entry point
│   │   ├── HexAppDelegate.swift      # App lifecycle
│   │   └── CheckForUpdatesView.swift
│   │
│   ├── Features/
│   │   ├── AIAssistant/              # 🎯 NEW - Local AI Assistant
│   │   │   ├── AIAssistantFeature.swift
│   │   │   ├── SystemCommandExecutor.swift
│   │   │   ├── IntentRecognizer.swift
│   │   │   ├── ModelManager.swift
│   │   │   ├── WebSearchClient.swift
│   │   │   ├── TimerManager.swift
│   │   │   ├── Calculator.swift
│   │   │   ├── NoteService.swift
│   │   │   ├── TodoService.swift
│   │   │   └── Tests/
│   │   │       ├── SystemControlTests.swift
│   │   │       ├── ModelManagementTests.swift
│   │   │       ├── InformationSearchTests.swift
│   │   │       ├── ProductivityToolsTests.swift
│   │   │       └── IntegrationTests.swift
│   │   │
│   │   └── Other features...
│   │
│   ├── Clients/
│   │   ├── AIClient.swift            # AI inference interface
│   │   ├── HuggingFaceClient.swift   # Model discovery
│   │   ├── TranscriptionClient.swift # Speech-to-text
│   │   ├── RecordingClient.swift     # Audio recording
│   │   ├── SecurityHardeningProvider.swift  # API security
│   │   └── Other clients...
│   │
│   ├── Models/
│   │   ├── AIModel.swift             # AI models and entities
│   │   ├── HexSettings.swift
│   │   ├── Note.swift
│   │   ├── TodoItem.swift
│   │   └── Other models...
│   │
│   ├── Views/
│   │   ├── AIAssistantIndicatorView.swift
│   │   ├── AIAssistantSettingsView.swift
│   │   ├── ModelDownloadView.swift
│   │   ├── SearchResultsView.swift
│   │   └── Other views...
│   │
│   ├── Assets.xcassets
│   └── Resources/
│
├── HexTests/
│   ├── IntegrationTests.swift
│   └── Other test files...
│
├── docs/
│   ├── ai-assistant-usage.md         # User guide
│   ├── voice-commands-reference.md   # Command reference
│   └── local-ai-transcription-flow.md
│
└── specs/
    └── 001-local-ai-assistant/
        ├── plan.md                   # Architecture & tech stack
        ├── spec.md                   # Requirements & user stories
        ├── tasks.md                  # Implementation tasks (✅ ALL COMPLETE)
        ├── data-model.md            # Entity definitions
        └── contracts/               # API contracts
```

---

## 🔍 Verifying Installation

### Checklist to Confirm Everything is Working

- [ ] Xcode builds successfully without errors
- [ ] App launches without crashes
- [ ] Microphone permission dialog appears
- [ ] Accessibility permission dialog appears
- [ ] Settings window opens
- [ ] Can configure hotkey
- [ ] Can browse and download AI model
- [ ] Voice recording indicator appears when hotkey pressed
- [ ] Simple command "Open Safari" works
- [ ] Tests pass: `⌘ + U`

If any of these fail, see [Troubleshooting](#-troubleshooting) below.

---

## ⚠️ Troubleshooting

### Build Fails with Package Resolution Errors

**Problem**: Xcode hangs on "Resolving Package Dependencies"

**Solution**:
```bash
# Clear Xcode cache
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Clear Swift Package Manager cache
rm -rf ~/Library/Caches/org.swift.swiftpm

# Retry build: ⌘ + B
```

### App Crashes on Launch

**Problem**: App crashes immediately after launching

**Solution**:
1. Check Console.app for error messages
2. Ensure macOS version is 13+
3. Reinstall app: `rm -rf ~/Library/Caches/com.hex.ai-assistant`
4. Try clean build: `⌘ + Shift + K` then `⌘ + B`

### Microphone Not Working

**Problem**: Microphone permission denied or not working

**Solution**:
1. Grant permission: System Settings → Privacy & Security → Microphone → Add Hex
2. Test microphone: System Settings → Sound → Input
3. Restart Hex application

### Model Download Stuck

**Problem**: Model download hangs or fails

**Solution**:
1. Check internet connection
2. Try smaller model first (Mistral 7B)
3. Check available disk space: `df -h`
4. Clear model cache:
   ```bash
   rm -rf ~/Library/Application\ Support/Hex/Models
   ```
5. Retry download

### High CPU Usage

**Problem**: CPU maxed out, fans running loudly

**Expected Behavior**: This is normal during:
- First app launch (ANECompilerService optimizing model)
- Model download
- AI inference on first use

**Solution**: Let it complete (5-20 minutes typically)

### Voice Commands Not Recognized

**Problem**: Commands not understood or trigger wrong actions

**Solution**:
1. Check microphone input level: System Settings → Sound
2. Speak clearly and at normal pace
3. Try exact command phrasing from documentation
4. Check AI model is loaded and ready
5. View debug logs:
   ```bash
   log stream --predicate 'process == "Hex"' --level debug
   ```

### Search Not Working

**Problem**: Search commands fail or return no results

**Solution**:
1. Check internet connection
2. Verify search provider is configured
3. For Google/Bing: Verify API key is valid
4. Test with simpler query
5. Check rate limits on API provider

---

## 📚 Additional Resources

### Documentation
- **User Guide**: `docs/ai-assistant-usage.md` (1000+ lines)
- **Command Reference**: `docs/voice-commands-reference.md` (800+ lines)
- **Architecture**: `specs/001-local-ai-assistant/plan.md`
- **Requirements**: `specs/001-local-ai-assistant/spec.md`

### API & Client Docs
- **Hugging Face**: https://huggingface.co/docs
- **Apple Intelligence**: https://developer.apple.com/ai/
- **TCA Documentation**: https://pointfreeco.gitbook.io/swift-composable-architecture

### Community
- **Discord**: https://discord.gg/5UzVCqWmav
- **GitHub Issues**: Report bugs or request features
- **GitHub Discussions**: Ask questions and share ideas

---

## 🚀 Next Steps After Setup

1. **Explore Features**:
   - Try voice system control (open apps, manage windows)
   - Test information search (web and local files)
   - Play with productivity tools (timers, calculator, notes)

2. **Customize**:
   - Configure your preferred hotkey
   - Select AI model that fits your needs
   - Set up search providers

3. **Develop** (if contributing):
   - Read `specs/001-local-ai-assistant/tasks.md` for implementation details
   - Review TCA patterns in existing features
   - Check `Hex/Features/AIAssistant/CodeCleanupGuide.swift` for code standards
   - Run tests: `⌘ + U`

4. **Report Issues**:
   - Found a bug? Open GitHub issue with:
     - macOS version
     - Xcode version
     - Steps to reproduce
     - Console logs (from Console.app)

---

## 📊 Project Status

**✅ Implementation**: COMPLETE (73/73 tasks)
- Phase 1-2: Foundation & Infrastructure
- Phase 3: Voice System Control
- Phase 4: AI Model Management  
- Phase 5: Information Search
- Phase 6: Productivity Tools
- Phase 7: Integration & Polish

**✅ Testing**: COMPREHENSIVE
- 40+ test cases
- Integration tests across all features
- Success criteria validation

**✅ Documentation**: EXTENSIVE
- 1000+ lines user guide
- 800+ lines command reference
- Comprehensive code documentation

---

## 💡 Tips for Best Results

1. **Use Apple Silicon Mac**: Best performance, native support
2. **Download Mistral 7B First**: Balanced performance/quality
3. **Use in Quiet Environment**: Better voice recognition
4. **Speak Clearly**: At normal pace, complete sentences
5. **Keep Internet Connected**: For web search and model downloads
6. **Monitor First Launch**: ANECompilerService optimization can take time
7. **Check Logs When Issues Occur**: `log stream --predicate 'process == "Hex"'`

---

**Questions?** Check the [Discord community](https://discord.gg/5UzVCqWmav) or open a GitHub issue!

**Last Updated**: November 2025
**Version**: 1.0 - Local AI Assistant (Production Ready)
