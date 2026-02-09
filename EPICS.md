# Hex Voice - Implementation Epics & User Stories

## Overview
Complete implementation plan for building a macOS voice-to-text menu bar application from scratch using Tauri + Rust.

---

## Epic 1: Project Setup & Infrastructure

**Goal**: Initialize Tauri project with all dependencies, build tooling, and CI/CD.

### Stories

| ID | Story | Description | Acceptance Criteria |
|----|-------|-------------|---------------------|
| 1.1 | Initialize Tauri project | Create new Tauri 2.0 project with React + TypeScript | - Project builds with `npm run tauri dev`<br>- TypeScript configured<br>- Hot reload works |
| 1.2 | Configure build tools | Set up Vite, Tailwind CSS, and build pipeline | - Production build succeeds<br>- CSS bundles correctly<br>- Source maps enabled |
| 1.3 | Add Rust dependencies | Install cpal, arboard, async-openai, tokio, serde | - Cargo.toml updated<br>- `cargo check` passes<br>- All dependencies compile |
| 1.4 | Add Tauri plugins | Install global-shortcut, store, dialog, fs, shell, log | - All plugins registered in lib.rs<br>- Plugin permissions configured |
| 1.5 | Set up project structure | Create folder structure for modules | - src-tauri/src/ with modules<br>- src/ with components, hooks, stores, types<br>- Documentation in place |
| 1.6 | Configure code signing | Set up macOS code signing and notarization | - Development signing works<br>- Entitlements configured |
| 1.7 | Add frontend dependencies | Install zustand, lucide-react, @tanstack/react-query | - All packages installed<br>- Type definitions available |

**Definition of Done**: Tauri app builds, runs in dev mode, and displays a basic UI.

---

## Epic 2: Menu Bar Integration

**Goal**: Run as a macOS menu bar app with tray icon and popover UI.

### Stories

| ID | Story | Description | Acceptance Criteria |
|----|-------|-------------|---------------------|
| 2.1 | Add tray-icon plugin | Integrate Tauri tray-icon for menu bar | - Tray icon visible in menu bar<br>- Icon shows app status |
| 2.2 | Hide main window | Configure window to be hidden/skip taskbar | - No dock icon (configurable)<br>- Window hidden on launch |
| 2.3 | Create tray menu | Build menu bar dropdown menu | - Menu shows on icon click<br>- Menu items: Record, Settings, History, Quit |
| 2.4 | Create popover UI | Build popover window for quick actions | - Popover appears on tray icon click<br>- Popover closes on blur |
| 2.5 | Add status indicator | Visual indicator in menu bar | - Idle: icon only<br>- Recording: pulsing red<br>- Transcribing: blue |
| 2.6 | Design app icons | Create menu bar icon assets | - 16x16, 32x32, 64x64 variants<br>- Light/dark mode support |

**Definition of Done**: App runs as menu bar only, with functional tray menu and status indicators.

---

## Epic 3: Audio Recording

**Goal**: Capture audio from microphone with real-time feedback.

### Stories

| ID | Story | Description | Acceptance Criteria |
|----|-------|-------------|---------------------|
| 3.1 | List audio devices | Enumerate available microphones | - Returns list of input devices<br>- Shows device names and IDs<br>- Handles no devices gracefully |
| 3.2 | Select audio device | Allow user to choose microphone | - Device selection persists<br>- Falls back to default if device missing |
| 3.3 | Start audio stream | Begin capturing audio with cpal | - Stream starts without errors<br>- Uses correct sample rate (16kHz)<br>- Mono channel |
| 3.4 | Record to buffer | Capture audio data in memory | - Audio data stored as PCM/WAV<br>- Buffer grows as recording continues<br>- Memory usage monitored |
| 3.5 | Stop recording | End capture and return audio data | - Stream closed cleanly<br>- Returns complete audio buffer<br>- Handles early stop |
| 3.6 | Real-time audio metering | Display audio level visualization | - Meter updates in real-time<br>- Shows dB level<br>- Visual feedback in UI |
| 3.7 | Audio format conversion | Convert raw audio to WAV format | - WAV header correctly written<br>- Compatible with transcription engines<br>- Sample rate conversion if needed |
| 3.8 | VAD (Voice Activity Detection) | Detect when user is speaking | - Identifies speech vs silence<br>- Optional auto-stop on silence<br>- Configurable sensitivity |

