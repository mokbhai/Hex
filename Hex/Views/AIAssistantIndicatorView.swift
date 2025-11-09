import SwiftUI
import ComposableArchitecture

/// AIAssistantIndicatorView displays the listening state of the AI assistant
///
/// Shows:
/// - Animated waveform during active listening
/// - Visual feedback for command recognition
/// - Status messages
/// - Microphone access indicator
///
/// Used by User Story 1: Voice System Control
public struct AIAssistantIndicatorView: View {
    let store: StoreOf<AIAssistantFeature>

    @State private var isAnimating = false
    @State private var wavePhase: Double = 0

    public init(store: StoreOf<AIAssistantFeature>) {
        self.store = store
    }

    public var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 12) {
                // MARK: - Listening Indicator

                if store.isListening {
                    listeningIndicator
                        .transition(.scale.combined(with: .opacity))
                } else if store.isExecutingCommand {
                    executingIndicator
                        .transition(.scale.combined(with: .opacity))
                }

                // MARK: - Status Message

                if let lastCommand = store.lastRecognizedCommand {
                    Text("Recognized: \(lastCommand)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .transition(.opacity)
                }

                // MARK: - Error Display

                if let error = store.lastError {
                    errorDisplay(error)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .onReceive(Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()) { _ in
                wavePhase += 0.1
            }
        }
    }

    // MARK: - Listening Indicator

    private var listeningIndicator: some View {
        VStack(spacing: 8) {
            // MARK: Animated Waveform

            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<7, id: \.self) { index in
                    waveBar(index: index)
                }
            }
            .frame(height: 24)

            // MARK: Status Text

            HStack(spacing: 6) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)

                Text("Listening...")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }

    private func waveBar(index: Int) -> some View {
        let offset = CGFloat(index) * 0.3
        let phase = wavePhase + offset
        let height = 24 * (0.3 + 0.7 * (0.5 + 0.5 * sin(phase)))

        return Capsule()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        .blue.opacity(0.8),
                        .cyan.opacity(0.8),
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: height)
    }

    // MARK: - Executing Indicator

    private var executingIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)

            Text("Executing command...")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            Spacer()
        }
    }

    // MARK: - Error Display

    private func errorDisplay(_ error: AIAssistantFeature.AIAssistantError) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
                .font(.caption)

            VStack(alignment: .leading, spacing: 2) {
                Text("Error")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)

                Text(error.errorDescription ?? "Unknown error")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(8)
        .background(Color.red.opacity(0.1))
        .cornerRadius(6)
    }
}

// MARK: - Preview

#if DEBUG
struct AIAssistantIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Listening state
            AIAssistantIndicatorView(
                store: Store(
                    initialState: AIAssistantFeature.State(
                        isListening: true
                    )
                ) {
                    AIAssistantFeature()
                }
            )
            .previewDisplayName("Listening")

            // Executing state
            AIAssistantIndicatorView(
                store: Store(
                    initialState: AIAssistantFeature.State(
                        isExecutingCommand: true,
                        lastRecognizedCommand: "Open Safari"
                    )
                ) {
                    AIAssistantFeature()
                }
            )
            .previewDisplayName("Executing")

            // Error state
            AIAssistantIndicatorView(
                store: Store(
                    initialState: AIAssistantFeature.State(
                        lastError: .commandExecutionFailed("App not found")
                    )
                ) {
                    AIAssistantFeature()
                }
            )
            .previewDisplayName("Error")

            // Idle state
            AIAssistantIndicatorView(
                store: Store(
                    initialState: AIAssistantFeature.State()
                ) {
                    AIAssistantFeature()
                }
            )
            .previewDisplayName("Idle")
        }
        .frame(width: 300)
        .padding()
    }
}
#endif
