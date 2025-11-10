import SwiftUI
import ComposableArchitecture

/// ModelDownloadView displays available models for download and manages the download process
///
/// Features:
/// - Browse available Hugging Face models
/// - Filter by model type
/// - Download progress tracking
/// - Model information display
/// - Download history
///
/// Used by User Story 5: AI Model Management (T030)
public struct ModelDownloadView: View {
    let store: StoreOf<AIAssistantFeature>

    @State private var searchText: String = ""
    @State private var selectedTask: String?
    @State private var isSearching = false
    @State private var sortBy: SortOption = .downloads

    enum SortOption {
        case name
        case downloads
        case size
        case newest
    }

    public init(store: StoreOf<AIAssistantFeature>) {
        self.store = store
    }

    public var body: some View {
        WithPerceptionTracking {
            NavigationView {
                VStack(spacing: 0) {
                    // MARK: - Search & Filter Bar

                    searchBar
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor))
                        .borderBottom()

                    // MARK: - Filter Options

                    filterBar
                        .padding(.horizontal)
                        .padding(.vertical, 8)

                    // MARK: - Models List

                    if store.isLoadingModels {
                        loadingView
                    } else if store.availableModels.isEmpty {
                        emptyView
                    } else {
                        modelsList
                    }
                }
                .navigationTitle("AI Models")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search models...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: searchText) { _, newValue in
                    // Trigger search in the reducer
                    if !newValue.isEmpty {
                        store.send(.loadAvailableModels)
                    }
                }

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        VStack(spacing: 8) {
            // Sort options
            HStack {
                Text("Sort by:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("Sort", selection: $sortBy) {
                    Text("Downloads").tag(SortOption.downloads)
                    Text("Name").tag(SortOption.name)
                    Text("Size").tag(SortOption.size)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: .infinity)
            }

            // Task filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(["All", "Text Generation", "QA", "Classification"], id: \.self) { task in
                        FilterChip(
                            label: task,
                            isSelected: selectedTask == task || (task == "All" && selectedTask == nil),
                            action: {
                                selectedTask = task == "All" ? nil : task
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Loading models...")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Searching Hugging Face for available models")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            VStack(spacing: 4) {
                Text("No models found")
                    .font(.headline)

                Text("Try searching for models like 'DialoGPT' or 'GPT2'")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button(action: { store.send(.loadAvailableModels) }) {
                Label("Browse Models", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Models List

    private var modelsList: some View {
        List {
            ForEach(filteredAndSortedModels, id: \.id) { model in
                ModelDownloadRow(
                    model: model,
                    isDownloaded: store.downloadedModels.contains { $0.id == model.id },
                    onDownload: {
                        let huggingFaceModel = HuggingFaceModel(
                            id: model.id,
                            name: model.name,
                            task: model.task,
                            downloads: model.downloads,
                            size: model.size
                        )
                        store.send(.downloadModel(huggingFaceModel))
                    }
                )
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Filtering & Sorting

    private var filteredAndSortedModels: [HuggingFaceModel] {
        var filtered = store.availableModels

        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { model in
                model.name.lowercased().contains(searchText.lowercased()) ||
                model.id.lowercased().contains(searchText.lowercased())
            }
        }

        // Filter by task
        if let task = selectedTask, task != "All" {
            filtered = filtered.filter { $0.task.lowercased().contains(task.lowercased()) }
        }

        // Sort
        switch sortBy {
        case .name:
            filtered.sort { $0.name.lowercased() < $1.name.lowercased() }
        case .downloads:
            filtered.sort { $0.downloads > $1.downloads }
        case .size:
            filtered.sort { $0.size < $1.size }
        case .newest:
            break
        }

        return filtered
    }
}

// MARK: - Model Row Component

struct ModelDownloadRow: View {
    let model: HuggingFaceModel
    let isDownloaded: Bool
    let onDownload: () -> Void

    @State private var showDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.name)
                        .font(.headline)

                    Text(model.id)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isDownloaded {
                    Label("Downloaded", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Button(action: onDownload) {
                        Label("Download", systemImage: "arrow.down.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }

            HStack(spacing: 16) {
                Label(formatBytes(model.size), systemImage: "internaldrive")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Label("\(model.downloads)", systemImage: "arrow.down")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Label(model.task, systemImage: "tag")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Filter Chip Component

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(nsColor: .controlBackgroundColor))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Helper Extensions

extension View {
    fileprivate func borderBottom() -> some View {
        VStack {
            self
            Divider()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ModelDownloadView_Previews: PreviewProvider {
    static var previews: some View {
        ModelDownloadView(
            store: Store(
                initialState: AIAssistantFeature.State(
                    availableModels: [
                        HuggingFaceModel(
                            id: "microsoft/DialoGPT-small",
                            name: "DialoGPT Small",
                            task: "text-generation",
                            downloads: 50000,
                            size: 100_000_000
                        ),
                        HuggingFaceModel(
                            id: "microsoft/DialoGPT-medium",
                            name: "DialoGPT Medium",
                            task: "text-generation",
                            downloads: 100000,
                            size: 300_000_000
                        ),
                    ]
                )
            ) {
                AIAssistantFeature()
            }
        )
        .frame(width: 800, height: 600)
    }
}
#endif