**Definition of Done**: Can record audio from any microphone, with visual feedback, and output WAV format.

---

## Epic 4: Speech Recognition

**Goal**: Transcribe audio using on-device ML models.

### Stories

| ID | Story | Description | Acceptance Criteria |
|----|-------|-------------|---------------------|
| 4.1 | Choose transcription engine | Evaluate and select whisper.cpp vs Sherpa-ONNX | - Decision documented<br>- FFI strategy defined |
| 4.2 | Add whisper.cpp bindings | Integrate whisper.cpp via FFI or crate | - whisper.cpp compiles for Apple Silicon<br>- Basic transcription works |
| 4.3 | Model management - download | Download models from remote source | - Progress bar shown<br>- Models stored in app support folder<br>- Resume interrupted downloads |
| 4.4 | Model management - list | Show available and downloaded models | - Curated list: Parakeet TDT v2/v3, Whisper sizes<br>- Shows download status<br>- Model size displayed |
| 4.5 | Model management - delete | Remove unused models | - Delete from disk<br>- Updates availability<br>- Frees disk space |
| 4.6 | Load model | Load selected model into memory | - Model loads successfully<br>- Memory usage tracked<br>- Error handling for corrupt models |
| 4.7 | Transcribe audio | Convert audio buffer to text | - Returns transcription text<br>- Includes confidence scores<br>- Handles edge cases (silence, noise) |
| 4.8 | Language support | Support 60+ languages | - Auto-detect language option<br>- Manual language selection<br>- Language stored in settings |
| 4.9 | Transcription progress | Show progress during long transcriptions | - Progress indicator in UI<br>- Estimated time remaining<br>- Cancellation support |
| 4.10 | CoreML acceleration | Use Apple Neural Engine for faster inference | - Models use CoreML when available<br>- Fallback to CPU<br>- Performance comparison documented |

**Definition of Done**: Can transcribe audio to text with configurable models and languages.

---

## Epic 5: Global Hotkeys

**Goal**: Register and respond to global keyboard shortcuts.

### Stories

| ID | Story | Description | Acceptance Criteria |
|----|-------|-------------|---------------------|
| 5.1 | Register hotkey | Use Tauri global-shortcut plugin | - Hotkey registered system-wide<br>- Works when app not focused |
| 5.2 | Press-and-hold mode | Record while holding hotkey | - Recording starts on press<br>- Recording stops on release<br>- Minimum duration enforcement |
| 5.3 | Double-tap mode | Toggle recording with double-tap | - Double-tap detected<br>- Toggle on/off<br>- Configurable tap timeout |
| 5.4 | Modifier-only hotkeys | Support single modifier keys (Option, Cmd) | - Option key works as hotkey<br>- 0.3s threshold to prevent accidents<br>- Configurable threshold |
| 5.5 | Escape cancellation | Stop recording with Escape key | - Escape key stops recording<br>- Works during transcription<br>- Confirmation UI (optional) |
| 5.6 | "Force quit" voice command | Emergency stop with voice | - Listens for "force quit hex now"<br>- Stops all operations<br>- Visual feedback |
| 5.7 | Hotkey configuration UI | Allow users to customize hotkeys | - Record hotkey in UI<br>- Shows current hotkey<br>- Validates combinations |
| 5.8 | Modifier side selection | Choose left/right/either for modifiers | - Left Option, Right Option, or Either<br>- Persisted in settings |
| 5.9 | Paste last transcript hotkey | Separate hotkey for re-pasting | - Registered independently<br>- Pastes last transcription<br>- Shows which transcript |
| 5.10 | Refinement hotkey | Trigger text refinement | - Separate hotkey for refinement<br>- Works with selected text<br>- Indicates refinement in progress |

