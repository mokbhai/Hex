# Select Text Hotkey Feature - Simple Implementation Plan

## Overview

This document outlines a simplified implementation plan for a new "selectTextHotkey" feature in Hex that replaces selected text with "Hello world" when a dedicated hotkey is pressed.

## User Requirements

1. **New Hotkey Setting**: Add a "selectTextHotkey" configuration that's different from the existing voice hotkey
2. **Text Selection Detection**: When the hotkey is pressed, detect currently selected text on screen
3. **Text Replacement**: Replace selected text with "Hello world"
4. **Audio Feedback**: Play success/failure sounds using existing sound system
5. **Error Handling**: Handle cases where no text is selected or field is not editable

## Architecture Analysis - Reusing Existing Components

### Existing Components We Can Use

1. **KeyEventMonitorClient**: Already handles global hotkey monitoring
2. **HotKeyProcessor**: State machine for hotkey detection
3. **SoundEffectsClient**: Already has `pasteTranscript.mp3` and `cancel.mp3` sounds
4. **PasteboardClient**: Has text insertion capabilities via `insertTextAtCursor`
5. **HexSettings**: Already structured for hotkey configurations
6. **AppFeature**: Already has hotkey monitoring patterns we can follow

### Key Existing Functions to Leverage

- `SoundEffectsClient.play(.pasteTranscript)` - Success sound
- `SoundEffectsClient.play(.cancel)` - Failure sound
- `PasteboardClient.insertTextAtCursor("Hello world")` - Text replacement
- Existing hotkey monitoring in `AppFeature.swift`

## Minimal Implementation Plan

### Step 1: Add Select Text Hotkey Setting

**File**: `HexCore/Sources/HexCore/Settings/HexSettings.swift`

Add one new property:
```swift
public var selectTextHotkey: HotKey?
```

Add corresponding enum case and settings field support.

### Step 2: Add Hotkey Monitoring to AppFeature

**File**: `Hex/Features/App/AppFeature.swift`

Add new action:
```swift
enum Action {
    // ... existing actions
    case selectTextHotkeyPressed
}
```

Add monitoring similar to existing `pasteLastTranscriptHotkey`:
```swift
private func startSelectTextHotkeyMonitoring() -> Effect<Action> {
    .run { send in
        @Shared(.hexSettings) var hexSettings: HexSettings
        @Shared(.isSettingHotKey) var isSettingHotKey: Bool

        let token = keyEventMonitor.handleKeyEvent { keyEvent in
            // Skip if user is setting a hotkey
            if isSettingHotKey { return false }

            // Check if this matches our select text hotkey
            if let hotkey = hexSettings.selectTextHotkey,
               keyEvent.key == hotkey.key && keyEvent.modifiers.matchesExactly(hotkey.modifiers) {
                Task { await send(.selectTextHotkeyPressed) }
                return true // Intercept the key
            }
            return false
        }

        defer { token.cancel() }
        try await Task.sleep(nanoseconds: .max)
    }
}
```

Add to `onAppear` in `AppFeature` body.

### Step 3: Handle Select Text Action

**File**: `Hex/Features/App/AppFeature.swift`

Add case in reducer:
```swift
case .selectTextHotkeyPressed:
    return .run { send in
        do {
            // Try to replace selected text with "Hello world"
            try PasteboardClientLive.insertTextAtCursor("Hello world")
            // Success - play paste sound
            await soundEffects.play(.pasteTranscript)
        } catch {
            // Failed - no text selected or field not editable
            await soundEffects.play(.cancel)
        }
    }
```

### Step 4: Add Settings UI

**File**: `Hex/Features/Settings/SettingsView.swift`

Add simple hotkey configuration section:
```swift
// Add to existing form
Section("Select Text Hotkey") {
    HotKeyView(
        hotkey: $hexSettings.selectTextHotkey,
        isSettingHotKey: $isSettingHotKey
    )
}
```

### Step 5: Add Default Hotkey

