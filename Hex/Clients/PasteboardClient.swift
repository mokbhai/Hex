//
//  PasteboardClient.swift
//  Hex
//
//  Created by Kit Langton on 1/24/25.
//

import ComposableArchitecture
import Dependencies
import DependenciesMacros
import Foundation
import HexCore
import Sauce
import SwiftUI

private let pasteboardLogger = HexLog.pasteboard

@DependencyClient
struct PasteboardClient {
    var paste: @Sendable (String) async -> Void
    var copy: @Sendable (String) async -> Void
    var sendKeyboardCommand: @Sendable (KeyboardCommand) async -> Void
}

extension PasteboardClient: DependencyKey {
    static var liveValue: Self {
        let live = PasteboardClientLive()
        return .init(
            paste: { text in
                await live.paste(text: text)
            },
            copy: { text in
                await live.copy(text: text)
            },
            sendKeyboardCommand: { command in
                await live.sendKeyboardCommand(command)
            }
        )
    }
}

extension PasteboardClientLive {
    /// Robust text insertion that tries multiple approaches
    @MainActor
    func insertTextWithFallbacks(_ text: String) async -> Bool {
        // Method 1: Try Accessibility API directly
        do {
            let success = try Self.insertTextAtCursor(text)
            if success {
                pasteboardLogger.debug("Text insertion successful via Accessibility API")
                return true
            }
        } catch {
            pasteboardLogger.warning("Accessibility API failed: \(error)")
        }

        // Method 2: Try clipboard paste approach
        let pasteSuccess = await pasteWithClipboard(text)
        if pasteSuccess {
            pasteboardLogger.debug("Text insertion successful via clipboard paste")
            return true
        }
        pasteboardLogger.debug("Clipboard paste approach failed")

        // Method 3: Try AppleScript typing simulation with verification
        let typingSuccess = await simulateTypingWithAppleScript(text)
        if typingSuccess {
            pasteboardLogger.debug("Text insertion successful via AppleScript typing")
            return true
        }
        pasteboardLogger.debug("AppleScript typing approach failed")

        return false // All methods failed
    }
}

extension DependencyValues {
    var pasteboard: PasteboardClient {
        get { self[PasteboardClient.self] }
        set { self[PasteboardClient.self] = newValue }
    }
}

struct PasteboardClientLive {
    @Shared(.hexSettings) var hexSettings: HexSettings

    @MainActor
    func paste(text: String) async {
        if hexSettings.useClipboardPaste {
            await pasteWithClipboard(text)
        } else {
            _ = await simulateTypingWithAppleScript(text)
        }
    }
    
    @MainActor
    func copy(text: String) async {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    @MainActor
    func sendKeyboardCommand(_ command: KeyboardCommand) async {
        let source = CGEventSource(stateID: .combinedSessionState)
        
        // Convert modifiers to CGEventFlags and key codes for modifier keys
        var modifierKeyCodes: [CGKeyCode] = []
        var flags = CGEventFlags()
        
        for modifier in command.modifiers.sorted {
            switch modifier.kind {
            case .command:
                flags.insert(.maskCommand)
                modifierKeyCodes.append(55) // Left Cmd
            case .shift:
                flags.insert(.maskShift)
                modifierKeyCodes.append(56) // Left Shift
            case .option:
                flags.insert(.maskAlternate)
                modifierKeyCodes.append(58) // Left Option
            case .control:
                flags.insert(.maskControl)
                modifierKeyCodes.append(59) // Left Control
            case .fn:
                flags.insert(.maskSecondaryFn)
                // Fn key doesn't need explicit key down/up
            }
        }
        
        // Press modifiers down
        for keyCode in modifierKeyCodes {
            let modDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
            modDown?.post(tap: .cghidEventTap)
        }
        
        // Press main key if present
        if let key = command.key {
            let keyCode = Sauce.shared.keyCode(for: key)
            
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
            keyDown?.flags = flags
            keyDown?.post(tap: .cghidEventTap)
            
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
            keyUp?.flags = flags
            keyUp?.post(tap: .cghidEventTap)
        }
        
        // Release modifiers in reverse order
        for keyCode in modifierKeyCodes.reversed() {
            let modUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
            modUp?.post(tap: .cghidEventTap)
        }
        
        pasteboardLogger.debug("Sent keyboard command: \(command.displayName)")
    }

    // Function to save the current state of the NSPasteboard
    func savePasteboardState(pasteboard: NSPasteboard) -> [[String: Any]] {
        var savedItems: [[String: Any]] = []
        
        for item in pasteboard.pasteboardItems ?? [] {
            var itemDict: [String: Any] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    itemDict[type.rawValue] = data
                }
            }
            savedItems.append(itemDict)
        }
        