**Definition of Done**: Global hotkeys work for recording, stopping, and special actions.

---

## Epic 6: Text Injection & Clipboard

**Goal**: Insert transcribed text into active applications.

### Stories

| ID | Story | Description | Acceptance Criteria |
|----|-------|-------------|---------------------|
| 6.1 | Detect active application | Find which app is currently focused | - Returns app name and bundle ID<br>- Updates when focus changes<br>- Handles no active app |
| 6.2 | Copy to clipboard | Place text in system clipboard | - Text copied via arboard<br>- Works with all text formats<br>- Error handling |
| 6.3 | Paste via clipboard | Trigger Cmd+V programmatically | - Simulates Cmd+V keypress<br>- Uses CGEvent API on macOS<br>- Respects user setting |
| 6.4 | Paste via keypress simulation | Type text character by character | - Fallback for apps that don't accept paste<br>- Configurable typing speed<br>- Handles special characters |
| 6.5 | Insertion mode setting | Let users choose insertion method | - "Clipboard" (fast)<br>- "Keypress simulation" (compatible)<br>- Setting persists |
| 6.6 | Copy only mode | Copy without pasting | - Optional setting<br>- Notification when copied<br>- User pastes manually |
| 6.7 | Paste last transcript | Re-paste previous transcription | - Separate hotkey<br>- Shows which transcript<br>- From history |

**Definition of Done**: Transcribed text appears in the active application.

---

## Epic 7: LLM Text Refinement

**Goal**: Improve transcriptions using OpenAI API.

### Stories

| ID | Story | Description | Acceptance Criteria |
|----|-------|-------------|---------------------|
| 7.1 | API key storage | Securely store OpenAI API key | - Encrypted storage in keychain<br>- Input field in settings<br>- Validation on save |
| 7.2 | Configure OpenAI client | Set up async-openai with base URL | - Default: api.openai.com<br>- Custom base URL supported<br>- Model selection |
| 7.3 | Refinement prompt | Create system prompt for grammar | - Preserves original meaning<br>- Improves clarity and grammar<br>- Concise output |
| 7.4 | Auto-refine toggle | Setting to enable auto-refinement | - Toggle in settings<br>- Applies to all transcriptions<br>- Shows when refining |
| 7.5 | Manual refinement | Refine on-demand with hotkey | - Captures selected text<br>- Replaces in place<br>- Shows refinement status |
| 7.6 | Model selection | Choose GPT model | - GPT-4o-mini (default)<br>- GPT-4o<br>- GPT-4.1<br>- Custom model name |
| 7.7 | Temperature control | Adjust creativity/precision | - Slider 0-1<br>- Lower = more precise<br>- Persisted in settings |
| 7.8 | Max tokens control | Limit output length | - Range 64-4096<br>- Default 512<br>- Prevents truncation |
| 7.9 | Fallback behavior | Handle API errors gracefully | - Shows error to user<br>- Falls back to original text<br>- Retry option |
| 7.10 | Refinement indicator | Visual feedback during refinement | - Status icon changes<br>- Progress indicator<br>- Notification on complete |

**Definition of Done**: Can refine text using OpenAI API with configurable options.

---

## Epic 8: Settings & Preferences

**Goal**: Comprehensive settings UI and persistence.

### Stories

