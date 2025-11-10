import Foundation
import ComposableArchitecture

/// Manages timers for voice-controlled productivity features
/// Supports multiple concurrent timers with notifications and callbacks
///
/// Used by User Story 3: Voice Productivity Tools (T047)
public struct TimerManager {
    // MARK: - Types

    public struct Timer: Equatable, Identifiable {
        public let id: UUID
        public let name: String
        public let duration: TimeInterval // in seconds
        public let createdAt: Date
        public var startedAt: Date?
        public var pausedAt: Date?
        public var totalPausedDuration: TimeInterval = 0

        public var isRunning: Bool {
            startedAt != nil && pausedAt == nil
        }

        public var isPaused: Bool {
            pausedAt != nil
        }

        public var remainingTime: TimeInterval {
            guard let startedAt = startedAt else { return duration }

            let elapsedSinceStart = Date().timeIntervalSince(startedAt) - totalPausedDuration

            if let pausedAt = pausedAt {
                // Timer is paused, use paused time to calculate remaining
                let elapsedBeforePause = pausedAt.timeIntervalSince(startedAt) - totalPausedDuration
                return max(0, duration - elapsedBeforePause)
            }

            return max(0, duration - elapsedSinceStart)
        }

        public var isComplete: Bool {
            remainingTime <= 0
        }

        public var progress: Double {
            let elapsed = duration - remainingTime
            return min(1.0, max(0, elapsed / duration))
        }

        public init(id: UUID = UUID(), name: String, duration: TimeInterval, createdAt: Date = Date()) {
            self.id = id
            self.name = name
            self.duration = duration
            self.createdAt = createdAt
        }
    }

    enum TimerError: LocalizedError {
        case timerNotFound
        case invalidDuration
        case timerAlreadyRunning
        case timerNotRunning

        public var errorDescription: String? {
            switch self {
            case .timerNotFound:
                return "Timer not found"
            case .invalidDuration:
                return "Invalid timer duration"
            case .timerAlreadyRunning:
                return "Timer is already running"
            case .timerNotRunning:
                return "Timer is not running"
            }
        }
    }

    // MARK: - Properties

    private var timers: [UUID: Timer] = [:]
    private var timerUpdateTask: Task<Void, Never>?

    // MARK: - Initialization

    public init() {}

    // MARK: - Timer Management

    /// Create a new timer
    /// - Parameters:
    ///   - name: Name/description of the timer
    ///   - duration: Duration in seconds
    /// - Returns: The created timer
    /// - Throws: TimerError if duration is invalid
    public mutating func createTimer(name: String, duration: TimeInterval) throws -> Timer {
        guard duration > 0 else {
            throw TimerError.invalidDuration
        }

        let timer = Timer(name: name, duration: duration)
        timers[timer.id] = timer

        return timer
    }

    /// Start a timer
    /// - Parameter id: The timer ID
    /// - Throws: TimerError if timer not found or already running
    public mutating func startTimer(_ id: UUID) throws {
        guard var timer = timers[id] else {
            throw TimerError.timerNotFound
        }

        guard !timer.isRunning else {
            throw TimerError.timerAlreadyRunning
        }

        if timer.startedAt == nil {
            timer.startedAt = Date()
        }
        timer.pausedAt = nil

        timers[id] = timer
    }

    /// Pause a running timer
    /// - Parameter id: The timer ID
    /// - Throws: TimerError if timer not found or not running
    public mutating func pauseTimer(_ id: UUID) throws {
        guard var timer = timers[id] else {
            throw TimerError.timerNotFound
        }

        guard timer.isRunning else {
            throw TimerError.timerNotRunning
        }

        timer.pausedAt = Date()
        timers[id] = timer
    }

