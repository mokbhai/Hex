import SwiftUI

/// View for managing todo lists via voice commands
/// Provides todo creation, editing, and completion tracking
///
/// Used by User Story 3: Voice Productivity Tools (T055)
struct TodoListView: View {
    @State private var showingNewTodo = false
    @State private var newTodoDescription = ""
    @State private var selectedPriority: TodoService.TodoPriority = .normal
    @State private var selectedDueDate: Date?
    @State private var filterMode: FilterMode = .incomplete
    @State private var searchText = ""

    let todos: [TodoItemEntity]
    let onCreateTodo: (String, TodoService.TodoPriority, Date?) -> Void
    let onCompleteTodo: (UUID) -> Void
    let onDeleteTodo: (UUID) -> Void
    let onUpdateTodo: (UUID, String, TodoService.TodoPriority, Date?) -> Void

    enum FilterMode {
        case all
        case incomplete
        case completed
        case highPriority
    }

    var filteredTodos: [TodoItemEntity] {
        var result = todos

        // Apply filter
        switch filterMode {
        case .all:
            break
        case .incomplete:
            result = result.filter { !$0.isCompleted }
        case .completed:
            result = result.filter { $0.isCompleted }
        case .highPriority:
            result = result.filter { !$0.isCompleted && $0.priority == 3 }
        }

        // Apply search
        if !searchText.isEmpty {
            result = result.filter { $0.description.localizedCaseInsensitiveContains(searchText) }
        }

        // Sort by priority and due date
        result.sort { a, b in
            if a.isCompleted != b.isCompleted {
                return !a.isCompleted
            }
            if a.priority != b.priority {
                return a.priority > b.priority
            }
            if let aDate = a.dueDate, let bDate = b.dueDate {
                return aDate < bDate
            }
            return a.createdAt < b.createdAt
        }

        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach([FilterMode.all, .incomplete, .completed, .highPriority], id: \.self) { mode in
                            FilterPill(
                                label: modeLabel(mode),
                                isSelected: filterMode == mode,
                                action: { filterMode = mode }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.05))

                // Search
                SearchBar(text: $searchText, placeholder: "Search todos")
                    .padding(16)

                // Todo list
                if filteredTodos.isEmpty {
                    EmptyStateView(
                        title: "No todos",
                        message: filterMode == .incomplete ? "Add a new todo to get started" : "No todos match your filter",
                        systemImage: "checklist"
                    )
                } else {
                    List {
                        ForEach(filteredTodos) { todo in
                            TodoRowView(
                                todo: todo,
                                onToggle: { onCompleteTodo(todo.id) },
                                onDelete: { onDeleteTodo(todo.id) },
                                onUpdate: { desc, priority, dueDate in
                                    onUpdateTodo(todo.id, desc, priority, dueDate)
                                }
                            )
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Todos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button(action: { showingNewTodo.toggle() }) {
                    Image(systemName: "plus.circle.fill")
                }
            }
            .sheet(isPresented: $showingNewTodo) {
                NewTodoView(
                    description: $newTodoDescription,
                    priority: $selectedPriority,
                    dueDate: $selectedDueDate,
                    onSave: {
                        onCreateTodo(newTodoDescription, selectedPriority, selectedDueDate)
                        newTodoDescription = ""
                        selectedPriority = .normal
                        selectedDueDate = nil
                        showingNewTodo = false
                    },
                    onCancel: { showingNewTodo = false }
                )
            }
        }
    }

    private func modeLabel(_ mode: FilterMode) -> String {
        switch mode {
        case .all:
            return "All"
        case .incomplete:
            return "To Do"
        case .completed:
            return "Done"
        case .highPriority:
            return "⚡ High"
        }
    }
}

/// Individual todo row
struct TodoRowView: View {
    let todo: TodoItemEntity
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onUpdate: (String, TodoService.TodoPriority, Date?) -> Void

    @State private var isEditing = false

    var priority: TodoService.TodoPriority {
        TodoService.TodoPriority(rawValue: todo.priority) ?? .normal
    }

    var isOverdue: Bool {
        !todo.isCompleted && todo.dueDate.map { $0 < Date() } ?? false
    }

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(todo.isCompleted ? .green : .gray)
            }