**File**: `HexCore/Sources/HexCore/Settings/HexSettings.swift`

Add a default like:
```swift
public static let defaultSelectTextHotkey = HotKey(key: .f1, modifiers: [.control])
```

## Files to Modify

### Existing Files (5 files total)
1. **HexCore/Sources/HexCore/Settings/HexSettings.swift** - Add selectTextHotkey property
2. **Hex/Features/App/AppFeature.swift** - Add hotkey monitoring and action handling
3. **Hex/Features/Settings/SettingsView.swift** - Add hotkey configuration UI
4. **Hex/Features/Settings/SettingsFeature.swift** - Add settings actions if needed
5. **HexCore/Sources/HexCore/Constants.swift** - Add default hotkey constant

### No New Files Needed!

We can implement this entire feature using existing components and patterns.

## Implementation Details

### Text Selection Detection Strategy

We'll use the existing `PasteboardClientLive.insertTextAtCursor()` function which already:
- Gets the focused element using Accessibility APIs
- Checks if the element supports text editing
- Replaces selected text (or inserts at cursor if no selection)

### Error Handling

The `insertTextAtCursor()` function throws specific errors:
- `focusedElementNotFound` - No focused text field
- `elementDoesNotSupportTextEditing` - Field is not editable
- `failedToInsertText` - Insertion failed

We'll catch any of these and play the `cancel.mp3` sound.

### Sound Effects

Already available:
- `SoundEffect.pasteTranscript` - Uses `pasteTranscript.mp3`
- `SoundEffect.cancel` - Uses `cancel.mp3`

### Hotkey Monitoring Pattern

We'll follow the exact same pattern as the existing `pasteLastTranscriptHotkey`:
- Use `keyEventMonitor.handleKeyEvent`
- Check against `hexSettings.selectTextHotkey`
- Return `true` to intercept the key combination
- Handle the `isSettingHotKey` flag properly

## Testing Strategy

### Manual Testing
1. **Basic functionality**: Select text in TextEdit, press hotkey, should replace with "Hello world"
2. **No selection**: Place cursor in text field, press hotkey, should insert "Hello world"
3. **No focused field**: Press hotkey with no text field focused, should play cancel sound
4. **Non-editable field**: Try in read-only areas, should play cancel sound
5. **Settings**: Configure hotkey in settings, verify it works
6. **Hotkey conflicts**: Ensure no conflicts with existing hotkeys

### Apps to Test In
- TextEdit (basic text editing)
- Safari (web forms)
- VS Code (code editor)
- Notes (rich text)
- Terminal (command line)

## Potential Issues and Solutions

### Issue 1: Accessibility Permissions
**Solution**: Already handled by existing hotkey system - same permissions are required

### Issue 2: Some Apps Don't Support Accessibility Text Insertion
**Solution**: The existing `insertTextAtCursor()` function is designed to handle this gracefully with proper error throwing

### Issue 3: Hotkey Conflicts
**Solution**: Use a default hotkey that's unlikely to conflict (Control+F1) and allow user customization

## Benefits of This Approach

1. **Minimal Code Changes**: Only 5 existing files to modify
2. **Reuses Existing Infrastructure**: Hotkey monitoring, sound system, text insertion all exist
3. **Consistent with Existing Patterns**: Follows same architecture as paste last transcript feature
4. **No New Dependencies**: Uses existing system frameworks and permissions
5. **Low Risk**: Simple implementation with clear error handling

## Future Enhancements (Post-MVP)

- Add customizable replacement text
- Add support for multiple text replacements
- Add visual feedback when text is replaced
- Add text selection preview before replacement
- Support for different replacement modes (append, prepend, etc.)

## Conclusion

This simplified implementation leverages the existing Hex codebase to the maximum extent possible. By reusing the hotkey monitoring system, sound effects infrastructure, and text insertion capabilities, we can implement this feature with minimal code changes while maintaining consistency with the existing application architecture.