| ID | Story | Description | Acceptance Criteria |
|----|-------|-------------|---------------------|
| 8.1 | Settings UI structure | Create settings interface | - Grouped by category<br>- Search functionality<br>- Clean, organized layout |
| 8.2 | Hotkey settings | Configure all hotkeys | - Recording hotkey<br>- Paste last hotkey<br>- Refinement hotkey<br>- Modifier side selection |
| 8.3 | Microphone settings | Audio device selection | - Device picker<br>- Test microphone button<br>- Level meter |
| 8.4 | Model settings | Transcription model selection | - Model list with descriptions<br>- Download progress<br>- Delete button<br>- "Show in Finder" |
| 8.5 | Language settings | Output language selection | - 60+ languages<br>- Auto-detect option<br>- Flag icons |
| 8.6 | Refinement settings | LLM configuration | - API key input<br>- Model selection<br>- Base URL<br>- Temperature, max tokens |
| 8.7 | Audio behavior settings | Sound and sleep options | - Sound effects toggle<br>- Volume slider<br>- Prevent sleep toggle<br>- Media pause/mute/do nothing |
| 8.8 | General settings | App-wide preferences | - Open on login<br>- Show dock icon<br>- Use clipboard to insert |
| 8.9 | Word transformations | Remove and remap words | - Removal patterns (regex)<br>- Word remappings<br>- Enable/disable per item<br>- Live preview |
| 8.10 | History settings | Transcription history options | - Save history toggle<br>- Max entries dropdown<br>- Clear all button |
| 8.11 | Settings persistence | Save and load settings | - Uses Tauri store plugin<br>- Survives app restarts<br>- Migration strategy |
| 8.12 | Reset to defaults | Restore default settings | - Button in settings<br>- Confirmation dialog<br>- Resets all options |

**Definition of Done**: All PRD settings configurable and persistent.

---

## Epic 9: Transcription History

**Goal**: Store, view, and manage past transcriptions.

### Stories

| ID | Story | Description | Acceptance Criteria |
|----|-------|-------------|---------------------|
| 9.1 | History storage | Save transcriptions to disk | - JSON file storage<br>- Includes text, timestamp, duration<br>- Audio file reference |
| 9.2 | History list UI | Display transcriptions | - Chronological list<br>- Shows preview text<br>- Timestamp and duration |
| 9.3 | Audio playback | Play original recordings | - Play/pause button<br>- Seek bar<br>- Volume control |
| 9.4 | Copy from history | Copy transcript to clipboard | - Copy button on each entry<br>- Visual feedback<br>- Notification |
| 9.5 | Delete entries | Remove individual entries | - Delete button with confirmation<br>- Updates list<br>- Removes audio file |
| 9.6 | Clear all history | Remove all transcriptions | - Button in settings<br>- Double confirmation<br>- Empties storage |
| 9.7 | Source app tracking | Show which app received text | - Displays app icon<br>- App name in list<br>- Filter by app |
| 9.8 | Timestamp display | Show when transcription occurred | - Relative time ("2 hours ago")<br>- Absolute time on hover<br>- Local timezone |
| 9.9 | Duration display | Show length of recording | - Duration in list<br>- Detailed view on click |
| 9.10 | Automatic cleanup | Remove old entries when limit reached | - Deletes oldest first<br>- Respects max entries setting<br>- Warning before cleanup |
| 9.11 | Configurable limit | Set maximum history entries | - Dropdown: unlimited, 50, 100, 200, 500, 1000<br>- Applied immediately |
| 9.12 | History toggle | Turn history on/off | - Setting to disable<br>- Clarifies data not saved<br>- Confirmation on enable |

**Definition of Done**: Full history management with playback and cleanup.

---

## Epic 10: Permissions

**Goal**: Request and manage macOS permissions.

### Stories

| ID | Story | Description | Acceptance Criteria |
|----|-------|-------------|---------------------|
| 10.1 | Microphone permission | Request audio recording permission | - Shows system prompt<br>- Guides user to Settings if denied<br>- Retries on grant |
| 10.2 | Accessibility permission | Request accessibility for text injection | - Explains why needed<br>- Opens System Preferences<br>- Detects when granted |
| 10.3 | Input monitoring permission | Request input monitoring for hotkeys | - Shows system prompt<br>- Guides user to Settings<br>- Required for global hotkeys |
| 10.4 | Permission status indicators | Show granted/denied status | - Visual indicator in settings<br>- Red if denied, green if granted<br>- Explanatory text |
| 10.5 | Permission requests on first launch | Guide user through setup | - Onboarding flow<br>- Request all permissions<br>- Can't proceed until granted |
| 10.6 | Recheck permissions | Verify permissions on launch | - Check on app start<br>- Notify if revoked<br>- Prompt to regrant |
| 10.7 | Help links | Link to Apple documentation | - "Learn more" links<br>- Explains each permission<br>- Troubleshooting tips |

