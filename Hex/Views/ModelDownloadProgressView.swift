import SwiftUI
import ComposableArchitecture

/// Progress view for model downloads with cancellation support
/// Shows download percentage, speed, time remaining, and allows user to cancel
struct ModelDownloadProgressView: View {
    @State private var downloadProgress: Double = 0
    @State private var downloadSpeed: String = "0 MB/s"
    @State private var timeRemaining: String = "--:--"
    @State private var totalSize: String = "0 MB"
    @State private var isCancelling = false

    let modelName: String
    let modelId: String
    let onCancel: () -> Void
    let onComplete: () -> Void

    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Downloading Model")
                        .font(.headline)
                    Text(modelName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(downloadProgress))%")
                        .font(.headline)
                        .foregroundStyle(.blue)
                    Text(totalSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Progress bar
            VStack(spacing: 8) {
                ProgressView(value: downloadProgress / 100)
                    .tint(.blue)
                    .frame(height: 6)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Speed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(downloadSpeed)
                            .font(.caption2)
                            .fontWeight(.medium)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Time Remaining")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(timeRemaining)
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                }
            }
            .padding(12)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)

            // Action buttons
            HStack(spacing: 12) {
                Button(action: {
                    isCancelling = true
                    onCancel()
                }) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Cancel")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .foregroundStyle(.red)
                .disabled(isCancelling)

                Button(action: { /* Pause not yet implemented */ }) {
                    HStack {
                        Image(systemName: "pause.circle.fill")
                        Text("Pause")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .foregroundStyle(.secondary)
                .disabled(true) // TODO: Implement pause/resume
            }

            // Details section
            DetailsSection(modelId: modelId)
        }
        .padding(16)
        .background(Color(.windowBackgroundColor))
        .cornerRadius(12)
        .onReceive(timer) { _ in
            updateProgress()
        }
    }

    private func updateProgress() {
        // In a real implementation, this would be driven by the download manager
        // For now, we simulate progress
        if downloadProgress < 100 && !isCancelling {
            downloadProgress += Double.random(in: 0.5...2.5)
            downloadProgress = min(downloadProgress, 100)

            // Update simulated metrics
            let bytesPerSecond = Double.random(in: 500000...2000000) // 500KB-2MB/s
            downloadSpeed = formatBytes(Int(bytesPerSecond)) + "/s"

            if downloadProgress < 100 {
                let remainingBytes = 1_000_000_000 * (1 - downloadProgress / 100) // Assume 1GB
                let secondsRemaining = remainingBytes / bytesPerSecond
                timeRemaining = formatTimeRemaining(Int(secondsRemaining))
            } else {
                timeRemaining = "Complete"
                onComplete()
            }

            totalSize = "~1 GB"
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func formatTimeRemaining(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

// MARK: - Details Section

private struct DetailsSection: View {
    let modelId: String

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(
            isExpanded: $isExpanded,
            content: {
                VStack(alignment: .leading, spacing: 8) {
                    DetailRow(label: "Model ID", value: modelId)
                    DetailRow(label: "Download Location", value: "~/Library/Application Support/AIModels")
                    DetailRow(label: "Format", value: "GGUF (quantized)")
                    DetailRow(label: "Status", value: "In Progress")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            },
            label: {
                Text("Details")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        )
        .padding(8)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(6)
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .lineLimit(1)
                .truncationMode(.middle)
                .monospaced()
        }
    }
}

// MARK: - Preview

#Preview {
    ModelDownloadProgressView(
        modelName: "Mistral 7B",
        modelId: "TheBloke/Mistral-7B-v0.1-GGUF",
        onCancel: { print("Cancel tapped") },
        onComplete: { print("Download complete") }
    )
    .frame(width: 400)
}

// MARK: - Alternative: Badge Style (For List Display)

/// Compact download progress badge for use in model lists
struct ModelDownloadProgressBadge: View {
    let progress: Double // 0.0 - 1.0
    let speed: String
    let timeRemaining: String

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)

                ProgressView(value: progress)
                    .frame(maxWidth: .infinity)

                Image(systemName: "xmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Cancel action
                    }
            }

            HStack {
                Text(speed)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(timeRemaining)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(6)
    }
}

#Preview("Progress Badge") {
    ModelDownloadProgressBadge(
        progress: 0.65,
        speed: "1.5 MB/s",
        timeRemaining: "4:32"
    )
    .padding()
}