        return savedItems
    }

    // Function to restore the saved state of the NSPasteboard
    func restorePasteboardState(pasteboard: NSPasteboard, savedItems: [[String: Any]]) {
        pasteboard.clearContents()
        
        for itemDict in savedItems {
            let item = NSPasteboardItem()
            for (type, data) in itemDict {
                if let data = data as? Data {
                    item.setData(data, forType: NSPasteboard.PasteboardType(rawValue: type))
                }
            }
            pasteboard.writeObjects([item])
        }
    }

    /// Pastes current clipboard content to the frontmost application
    static func pasteToFrontmostApp() -> Bool {
        let script = """
        if application "System Events" is not running then
            tell application "System Events" to launch
            delay 0.1
        end if
        tell application "System Events"
            tell process (name of first application process whose frontmost is true)
                tell (menu item "Paste" of menu of menu item "Paste" of menu "Edit" of menu bar item "Edit" of menu bar 1)
                    if exists then
                        log (get properties of it)
                        if enabled then
                            click it
                            return true
                        else
                            return false
                        end if
                    end if
                end tell
                tell (menu item "Paste" of menu "Edit" of menu bar item "Edit" of menu bar 1)
                    if exists then
                        if enabled then
                            click it
                            return true
                        else
                            return false
                        end if
                    else
                        return false
                    end if
                end tell
            end tell
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let result = scriptObject.executeAndReturnError(&error)
            if let error = error {
                pasteboardLogger.error("AppleScript paste failed: \(error)")
                return false
            }
            return result.booleanValue
        }
        return false
    }

    @MainActor
    func pasteWithClipboard(_ text: String) async -> Bool {
        let pasteboard = NSPasteboard.general
        let originalItems = savePasteboardState(pasteboard: pasteboard)
        let targetChangeCount = writeAndTrackChangeCount(pasteboard: pasteboard, text: text)
        _ = await waitForPasteboardCommit(targetChangeCount: targetChangeCount)
        let pasteSucceeded = await tryPaste(text)

        // Only restore original pasteboard contents if:
        // 1. Copying to clipboard is disabled AND
        // 2. The paste operation succeeded
        if !hexSettings.copyToClipboard && pasteSucceeded {
            let savedItems = originalItems
            Task { @MainActor in
                // Give slower apps (e.g., Claude, Warp) a short window to read the plain-text entry
                // before we repopulate the clipboard with the user's previous rich data.
                try? await Task.sleep(for: .milliseconds(500))
                pasteboard.clearContents()
                restorePasteboardState(pasteboard: pasteboard, savedItems: savedItems)
            }
        }

        // If we failed to paste AND user doesn't want clipboard retention,
        // show a notification that text is available in clipboard
        if !pasteSucceeded && !hexSettings.copyToClipboard {
            // Keep the transcribed text in clipboard regardless of setting
            pasteboardLogger.notice("Paste operation failed; text remains in clipboard as fallback.")

            // TODO: Could add a notification here to inform user
            // that text is available in clipboard
        }

        return pasteSucceeded
    }

    @MainActor
    private func writeAndTrackChangeCount(pasteboard: NSPasteboard, text: String) -> Int {
        let before = pasteboard.changeCount
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let after = pasteboard.changeCount
        if after == before {
            // Ensure we always advance by at least one to avoid infinite waits if the system
            // coalesces writes (seen on Sonoma betas with zero-length strings).
            return after + 1
        }
        return after
    }

    @MainActor
    private func waitForPasteboardCommit(
        targetChangeCount: Int,
        timeout: Duration = .milliseconds(150),
        pollInterval: Duration = .milliseconds(5)
    ) async -> Bool {
        guard targetChangeCount > NSPasteboard.general.changeCount else { return true }

        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if NSPasteboard.general.changeCount >= targetChangeCount {
                return true
            }
            try? await Task.sleep(for: pollInterval)
        }
        return false
    }

    // MARK: - Paste Orchestration

    @MainActor
    private func tryPaste(_ text: String) async -> Bool {
        // 1) Fast path: send Cmd+V (no delay)
        if await postCmdV(delayMs: 0) { return true }
        // 2) Menu fallback (quiet failure)
        if PasteboardClientLive.pasteToFrontmostApp() { return true }
        // 3) AX insert fallback
        if (try? Self.insertTextAtCursor(text)) != nil { return true }
        return false
    }

    // MARK: - Helpers

    @MainActor
    private func postCmdV(delayMs: Int) async -> Bool {
        // Optional tiny wait before keystrokes
        try? await wait(milliseconds: delayMs)
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey = vKeyCode()
        let cmdKey: CGKeyCode = 55
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: cmdKey, keyDown: true)
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        vDown?.flags = .maskCommand
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        vUp?.flags = .maskCommand
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: cmdKey, keyDown: false)
        cmdDown?.post(tap: .cghidEventTap)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
        return true
    }

    @MainActor
    private func vKeyCode() -> CGKeyCode {
        if Thread.isMainThread { return Sauce.shared.keyCode(for: .v) }
        return DispatchQueue.main.sync { Sauce.shared.keyCode(for: .v) }
    }

    @MainActor
    private func wait(milliseconds: Int) async throws {
        try Task.checkCancellation()
        try await Task.sleep(nanoseconds: UInt64(milliseconds) * 1_000_000)
    }
    
    @MainActor
    func simulateTypingWithAppleScript(_ text: String) async -> Bool {
        let escapedText = text.replacingOccurrences(of: "\"", with: "\\\"")
        let script = NSAppleScript(source: "tell application \"System Events\" to keystroke \"\(escapedText)\"")
        var error: NSDictionary?
        _ = script?.executeAndReturnError(&error)

        if let error = error {
            pasteboardLogger.error("Error executing AppleScript typing fallback: \(error)")
            return false
        }

        // Verify the text was actually typed by checking if it appears in the focused element
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElementRef: CFTypeRef?
        let axError = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElementRef)

        guard axError == .success, let focusedElementRef = focusedElementRef else {
            pasteboardLogger.warning("Could not verify AppleScript typing - no focused element")
            return true // Assume success since AppleScript executed without error
        }

        let focusedElement = focusedElementRef as! AXUIElement
        var value: CFTypeRef?

        // Try to get the text content and see if it contains our typed text
        if AXUIElementCopyAttributeValue(focusedElement, kAXValueAttribute as CFString, &value) == .success {
            // Small delay to allow the typing to register
            try? await Task.sleep(for: .milliseconds(100))

            // Check again after delay
            if AXUIElementCopyAttributeValue(focusedElement, kAXValueAttribute as CFString, &value) == .success,
               let updatedText = value as? String {
                if updatedText.contains(text) {
                    pasteboardLogger.debug("AppleScript typing verified - text found in focused element")
                    return true
                } else {
                    pasteboardLogger.warning("AppleScript typing may have failed - text not found")
                    return false
                }
            }
        }

        // If we can't verify, assume success since the AppleScript executed
        return true
    }

    enum PasteError: Error {
        case systemWideElementCreationFailed
        case focusedElementNotFound
        case elementDoesNotSupportTextEditing
        case failedToInsertText
    }
    
    static func insertTextAtCursor(_ text: String) throws -> Bool {
        pasteboardLogger.debug("Attempting to insert text at cursor: \(text, privacy: .private)")

        // Get the system-wide accessibility element
        let systemWideElement = AXUIElementCreateSystemWide()

        // Get the focused element
        var focusedElementRef: CFTypeRef?
        let axError = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElementRef)

        guard axError == .success, let focusedElementRef = focusedElementRef else {
            pasteboardLogger.error("Failed to get focused UI element: \(axError.rawValue)")
            throw PasteError.focusedElementNotFound
        }

        let focusedElement = focusedElementRef as! AXUIElement

        // Get element information for debugging
        var role: CFTypeRef?
        var title: CFTypeRef?
        var identifier: CFTypeRef?
        AXUIElementCopyAttributeValue(focusedElement, kAXRoleAttribute as CFString, &role)
        AXUIElementCopyAttributeValue(focusedElement, kAXTitleAttribute as CFString, &title)
        AXUIElementCopyAttributeValue(focusedElement, kAXIdentifierAttribute as CFString, &identifier)

        let roleString = role as? String ?? "unknown"
        let titleString = title as? String ?? "none"
        let identifierString = identifier as? String ?? "none"
        pasteboardLogger.debug("Focused element - Role: \(roleString), Title: \(titleString), Identifier: \(identifierString)")

        // Get any selected text before replacement
        var selectedText: String = ""
        var selectedRange: CFTypeRef?
        var value: CFTypeRef?

        // First get the selected range
        if AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextRangeAttribute as CFString, &selectedRange) == .success,
           CFGetTypeID(selectedRange) == AXValueGetTypeID() {
            let rangeValue = selectedRange as! AXValue
            var cfRange: CFRange = CFRange(location: 0, length: 0)
            if AXValueGetValue(rangeValue, .cfRange, &cfRange) {
                // Extract selected text using the range
                if AXUIElementCopyAttributeValue(focusedElement, kAXValueAttribute as CFString, &value) == .success,
                   let fullText = value as? String {
                    let startIndex = fullText.index(fullText.startIndex, offsetBy: min(cfRange.location, fullText.count))
                    let endIndex = fullText.index(startIndex, offsetBy: min(cfRange.length, fullText.distance(from: startIndex, to: fullText.endIndex)))
                    selectedText = String(fullText[startIndex..<endIndex])
                    pasteboardLogger.debug("Current selected text range: \(cfRange.location)-\(cfRange.location + cfRange.length), text: '\(selectedText, privacy: .private)'")
                }
            }
        }

        // Verify if the focused element supports text editing
        let supportsText = AXUIElementCopyAttributeValue(focusedElement, kAXValueAttribute as CFString, &value) == .success
        let supportsSelectedText = AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextRangeAttribute as CFString, &selectedRange) == .success

        if !supportsText && !supportsSelectedText {
            pasteboardLogger.warning("Element does not support text editing - Role: \(roleString)")
            throw PasteError.elementDoesNotSupportTextEditing
        }

        // Method 1: Try to replace selected text using keyboard simulation via Accessibility
        // This is more reliable than trying to set attributes directly
        if supportsSelectedText || selectedText.count > 0 {
            // For apps with selection, we need to use a different approach
            pasteboardLogger.debug("Element supports text selection, using keyboard simulation approach")

            // Store current clipboard content
            let pasteboard = NSPasteboard.general
            let originalContent = pasteboard.string(forType: .string)

            // Set our text to clipboard
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)

            // Simulate Cmd+V to paste
            let source = CGEventSource(stateID: .combinedSessionState)
            let vKey: CGKeyCode = 9 // V key code
            let cmdKey: CGKeyCode = 55

            let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: cmdKey, keyDown: true)
            let vDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
            vDown?.flags = CGEventFlags.maskCommand
            let vUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
            vUp?.flags = CGEventFlags.maskCommand
            let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: cmdKey, keyDown: false)

            cmdDown?.post(tap: CGEventTapLocation.cghidEventTap)
            vDown?.post(tap: CGEventTapLocation.cghidEventTap)
            vUp?.post(tap: CGEventTapLocation.cghidEventTap)
            cmdUp?.post(tap: CGEventTapLocation.cghidEventTap)

            // Restore original clipboard content after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let original = originalContent {
                    pasteboard.clearContents()
                    pasteboard.setString(original, forType: .string)
                } else {
                    pasteboard.clearContents()
                }
            }

            pasteboardLogger.debug("Successfully replaced selected text via keyboard simulation")
            return true
        }

        // Method 2: Try using AXValue to insert/replace text (works better in some apps)
        if supportsText {
            // Get current text content
            var currentValue: String = ""
            if AXUIElementCopyAttributeValue(focusedElement, kAXValueAttribute as CFString, &value) == .success,
               let stringValue = value as? String {
                currentValue = stringValue
            }

            // If there's selected text, replace it; otherwise insert at cursor
            var newText: String
            if selectedText.count > 0 {
                // Replace selected text
                guard CFGetTypeID(selectedRange) == AXValueGetTypeID() else {
                    pasteboardLogger.warning("Selected text range not available for replacement")
                    throw PasteError.failedToInsertText
                }

                let selectedRangeValue = selectedRange as! AXValue
                var cfRange: CFRange = CFRange(location: 0, length: 0)
                if AXValueGetValue(selectedRangeValue, .cfRange, &cfRange) {
                    let startIndex = currentValue.index(currentValue.startIndex, offsetBy: min(cfRange.location, currentValue.count))
                    let endIndex = currentValue.index(startIndex, offsetBy: min(cfRange.length, currentValue.distance(from: startIndex, to: currentValue.endIndex)))
                    newText = currentValue.replacingCharacters(in: startIndex..<endIndex, with: text)
                } else {
                    newText = text // Fallback: just replace everything
                }
            } else {
                // Insert at cursor position
                newText = currentValue + text
            }

            // Set the new text
            let setValueResult = AXUIElementSetAttributeValue(focusedElement, kAXValueAttribute as CFString, newText as CFTypeRef)
            if setValueResult == .success {
                pasteboardLogger.debug("Successfully inserted text via kAXValueAttribute")
                return true
            }

            pasteboardLogger.warning("Failed to insert via kAXValueAttribute: \(setValueResult.rawValue)")
        }

        pasteboardLogger.error("All text insertion methods failed")
        throw PasteError.failedToInsertText
    }
}