**Definition of Done**: All permissions requested with clear UX and status tracking.

---

## Epic 11: Auto-Updates

**Goal**: Automatic app updates using Tauri updater.

### Stories

| ID | Story | Description | Acceptance Criteria |
|----|-------|-------------|---------------------|
| 11.1 | Configure updater | Set up Tauri updater plugin | - Update server configured<br>- Update interval set<br>- Check on launch |
| 11.2 | Update notification | Show user when update available | - In-app notification<br>- Shows version number<br>- Release notes link |
| 11.3 | Download and install | Automatic update flow | - Download progress<br>- Install on quit<br>- Restart app |
| 11.4 | Changelog view | Display version history | - Changelog screen<br>- Shows recent versions<br>- Links to full changelog |
| 11.5 | About view | App information | - Version number<br>- Build info<br>- License info<br>- Credits |

**Definition of Done**: App updates automatically with user notification.

---

## Epic 12: Sound Effects

**Goal**: Audio feedback for user actions.

### Stories

| ID | Story | Description | Acceptance Criteria |
|----|-------|-------------|---------------------|
| 12.1 | Sound file management | Store and load sound files | - Sounds in Resources/Audio/<br>- Start recording sound<br>- Stop recording sound<br>- Success sound<br>- Error sound |
| 12.2 | Play sound effects | Trigger sounds on events | - On recording start<br>- On recording stop<br>- On transcription complete<br>- On error |
| 12.3 | Volume control | Adjust sound effect volume | - Slider 0-100%<br>- Real-time preview<br>- Persisted setting |
| 12.4 | Toggle on/off | Enable/disable sounds | - Setting in preferences<br>- Applies immediately |
| 12.5 | Custom sounds | Allow users to add custom sounds | - File picker<br>- Validates audio format<br>- Per-sound customization |

**Definition of Done**: Audio feedback for all key events, configurable by user.

---

## Epic 13: Word Transformations

**Goal**: Post-processing to remove or replace words.

### Stories

| ID | Story | Description | Acceptance Criteria |
|----|-------|-------------|---------------------|
| 13.1 | Word removals | Regex-based word removal | - Case-insensitive matching<br>- Whole-word option<br>- Multiple patterns |
| 13.2 | Word remappings | Replace words with alternatives | - Exact word matching<br>- Ordered application<br>- Special character support (\n, \t) |
| 13.3 | Enable/disable per item | Toggle individual transformations | - Checkbox per item<br>- Applied when enabled<br>- Preview shows effect |
| 13.4 | Live preview scratchpad | Test transformations | - Input field<br>- Shows output in real-time<br>- Clear visual indication |
| 13.5 | Transformation UI | Settings screen for transformations | - Separate tab<br>- Add/remove items<br>- Type indicator (removal/remapping) |
| 13.6 | Apply to transcriptions | Process transcription text | - Runs after transcription<br>- Before refinement<br>- Shows in transcript |
| 13.7 | Import/export transformations | Backup and share | - Export to JSON<br>- Import from file<br>- Validation |

**Definition of Done**: Powerful text transformation system for common speech recognition issues.

---

## Epic 14: Polish & UX

**Goal**: Refine user experience and visual design.

### Stories

