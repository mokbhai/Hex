import SwiftUI
import ComposableArchitecture

/// SearchResultsView displays web and local file search results
///
/// Features:
/// - Unified display for web and local results
/// - Result filtering and sorting
/// - Quick actions (open, copy)
/// - Relevance indicators
///
/// Used by User Story 2: Voice Information Search (T041)
public struct SearchResultsView: View {
    let store: StoreOf<AIAssistantFeature>

    @State private var sortBy: SortOption = .relevance
    @State private var filterType: FilterType = .all

    enum SortOption {
        case relevance
        case title
        case type
    }

    enum FilterType {
        case all
        case web
        case local
    }

    public init(store: StoreOf<AIAssistantFeature>) {
        self.store = store
    }

    public var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                // MARK: - Search Query Display

                if let query = store.lastSearchQuery {
                    SearchHeaderView(query: query)
                        .borderBottom()
                }

                // MARK: - Filter & Sort Controls

                filterAndSortBar
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .borderBottom()

                // MARK: - Results List

                if store.isSearching {
                    loadingView
                } else if store.searchResults.isEmpty {
                    emptyView
                } else {
                    resultsList
                }
            }
        }
    }

    // MARK: - Filter & Sort Bar

    private var filterAndSortBar: some View {
        HStack(spacing: 12) {
            // Filter buttons
            HStack(spacing: 8) {
                FilterButton(
                    label: "All",
                    isSelected: filterType == .all,
                    action: { filterType = .all }
                )

                FilterButton(
                    label: "Web",
                    isSelected: filterType == .web,
                    action: { filterType = .web }
                )

                FilterButton(
                    label: "Files",
                    isSelected: filterType == .local,
                    action: { filterType = .local }
                )
            }

            Spacer()

            // Sort dropdown
            Menu {
                Button(action: { sortBy = .relevance }) {
                    Label("Relevance", systemImage: "arrow.down")
                }

                Button(action: { sortBy = .title }) {
                    Label("Title", systemImage: "abc")
                }

                Button(action: { sortBy = .type }) {
                    Label("Type", systemImage: "tag")
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
                    .font(.caption)
            }
            .menuStyle(.button)
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Searching...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            VStack(spacing: 4) {
                Text("No results found")
                    .font(.headline)

                if let query = store.lastSearchQuery {
                    Text("No matches for '\(query)'")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Results List

    private var resultsList: some View {
        List {
            ForEach(filteredAndSortedResults, id: \.id) { result in
                SearchResultRow(result: result)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Filtering & Sorting

    private var filteredAndSortedResults: [AIAssistantFeature.SearchResult] {
        var filtered = store.searchResults

        // Filter by type
        switch filterType {
        case .web:
            filtered = filtered.filter { $0.source == .web }
        case .local:
            filtered = filtered.filter { $0.source == .local }
        case .all:
            break
        }

        // Sort
        switch sortBy {
        case .relevance:
            filtered.sort { $0.id.uuidString < $1.id.uuidString }
        case .title:
            filtered.sort { $0.title < $1.title }
        case .type:
            filtered.sort { $0.source.rawValue < $1.source.rawValue }
        }

        return filtered
    }
}

// MARK: - Search Header

struct SearchHeaderView: View {
    let query: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Search Results")
                .font(.headline)

            Text("Query: \(query)")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding()
    }
}

// MARK: - Result Row

struct SearchResultRow: View {
    let result: AIAssistantFeature.SearchResult

    @State private var showDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Icon
                Image(systemName: iconForSource(result.source))
                    .foregroundColor(colorForSource(result.source))

                // Title
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .font(.headline)
                        .lineLimit(2)

                    if let url = result.url {
                        Text(url)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Actions
                Menu {
                    if let url = result.url {
                        Link(destination: URL(string: url) ?? URL(fileURLWithPath: url)) {
                            Label("Open", systemImage: "arrow.up.right")
                        }
                    }

                    Button(action: {
                        UIPasteboard.general.string = result.title
                    }) {
                        Label("Copy Title", systemImage: "doc.on.doc")
                    }

                    if let url = result.url {
                        Button(action: {
                            UIPasteboard.general.string = url
                        }) {
                            Label("Copy Link", systemImage: "link")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
            }

            // Snippet
            Text(result.snippet)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .padding(.leading, 24)
        }
        .padding(.vertical, 8)
    }

    private func iconForSource(_ source: AIAssistantFeature.SearchResult.SearchSource) -> String {
        switch source {
        case .web:
            return "globe"
        case .local:
            return "folder"
        }
    }

    private func colorForSource(_ source: AIAssistantFeature.SearchResult.SearchSource) -> Color {
        switch source {
        case .web:
            return .blue
        case .local:
            return .orange
        }
    }
}

// MARK: - Filter Button

struct FilterButton: View {
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

// MARK: - Pasteboard Helper

#if os(macOS)
struct UIPasteboard {
    static var general: NSPasteboard {
        NSPasteboard.general
    }

    static var string: String? {
        get {
            NSPasteboard.general.string(forType: .string)
        }
        set {
            NSPasteboard.general.clearContents()
            if let value = newValue {
                NSPasteboard.general.setString(value, forType: .string)
            }
        }
    }
}
#endif

// MARK: - Preview

#if DEBUG
struct SearchResultsView_Previews: PreviewProvider {
    static var previews: some View {
        SearchResultsView(
            store: Store(
                initialState: AIAssistantFeature.State(
                    lastSearchQuery: "SwiftUI",
                    searchResults: [
                        AIAssistantFeature.SearchResult(
                            id: UUID(),
                            title: "SwiftUI Documentation",
                            url: "https://developer.apple.com/swiftui",
                            snippet: "Declarative syntax for building user interfaces",
                            source: .web
                        ),
                        AIAssistantFeature.SearchResult(
                            id: UUID(),
                            title: "MyProject.swift",
                            url: "/Users/user/Projects/MyProject.swift",
                            snippet: "struct ContentView: View {",
                            source: .local
                        ),
                    ]
                )
            ) {
                AIAssistantFeature()
            }
        )
        .frame(width: 600, height: 500)
    }
}
#endif