    /// Resume a paused timer
    /// - Parameter id: The timer ID
    /// - Throws: TimerError if timer not found or not paused
    public mutating func resumeTimer(_ id: UUID) throws {
        guard var timer = timers[id] else {
            throw TimerError.timerNotFound
        }

        guard timer.isPaused else {
            throw TimerError.timerNotRunning
        }

        if let pausedAt = timer.pausedAt, let startedAt = timer.startedAt {
            let pauseDuration = Date().timeIntervalSince(pausedAt)
            timer.totalPausedDuration += pauseDuration
        }

        timer.pausedAt = nil
        timers[id] = timer
    }

    /// Cancel a timer
    /// - Parameter id: The timer ID
    /// - Throws: TimerError if timer not found
    public mutating func cancelTimer(_ id: UUID) throws {
        guard timers[id] != nil else {
            throw TimerError.timerNotFound
        }

        timers.removeValue(forKey: id)
    }

    /// Get a specific timer
    /// - Parameter id: The timer ID
    /// - Returns: The timer, or nil if not found
    public func getTimer(_ id: UUID) -> Timer? {
        timers[id]
    }

    /// Get all active timers
    /// - Returns: Array of timers
    public func getAllTimers() -> [Timer] {
        Array(timers.values).sorted { $0.createdAt < $1.createdAt }
    }

    /// Get all running timers
    /// - Returns: Array of running timers
    public func getRunningTimers() -> [Timer] {
        getAllTimers().filter { $0.isRunning }
    }

    /// Update timer states and check for completions
    /// - Returns: Array of IDs for timers that just completed
    public mutating func updateTimers() -> [UUID] {
        var completedIds: [UUID] = []

        for (id, timer) in timers {
            if timer.isComplete && timer.isRunning {
                var updated = timer
                updated.pausedAt = Date() // Mark as complete
                timers[id] = updated
                completedIds.append(id)
            }
        }

        return completedIds
    }

    // MARK: - Utility Methods

    /// Format time interval as MM:SS
    /// - Parameter timeInterval: Time in seconds
    /// - Returns: Formatted string (e.g., "05:30")
    public static func formatTime(_ timeInterval: TimeInterval) -> String {
        let totalSeconds = Int(timeInterval)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Parse natural language timer input
    /// - Parameter input: String like "5 minutes", "30 seconds", "1 hour"
    /// - Returns: TimeInterval in seconds, or nil if parsing fails
    public static func parseTimerInput(_ input: String) -> TimeInterval? {
        let lowercased = input.lowercased().trimmingCharacters(in: .whitespaces)

        // Extract number and unit
        let parts = lowercased.components(separatedBy: .whitespaces)
        guard parts.count >= 2 else { return nil }

        guard let value = Double(parts[0]) else { return nil }

        let unit = parts[1]

        switch unit {
        case "second", "seconds", "sec", "secs", "s":
            return value
        case "minute", "minutes", "min", "mins", "m":
            return value * 60
        case "hour", "hours", "hr", "hrs", "h":
            return value * 3600
        default:
            return nil
        }
    }

    /// Get total duration of all timers
    /// - Returns: Sum of all timer durations
    public func getTotalDuration() -> TimeInterval {
        timers.values.reduce(0) { $0 + $1.duration }
    }

    /// Get total remaining time across all running timers
    /// - Returns: Sum of remaining times
    public func getTotalRemainingTime() -> TimeInterval {
        timers.values.filter { $0.isRunning }.reduce(0) { $0 + $1.remainingTime }
    }

    /// Delete all completed timers
    /// - Returns: Count of deleted timers
    public mutating func deleteCompletedTimers() -> Int {
        let completedIds = timers.filter { $0.value.isComplete }.map { $0.key }
        completedIds.forEach { timers.removeValue(forKey: $0) }
        return completedIds.count
    }
}

// MARK: - TCA Integration

extension DependencyValues {
    var timerManager: TimerManager {
        get { self[TimerManagerKey.self] }
        set { self[TimerManagerKey.self] = newValue }
    }
}

private enum TimerManagerKey: DependencyKey {
    static let liveValue = TimerManager()
    static let previewValue = TimerManager()
    static let testValue = TimerManager()
}
