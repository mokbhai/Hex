import Foundation

/// SystemCommand represents a voice command for system control
/// 
/// Supports:
/// - App management (launch, close, focus)
/// - Window management (minimize, maximize, close)
/// - System actions (sleep, screenshot, volume)
/// 
/// Used by User Story 1: Voice System Control
public enum SystemCommand: Equatable {
    // MARK: - App Management

    /// Launch an application
    case launchApp(String) // App name

    /// Close an application
    case closeApp(String) // App name

    /// Focus an application window
    case focusApp(String) // App name

    // MARK: - Window Management

    /// Minimize the frontmost window
    case minimizeWindow

    /// Maximize/restore the frontmost window
    case maximizeWindow

    /// Close the frontmost window
    case closeWindow

    /// Move window to left half of screen
    case snapWindowLeft

    /// Move window to right half of screen
    case snapWindowRight

    // MARK: - System Actions

    /// Lock the screen
    case lockScreen

    /// Sleep the system
    case sleep

    /// Take a screenshot
    case screenshot

    /// Adjust system volume
    case setVolume(Int) // 0-100

    /// Mute/unmute audio
    case toggleMute

    /// Brightness control
    case setBrightness(Int) // 0-100

    // MARK: - Execution

    /// Execute this command
    /// - Returns: Result of execution
    @available(macOS 10.15, *)
    public func execute() async throws -> CommandExecutionResult {
        switch self {
        // App Management
        case .launchApp(let appName):
            return try await executeAppLaunch(appName)
        case .closeApp(let appName):
            return try await executeAppClose(appName)
        case .focusApp(let appName):
            return try await executeAppFocus(appName)

        // Window Management
        case .minimizeWindow:
            return try await executeMinimizeWindow()
        case .maximizeWindow:
            return try await executeMaximizeWindow()
        case .closeWindow:
            return try await executeCloseWindow()
        case .snapWindowLeft:
            return try await executeSnapWindowLeft()
        case .snapWindowRight:
            return try await executeSnapWindowRight()

        // System Actions
        case .lockScreen:
            return try await executeLockScreen()
        case .sleep:
            return try await executeSleep()
        case .screenshot:
            return try await executeScreenshot()
        case .setVolume(let level):
            return try await executeSetVolume(level)
        case .toggleMute:
            return try await executeToggleMute()
        case .setBrightness(let level):
            return try await executeSetBrightness(level)
        }
    }

    // MARK: - Command Execution Implementations

    private func executeAppLaunch(_ appName: String) async throws -> CommandExecutionResult {
        // TODO: T017 App Launch
        // 1. Search for app by name
        // 2. Launch using NSWorkspace
        // 3. Wait for app to launch
        // 4. Return success with app path
        return CommandExecutionResult(
            success: true,
            message: "Launched \(appName)",
            details: ["appName": appName]
        )
    }

    private func executeAppClose(_ appName: String) async throws -> CommandExecutionResult {
        // TODO: T017 App Close
        // 1. Find running app by name
        // 2. Send quit event
        // 3. Handle unsaved changes
        return CommandExecutionResult(
            success: true,
            message: "Closed \(appName)",
            details: ["appName": appName]
        )
    }

    private func executeAppFocus(_ appName: String) async throws -> CommandExecutionResult {
        // TODO: T017 App Focus
        // 1. Find app by name
        // 2. Focus it using NSRunningApplication
        return CommandExecutionResult(
            success: true,
            message: "Focused \(appName)",
            details: ["appName": appName]
        )
    }

    private func executeMinimizeWindow() async throws -> CommandExecutionResult {
        // TODO: T019 Window Minimize
        // 1. Get frontmost window
        // 2. Send minimize command
        return CommandExecutionResult(success: true, message: "Minimized window")
    }

    private func executeMaximizeWindow() async throws -> CommandExecutionResult {
        // TODO: T019 Window Maximize
        // 1. Get frontmost window
        // 2. Toggle maximize state
        return CommandExecutionResult(success: true, message: "Maximized window")
    }