            VStack(alignment: .leading, spacing: 4) {
                // Description
                Text(todo.description)
                    .strikethrough(todo.isCompleted)
                    .foregroundColor(todo.isCompleted ? .secondary : .primary)
                    .lineLimit(2)

                // Meta info
                HStack(spacing: 8) {
                    // Priority badge
                    Text(priority.emoji)
                        .font(.system(size: 10))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(priorityColor.opacity(0.2))
                        .foregroundColor(priorityColor)
                        .cornerRadius(3)

                    // Due date
                    if let dueDate = todo.dueDate {
                        Label(formatDate(dueDate), systemImage: "calendar")
                            .font(.system(size: 10))
                            .foregroundColor(isOverdue ? .red : .secondary)
                    }

                    // Completion status
                    if todo.isCompleted, let completedAt = todo.completedAt {
                        Label("Done", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                    }
                }
            }

            Spacer()

            // Menu
            Menu {
                Button("Edit") {
                    isEditing = true
                }

                Button("Toggle", action: onToggle)

                if !todo.isCompleted {
                    Button("Set High Priority") {
                        onUpdate(todo.description, .high, todo.dueDate)
                    }
                }

                Button("Delete", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
        .sheet(isPresented: $isEditing) {
            EditTodoView(
                todo: todo,
                onSave: { desc, priority, dueDate in
                    onUpdate(desc, priority, dueDate)
                    isEditing = false
                },
                onCancel: { isEditing = false }
            )
        }
    }

    private var priorityColor: Color {
        switch priority {
        case .low:
            return .gray
        case .normal:
            return .blue
        case .high:
            return .red
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

/// New todo creation view
struct NewTodoView: View {
    @Binding var description: String
    @Binding var priority: TodoService.TodoPriority
    @Binding var dueDate: Date?
    let onSave: () -> Void
    let onCancel: () -> Void

    @State private var showDueDatePicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Todo description", text: $description)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 14))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Priority")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)

                    Picker("Priority", selection: $priority) {
                        ForEach(TodoService.TodoPriority.allCases, id: \.self) { p in
                            Text("\(p.emoji) \(p.displayName)").tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Due Date")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)

                        Spacer()

                        if dueDate != nil {
                            Button(action: { dueDate = nil }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }

                    Button(action: { showDueDatePicker.toggle() }) {
                        HStack {
                            Image(systemName: "calendar")
                            Text(dueDate.map { formatDate($0) } ?? "Set date")
                            Spacer()
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }

                    if showDueDatePicker {
                        DatePicker(
                            "Due Date",
                            selection: Binding(
                                get: { dueDate ?? Date() },
                                set: { dueDate = $0 }
                            ),
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.graphical)
                    }
                }

                Spacer()

                HStack(spacing: 12) {
                    Button("Cancel", action: onCancel)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)

                    Button("Create", action: onSave)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .disabled(description.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(16)
            .navigationTitle("New Todo")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

/// Edit todo view
struct EditTodoView: View {
    let todo: TodoItemEntity
    let onSave: (String, TodoService.TodoPriority, Date?) -> Void
    let onCancel: () -> Void

    @State private var description: String = ""
    @State private var priority: TodoService.TodoPriority = .normal
    @State private var dueDate: Date?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Todo description", text: $description)
                    .textFieldStyle(.roundedBorder)

                Picker("Priority", selection: $priority) {
                    ForEach(TodoService.TodoPriority.allCases, id: \.self) { p in
                        Text("\(p.emoji) \(p.displayName)").tag(p)
                    }
                }
                .pickerStyle(.segmented)

                Spacer()

                HStack(spacing: 12) {
                    Button("Cancel", action: onCancel)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)

                    Button("Save") {
                        onSave(description, priority, dueDate)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            .padding(16)
            .navigationTitle("Edit Todo")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                description = todo.description
                priority = TodoService.TodoPriority(rawValue: todo.priority) ?? .normal
                dueDate = todo.dueDate
            }
        }
    }
}

/// Helper views
struct FilterPill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(6)
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)

            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text(title)
                .font(.system(size: 18, weight: .semibold))

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    TodoListView(
        todos: [],
        onCreateTodo: { _, _, _ in },
        onCompleteTodo: { _ in },
        onDeleteTodo: { _ in },
        onUpdateTodo: { _, _, _, _ in }
    )
}