| ID | Story | Description | Acceptance Criteria |
|----|-------|-------------|---------------------|
| 14.1 | Design system | Establish visual language | - Color palette<br>- Typography<br>- Component library<br>- Spacing system |
| 14.2 | Animations | Smooth transitions | - Recording indicator pulse<br>- Loading spinners<br>- Slide-in menus<br>- Button hover states |
| 14.3 | Dark mode support | Adapt to system theme | - Follows macOS appearance<br>- Manual override option<br>- All components themed |
| 14.4 | Keyboard navigation | Full keyboard control | - Tab through UI<br>- Enter to activate<br>- Escape to dismiss<br>- Arrow keys in lists |
| 14.5 | Tooltips | Helpful hints on hover | - Show on hover<br>- Dismissible<br>- Context-aware |
| 14.6 | Empty states | Guide users when no data | - No history message<br>- No models message<br>- Call-to-action |
| 14.7 | Loading states | Indicate async operations | - Progress bars<br>- Spinners<br>- Skeleton screens |
| 14.8 | Error handling | Graceful error display | - User-friendly messages<br>- Recovery options<br>- Error reporting |
| 14.9 | Notifications | System notifications for events | - Recording started<br>- Transcription complete<br>- Update available<br>- Errors |
| 14.10 | Performance optimization | Ensure smooth operation | - <100ms response time<br>- Efficient rendering<br>- Memory profiling |

**Definition of Done**: Polished, professional user experience.

---

## Epic 15: Testing & Quality Assurance

**Goal**: Comprehensive test coverage.

### Stories

| ID | Story | Description | Acceptance Criteria |
|----|-------|-------------|---------------------|
| 15.1 | Unit tests - Rust | Test backend logic | - Audio module tests<br>- Clipboard tests<br>- Store tests<br>- >80% coverage |
| 15.2 | Unit tests - TypeScript | Test frontend logic | - Component tests<br>- Hook tests<br>- Store tests<br>- >80% coverage |
| 15.3 | Integration tests | Test module interactions | - Recording to transcription<br>- Hotkey to action<br>- Settings persistence |
| 15.4 | E2E tests | Test user flows | - Record and transcribe<br>- Refine text<br>- View history<br>- Change settings |
| 15.5 | Manual testing checklist | Document test scenarios | - All features covered<br>- Reproducible steps<br>- Expected results |
| 15.6 | Accessibility testing | Ensure VoiceOver support | - All labels read<br>- Keyboard navigation<br>- Contrast ratios |
| 15.7 | Performance testing | Benchmark key operations | - Recording latency<br>- Transcription speed<br>- Memory usage<br>- Startup time |
| 15.8 | Crash reporting | Collect and report crashes | - Sentry integration<br>- Stack traces<br>- User context |

**Definition of Done**: Comprehensive test coverage with automated and manual tests.

---

## Epic 16: Documentation

**Goal**: Complete documentation for users and developers.

### Stories

| ID | Story | Description | Acceptance Criteria |
|----|-------|-------------|---------------------|
| 16.1 | README | Project overview and setup | - Description<br>- Installation<br>- Development<br>- Contributing |
| 16.2 | User guide | How to use the app | - Getting started<br>- Features explained<br>- Screenshots<br>- Troubleshooting |
| 16.3 | API documentation | Document Tauri commands | - All commands listed<br>- Parameters described<br>- Return types<br>- Examples |
| 16.4 | Architecture docs | Explain system design | - Module overview<br>- Data flow<br>- Technology choices<br>- Diagrams |
| 16.5 | Contributing guide | For external contributors | - Setup steps<br>- Code style<br>- PR process<br>- Community guidelines |
| 16.6 | Changelog | Version history | - Semantic versioning<br>- Release notes<br>- Migration guides |

**Definition of Done**: Complete documentation for all audiences.

---

## Summary

**Total Epics**: 16
**Total Stories**: ~165

### Implementation Order (Recommended)

| Phase | Epics | Duration |
|-------|-------|----------|
| **Foundation** | 1, 2 | Week 1 |
| **Core Recording** | 3, 5, 6 | Week 2-3 |
| **Transcription** | 4 | Week 4 |
| **AI Features** | 7 | Week 5 |
| **User Features** | 8, 9 | Week 6-7 |
| **System** | 10, 11 | Week 8 |
| **Polish** | 12, 13, 14 | Week 9-10 |
| **Quality** | 15, 16 | Week 11-12 |

**Estimated Total Duration**: 12 weeks for a single developer.
