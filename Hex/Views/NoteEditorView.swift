import SwiftUI

/// View for creating and editing notes via voice commands
/// Provides text input and tag management for notes
///
/// Used by User Story 3: Voice Productivity Tools (T054)
struct NoteEditorView: View {
    @State private var content: String = ""
    @State private var tags: [String] = []
    @State private var tagInput: String = ""
    @State private var showingTagInput = false

    let onSave: (String, [String]) -> Void
    let onCancel: () -> Void
    var isEditingExisting: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Content editor
                VStack(alignment: .leading, spacing: 8) {
                    Label("Note Content", systemImage: "doc.text")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)

                    TextEditor(text: $content)
                        .frame(minHeight: 200)
                        .padding(12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .font(.system(size: 14))
                }

                Divider()

                // Tags section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Tags", systemImage: "tag")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)

                        Spacer()

                        Button(action: { showingTagInput.toggle() }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }

                    if !tags.isEmpty {
                        Wrap(spacing: 8) {
                            ForEach(tags, id: \.self) { tag in
                                HStack(spacing: 6) {
                                    Text(tag)
                                        .font(.system(size: 12))

                                    Button(action: { removeTag(tag) }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(6)
                            }
                        }
                    } else {
                        Text("No tags added")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    if showingTagInput {
                        HStack {
                            TextField("New tag", text: $tagInput)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))

                            Button(action: addTag) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }

                Spacer()

                // Action buttons
                HStack(spacing: 12) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                    }

                    Button(action: save) {
                        Text(isEditingExisting ? "Update" : "Save Note")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(content.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(16)
            .navigationTitle(isEditingExisting ? "Edit Note" : "New Note")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty && !tags.contains(trimmed) else { return }

        tags.append(trimmed)
        tagInput = ""
        showingTagInput = false
    }

    private func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }

    private func save() {
        let trimmedContent = content.trimmingCharacters(in: .whitespaces)
        guard !trimmedContent.isEmpty else { return }

        onSave(trimmedContent, tags)
    }
}

/// List view for displaying notes
struct NoteListView: View {
    let notes: [NoteEntity]
    let onSelectNote: (NoteEntity) -> Void
    let onDeleteNote: (UUID) -> Void
    let onSearchText: (String) -> Void

    @State private var searchText = ""

    var filteredNotes: [NoteEntity] {
        searchText.isEmpty ? notes : notes.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List {
            ForEach(filteredNotes) { note in
                NoteRowView(note: note, onTapGesture: { onSelectNote(note) })
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive, action: { onDeleteNote(note.id) }) {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .searchable(text: $searchText, prompt: "Search notes")
        .onChange(of: searchText) { onSearchText($0) }
    }
}

/// Individual note row for list display
struct NoteRowView: View {
    let note: NoteEntity
    let onTapGesture: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Content preview
            Text(note.content)
                .lineLimit(3)
                .font(.system(size: 14))
                .foregroundColor(.primary)

            // Meta information
            HStack(spacing: 12) {
                Label(formatDate(note.createdAt), systemImage: "calendar")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                if !note.tags.isEmpty {
                    Label(note.tags.count.description, systemImage: "tag")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            // Tags preview
            if !note.tags.isEmpty {
                Wrap(spacing: 4) {
                    ForEach(note.tags.prefix(3), id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }

                    if note.tags.count > 3 {
                        Text("+\(note.tags.count - 3)")
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.gray.opacity(0.1))
                            .foregroundColor(.secondary)
                            .cornerRadius(4)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTapGesture)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

/// Note detail view
struct NoteDetailView: View {
    let note: NoteEntity
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isCopied = false

    var body: some View {
        VStack(spacing: 16) {
            // Content
            Text(note.content)
                .font(.system(size: 14))
                .lineLimit(nil)
                .textSelection(.enabled)

            Spacer()

            // Meta
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Created", systemImage: "calendar")
                    Spacer()
                    Text(formatDate(note.createdAt))
                }
                .font(.system(size: 12))
                .foregroundColor(.secondary)

                if note.createdAt != note.updatedAt {
                    HStack {
                        Label("Updated", systemImage: "clock")
                        Spacer()
                        Text(formatDate(note.updatedAt))
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                }
            }

            // Tags
            if !note.tags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)

                    Wrap(spacing: 6) {
                        ForEach(note.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(size: 11))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                    }
                }
            }

            // Actions
            HStack(spacing: 12) {
                Button(action: { copyToClipboard() }) {
                    Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                    Text(isCopied ? "Copied" : "Copy")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(8)

                Button(action: onEdit) {
                    Image(systemName: "pencil")
                    Text("Edit")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.green.opacity(0.1))
                .foregroundColor(.green)
                .cornerRadius(8)

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(16)
    }

    private func copyToClipboard() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(note.content, forType: .string)
        #endif

        withAnimation {
            isCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                isCopied = false
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    NoteEditorView(
        onSave: { _, _ in },
        onCancel: {}
    )
}
