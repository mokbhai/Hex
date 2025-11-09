import Foundation
import AppKit

/// SystemCommandExecutor handles the execution of system commands with error handling
///
/// Responsible for:
/// - App management (launch, close, focus)
/// - Window management (resize, move, snap)
/// - System actions (volume, brightness, screenshot)
/// - Error recovery and user feedback
///
/// Used by User Story 1: Voice System Control
public struct SystemCommandExecutor {
    // MARK: - Public Interface

    /// Execute a system command with comprehensive error handling
    /// - Parameter command: SystemCommand to execute
    /// - Returns: Result of execution with status and message
    public static func execute(_ command: SystemCommand) async -> CommandExecutionResult {
        do {
            let result = try await command.execute()
            return result
        } catch {
            let errorMessage = errorMessage(for: error)
            return CommandExecutionResult(
                success: false,
                message: errorMessage,
                details: ["error": "\(error)"]
            )
        }
    }

    // MARK: - App Management Execution

    /// Execute app launch command
    /// - Parameter appName: Name of app to launch
    /// - Returns: Result with app path if successful
    public static func executeAppLaunch(_ appName: String) async throws -> CommandExecutionResult {
        let workspace = NSWorkspace.shared

        // Search for app in standard locations
        guard let appPath = findApplication(named: appName) else {
            throw SystemCommandError.appNotFound(appName)
        }

        let appURL = URL(fileURLWithPath: appPath)

        do {
            try workspace.launchApplication(
                appURL.path,
                arguments: []
            )

            return CommandExecutionResult(
                success: true,
                message: "Launched \(appName)",
                details: ["appPath": appPath]
            )
        } catch {
            throw SystemCommandError.launchFailed(appName, error.localizedDescription)
        }
    }

    /// Execute app close command
    /// - Parameter appName: Name of app to close
    /// - Returns: Result indicating if app was closed
    public static func executeAppClose(_ appName: String) async throws -> CommandExecutionResult {
        guard let runningApp = findRunningApplication(named: appName) else {
            throw SystemCommandError.appNotRunning(appName)
        }

        let success = runningApp.terminate()

        guard success else {
            throw SystemCommandError.terminationFailed(appName)
        }

        return CommandExecutionResult(
            success: true,
            message: "Closed \(appName)",
            details: ["appName": appName]
        )
    }

    /// Execute app focus command
    /// - Parameter appName: Name of app to focus
    /// - Returns: Result indicating if app was focused
    public static func executeAppFocus(_ appName: String) async throws -> CommandExecutionResult {
        guard let runningApp = findRunningApplication(named: appName) else {
            throw SystemCommandError.appNotRunning(appName)
        }

        let success = runningApp.activate(options: .activateAllWindows)

        guard success else {
            throw SystemCommandError.focusFailed(appName)
        }

        return CommandExecutionResult(
            success: true,
            message: "Focused \(appName)",
            details: ["appName": appName]
        )
    }

    // MARK: - Window Management Execution

    /// Execute minimize window command
    public static func executeMinimizeWindow() async throws -> CommandExecutionResult {
        // Use AppleScript for window management
        let script = "tell application \"System Events\" to key code 101" // F11 key for minimize
        try executeAppleScript(script)

        return CommandExecutionResult(success: true, message: "Minimized window")
    }

    /// Execute maximize window command
    public static func executeMaximizeWindow() async throws -> CommandExecutionResult {
        let script = """
        tell application "System Events"
            click green button of front window
        end tell
        """
        try executeAppleScript(script)

        return CommandExecutionResult(success: true, message: "Maximized window")
    }

    /// Execute close window command
    public static func executeCloseWindow() async throws -> CommandExecutionResult {
        let script = """
        tell application "System Events"
            click red button of front window
        end tell
        """
        try executeAppleScript(script)

        return CommandExecutionResult(success: true, message: "Closed window")
    }

    /// Execute snap window to left command
    public static func executeSnapWindowLeft() async throws -> CommandExecutionResult {
        let script = """
        tell application "System Events"
            key code 123 using {command down, option down}
        end tell
        """
        try executeAppleScript(script)

        return CommandExecutionResult(success: true, message: "Snapped window to left")
    }

    /// Execute snap window to right command
    public static func executeSnapWindowRight() async throws -> CommandExecutionResult {
        let script = """
        tell application "System Events"
            key code 124 using {command down, option down}
        end tell
        """
        try executeAppleScript(script)

        return CommandExecutionResult(success: true, message: "Snapped window to right")
    }

    // MARK: - System Actions Execution

    /// Execute lock screen command
    public static func executeLockScreen() async throws -> CommandExecutionResult {
        let script = """
        tell application "System Events"
            key code 55 using {control down, command down}
        end tell
        """
        try executeAppleScript(script)

        return CommandExecutionResult(success: true, message: "Locked screen")
    }

    /// Execute sleep system command
    public static func executeSleep() async throws -> CommandExecutionResult {
        let script = """
        tell application "System Events"
            sleep
        end tell
        """
        try executeAppleScript(script)

        return CommandExecutionResult(success: true, message: "Putting system to sleep")
    }

