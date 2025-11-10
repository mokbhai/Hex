import SwiftUI
import ComposableArchitecture

/// View for displaying timer notifications and alerts
/// Shows timer completion notifications and timer management UI
///
/// Used by User Story 3: Voice Productivity Tools (T052)
struct TimerNotificationView: View {
    @Environment(\.dismiss) var dismiss
    let timer: TimerManager.Timer
    let onDismiss: () -> Void
    let onExtend: (TimeInterval) -> Void

    @State private var isComplete = false
    @State private var displayTime: String = ""
    @State private var updateTimer: Timer?

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Title
                Text("Timer Complete")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)

                // Timer Name (if available)
                if !timer.name.isEmpty {
                    Text(timer.name)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.gray)
                }

                // Animation
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                        .scaleEffect(isComplete ? 1.0 : 0.5)
                        .opacity(isComplete ? 1.0 : 0.5)
                }

                Spacer()

                // Action Buttons
                HStack(spacing: 16) {
                    // Dismiss Button
                    Button(action: {
                        onDismiss()
                        dismiss()
                    }) {
                        Text("Done")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(8)
                    }

                    // Extend Button
                    Menu {
                        Button("5 minutes") {
                            onExtend(300)
                        }
                        Button("10 minutes") {
                            onExtend(600)
                        }
                        Button("15 minutes") {
                            onExtend(900)
                        }
                    } label: {
                        Text("Extend")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue.opacity(0.7))
                            .cornerRadius(8)
                    }
                }
            }
            .padding(24)
        }
        .onAppear {
            isComplete = true
            startAudio()
        }
        .onDisappear {
            stopAudio()
        }
    }

    private func startAudio() {
        // Play system sound notification
        #if os(macOS)
        NSSound(named: NSSound.Name("Glass"))?.play()
        #endif
    }

    private func stopAudio() {
        // Cleanup if needed
    }
}

/// Compact timer display for showing active timers
struct TimerCompactView: View {
    let timer: TimerManager.Timer
    let onTapped: () -> Void

    @State private var displayTime: String = ""
    @State private var updateTimer: Timer?

    var body: some View {
        VStack(spacing: 8) {
            // Timer display
            VStack(spacing: 4) {
                Text(timer.name.isEmpty ? "Timer" : timer.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                Text(TimerManager.formatTime(timer.remainingTime))
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(timer.remainingTime < 60 ? .red : .white)
            }

            // Progress bar
            ProgressView(value: timer.progress)
                .tint(.blue)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .onTapGesture(perform: onTapped)
        .onAppear {
            startUpdating()
        }
        .onDisappear {
            stopUpdating()
        }
    }

    private func startUpdating() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            displayTime = TimerManager.formatTime(timer.remainingTime)
        }
    }

    private func stopUpdating() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
}

/// List view for managing multiple timers
struct TimerListView: View {
    let timers: [TimerManager.Timer]
    let onSelectTimer: (TimerManager.Timer) -> Void
    let onDeleteTimer: (UUID) -> Void

    var body: some View {
        List {
            ForEach(timers) { timer in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(timer.name.isEmpty ? "Timer" : timer.name)
                            .font(.system(size: 16, weight: .semibold))

                        HStack(spacing: 8) {
                            Image(systemName: timer.isRunning ? "play.fill" : "pause.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)

                            Text(TimerManager.formatTime(timer.remainingTime))
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(.secondary)

                            ProgressView(value: timer.progress)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    Spacer()

                    Menu {
                        if timer.isRunning {
                            Button("Pause") {
                                // TODO: Pause action
                            }
                        } else if timer.isPaused {
                            Button("Resume") {
                                // TODO: Resume action
                            }
                        }

                        Button("Delete", role: .destructive) {
                            onDeleteTimer(timer.id)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                .onTapGesture {
                    onSelectTimer(timer)
                }
            }
        }
    }
}

#Preview {
    TimerNotificationView(
        timer: TimerManager.Timer(name: "Pomodoro", duration: 1500),
        onDismiss: {},
        onExtend: { _ in }
    )
}