    private func executeCloseWindow() async throws -> CommandExecutionResult {
        // TODO: T019 Window Close
        // 1. Get frontmost window
        // 2. Send close command
        return CommandExecutionResult(success: true, message: "Closed window")
    }

    private func executeSnapWindowLeft() async throws -> CommandExecutionResult {
        // TODO: T019 Window Snap Left
        // 1. Get frontmost window
        // 2. Resize to left half of screen
        return CommandExecutionResult(success: true, message: "Snapped window to left")
    }

    private func executeSnapWindowRight() async throws -> CommandExecutionResult {
        // TODO: T019 Window Snap Right
        // 1. Get frontmost window
        // 2. Resize to right half of screen
        return CommandExecutionResult(success: true, message: "Snapped window to right")
    }

    private func executeLockScreen() async throws -> CommandExecutionResult {
        // TODO: T020 System Lock
        // 1. Execute lock screen command
        return CommandExecutionResult(success: true, message: "Locked screen")
    }

    private func executeSleep() async throws -> CommandExecutionResult {
        // TODO: T020 System Sleep
        // 1. Execute sleep command via osascript
        return CommandExecutionResult(success: true, message: "Putting system to sleep")
    }

    private func executeScreenshot() async throws -> CommandExecutionResult {
        // TODO: T020 System Screenshot
        // 1. Capture screenshot
        // 2. Save to specified location
        return CommandExecutionResult(success: true, message: "Screenshot captured")
    }

    private func executeSetVolume(_ level: Int) async throws -> CommandExecutionResult {
        // TODO: T020 System Volume
        // 1. Validate level (0-100)
        // 2. Set system volume
        return CommandExecutionResult(success: true, message: "Set volume to \(level)%")
    }

    private func executeToggleMute() async throws -> CommandExecutionResult {
        // TODO: T020 System Mute
        // 1. Get current mute state
        // 2. Toggle it
        return CommandExecutionResult(success: true, message: "Toggled mute")
    }

    private func executeSetBrightness(_ level: Int) async throws -> CommandExecutionResult {
        // TODO: T020 System Brightness
        // 1. Validate level (0-100)
        // 2. Set brightness via system APIs
        return CommandExecutionResult(success: true, message: "Set brightness to \(level)%")
    }
}

// MARK: - Execution Result

/// Result of command execution
public struct CommandExecutionResult: Equatable {
    public let success: Bool
    public let message: String
    public let details: [String: String]
    public let timestamp: Date

    public init(
        success: Bool,
        message: String,
        details: [String: String] = [:],
        timestamp: Date = Date()
    ) {
        self.success = success
        self.message = message
        self.details = details
        self.timestamp = timestamp
    }
}

// MARK: - Command Parsing

/// Parse natural language commands into SystemCommand enums
public struct CommandParser {
    /// Parse a voice command string into a SystemCommand
    /// - Parameter input: Voice command text (e.g., "Open Safari")
    /// - Returns: Parsed command, or nil if not recognized
    public static func parse(_ input: String) -> SystemCommand? {
        let lowercased = input.lowercased().trimmingCharacters(in: .whitespaces)

        // App launch: "Open [app]", "Launch [app]"
        if let appName = extractAppName(from: lowercased, pattern: "^(open|launch)\\s+(.+)") {
            return .launchApp(appName)
        }

        // App close: "Close [app]", "Quit [app]"
        if let appName = extractAppName(from: lowercased, pattern: "^(close|quit)\\s+(.+)") {
            return .closeApp(appName)
        }

        // Window management: "Minimize window", "Maximize window"
        if lowercased.contains("minimize") {
            return .minimizeWindow
        }
        if lowercased.contains("maximize") {
            return .maximizeWindow
        }

        // System actions: "Take a screenshot", "Lock screen"
        if lowercased.contains("screenshot") {
            return .screenshot
        }
        if lowercased.contains("lock") {
            return .lockScreen
        }

        return nil
    }

    private static func extractAppName(from text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else {
            return nil
        }

        guard match.numberOfRanges > 2,
              let appNameRange = Range(match.range(at: 2), in: text) else {
            return nil
        }

        return String(text[appNameRange]).trimmingCharacters(in: .whitespaces)
    }
}