    /// Execute screenshot command
    public static func executeScreenshot() async throws -> CommandExecutionResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", "-t", "png"]

        do {
            try process.run()
            process.waitUntilExit()

            return CommandExecutionResult(
                success: true,
                message: "Screenshot captured to clipboard"
            )
        } catch {
            throw SystemCommandError.screenshotFailed(error.localizedDescription)
        }
    }

    /// Execute set volume command
    /// - Parameter level: Volume level (0-100)
    public static func executeSetVolume(_ level: Int) async throws -> CommandExecutionResult {
        let validLevel = min(100, max(0, level))
        let scriptLevel = validLevel / 2 // macOS volume scale is 0-16

        let script = """
        set volume output volume \(scriptLevel)
        """

        try executeAppleScript(script)

        return CommandExecutionResult(
            success: true,
            message: "Set volume to \(validLevel)%"
        )
    }

    /// Execute toggle mute command
    public static func executeToggleMute() async throws -> CommandExecutionResult {
        let script = """
        set currentVolume to output volume
        if currentVolume > 0 then
            set volume output volume 0
        else
            set volume output volume 10
        end if
        """

        try executeAppleScript(script)

        return CommandExecutionResult(success: true, message: "Toggled mute")
    }

    /// Execute set brightness command
    /// - Parameter level: Brightness level (0-100)
    public static func executeSetBrightness(_ level: Int) async throws -> CommandExecutionResult {
        let validLevel = min(100, max(0, level))

        let script = """
        tell application "System Events"
            tell display 1
                set brightness to \(validLevel)
            end tell
        end tell
        """

        try executeAppleScript(script)

        return CommandExecutionResult(
            success: true,
            message: "Set brightness to \(validLevel)%"
        )
    }

    // MARK: - Helper Functions

    /// Find application by name in standard locations
    /// - Parameter name: App name (with or without .app extension)
    /// - Returns: Path to app bundle if found
    private static func findApplication(named name: String) -> String? {
        let workspace = NSWorkspace.shared
        let appName = name.hasSuffix(".app") ? name : name + ".app"

        // Check common app locations
        let locations = [
            "/Applications",
            "/Applications/Utilities",
            NSHomeDirectory() + "/Applications",
            "/System/Applications",
        ]

        for location in locations {
            let appPath = URL(fileURLWithPath: location).appendingPathComponent(appName).path
            if FileManager.default.fileExists(atPath: appPath) {
                return appPath
            }
        }

        // Fallback: use workspace's method
        if let appURL = workspace.urlForApplication(withBundleIdentifier: name) {
            return appURL.path
        }

        return nil
    }

    /// Find running application by name
    /// - Parameter name: App name
    /// - Returns: NSRunningApplication if found
    private static func findRunningApplication(named name: String) -> NSRunningApplication? {
        let workspace = NSWorkspace.shared

        // Search by name
        for app in workspace.runningApplications {
            if let appName = app.localizedName,
               appName.lowercased().contains(name.lowercased()) {
                return app
            }
        }

        return nil
    }

    /// Execute an AppleScript with error handling
    /// - Parameter script: AppleScript code
    private static func executeAppleScript(_ script: String) throws {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: script) else {
            throw SystemCommandError.scriptExecutionFailed("Invalid AppleScript")
        }

        let result = script.executeAndReturnError(&error)

        if error != nil {
            let errorMsg = error?["NSAppleScriptErrorMessage"] as? String ?? "Unknown error"
            throw SystemCommandError.scriptExecutionFailed(errorMsg)
        }
    }

    /// Convert error to user-friendly message
    /// - Parameter error: Error to convert
    /// - Returns: User-friendly error message
    private static func errorMessage(for error: Error) -> String {
        if let sysError = error as? SystemCommandError {
            return sysError.localizedDescription
        }

        return "Failed to execute command: \(error.localizedDescription)"
    }
}

// MARK: - Error Types

/// Errors that can occur during system command execution
public enum SystemCommandError: LocalizedError, Equatable {
    case appNotFound(String)
    case appNotRunning(String)
    case launchFailed(String, String)
    case terminationFailed(String)
    case focusFailed(String)
    case screenshotFailed(String)
    case scriptExecutionFailed(String)
    case invalidParameter(String)

    public var errorDescription: String? {
        switch self {
        case .appNotFound(let appName):
            return "App '\(appName)' not found"
        case .appNotRunning(let appName):
            return "App '\(appName)' is not running"
        case .launchFailed(let appName, let reason):
            return "Failed to launch \(appName): \(reason)"
        case .terminationFailed(let appName):
            return "Failed to close \(appName)"
        case .focusFailed(let appName):
            return "Failed to focus \(appName)"
        case .screenshotFailed(let reason):
            return "Screenshot failed: \(reason)"
        case .scriptExecutionFailed(let reason):
            return "Command failed: \(reason)"
        case .invalidParameter(let param):
            return "Invalid parameter: \(param)"
        }
    }
}
