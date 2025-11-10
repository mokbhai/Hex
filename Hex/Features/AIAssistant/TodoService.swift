import Foundation
import CoreData
import ComposableArchitecture

/// Service for managing todo items via voice commands
/// Handles CRUD operations for todos stored in CoreData
///
/// Used by User Story 3: Voice Productivity Tools (T050)
public struct TodoService {
    // MARK: - Types

    public enum TodoServiceError: LocalizedError {
        case todoNotFound
        case invalidInput
        case saveFailed
        case deleteFailed
        case fetchFailed

        public var errorDescription: String? {
            switch self {
            case .todoNotFound:
                return "Todo item not found"
            case .invalidInput:
                return "Invalid todo input"
            case .saveFailed:
                return "Failed to save todo"
            case .deleteFailed:
                return "Failed to delete todo"
            case .fetchFailed:
                return "Failed to fetch todos"
            }
        }
    }

    public enum TodoPriority: Int32, CaseIterable {
        case low = 1
        case normal = 2
        case high = 3

        public var displayName: String {
            switch self {
            case .low:
                return "Low"
            case .normal:
                return "Normal"
            case .high:
                return "High"
            }
        }

        public var emoji: String {
            switch self {
            case .low:
                return "○"
            case .normal:
                return "◑"
            case .high:
                return "●"
            }
        }
    }

    // MARK: - Properties

    private let context: NSManagedObjectContext

    // MARK: - Initialization

    public init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - CRUD Operations

    /// Create a new todo
    /// - Parameters:
    ///   - description: The todo description
    ///   - priority: Priority level (default: normal)
    ///   - dueDate: Optional due date
    /// - Returns: Created TodoItemEntity
    /// - Throws: TodoServiceError if creation fails
    public func createTodo(
        description: String,
        priority: TodoPriority = .normal,
        dueDate: Date? = nil
    ) throws -> TodoItemEntity {
        guard !description.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw TodoServiceError.invalidInput
        }

        let todo = TodoItemEntity(entity: TodoItemEntity.entity(), insertInto: context)
        todo.description = description
        todo.priority = priority.rawValue
        todo.dueDate = dueDate
        todo.isCompleted = false

        try save()

        return todo
    }

    /// Update a todo
    /// - Parameters:
    ///   - id: The todo ID
    ///   - description: New description (optional)
    ///   - priority: New priority (optional)
    ///   - dueDate: New due date (optional)
    /// - Returns: Updated TodoItemEntity
    /// - Throws: TodoServiceError if update fails
    public func updateTodo(
        id: UUID,
        description: String? = nil,
        priority: TodoPriority? = nil,
        dueDate: Date? = nil
    ) throws -> TodoItemEntity {
        let todo = try fetchTodo(id: id)

        if let description = description {
            guard !description.trimmingCharacters(in: .whitespaces).isEmpty else {
                throw TodoServiceError.invalidInput
            }
            todo.description = description
        }

        if let priority = priority {
            todo.priority = priority.rawValue
        }

        if dueDate != nil {
            todo.dueDate = dueDate
        }

        try save()

        return todo
    }

    /// Mark a todo as completed
    /// - Parameter id: The todo ID
    /// - Returns: Updated TodoItemEntity
    /// - Throws: TodoServiceError if operation fails
    public func completeTodo(id: UUID) throws -> TodoItemEntity {
        let todo = try fetchTodo(id: id)
        todo.isCompleted = true
        todo.completedAt = Date()

        try save()

        return todo
    }

    /// Mark a todo as incomplete
    /// - Parameter id: The todo ID
    /// - Returns: Updated TodoItemEntity
    /// - Throws: TodoServiceError if operation fails
    public func incompleteTodo(id: UUID) throws -> TodoItemEntity {
        let todo = try fetchTodo(id: id)
        todo.isCompleted = false
        todo.completedAt = nil

        try save()

        return todo
    }

    /// Delete a todo
    /// - Parameter id: The todo ID
    /// - Throws: TodoServiceError if deletion fails
    public func deleteTodo(id: UUID) throws {
        let todo = try fetchTodo(id: id)
        context.delete(todo)
        try save()
    }

    /// Fetch a specific todo
    /// - Parameter id: The todo ID
    /// - Returns: TodoItemEntity
    /// - Throws: TodoServiceError if not found
    public func fetchTodo(id: UUID) throws -> TodoItemEntity {
        let fetchRequest = TodoItemEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            let results = try context.fetch(fetchRequest)
            guard let todo = results.first else {
                throw TodoServiceError.todoNotFound
            }
            return todo
        } catch {
            throw TodoServiceError.fetchFailed
        }
    }

    /// Fetch all todos
    /// - Returns: Array of TodoItemEntity sorted by creation date
    /// - Throws: TodoServiceError if fetch fails
    public func fetchAllTodos() throws -> [TodoItemEntity] {
        let fetchRequest = TodoItemEntity.fetchRequest()
        let sortDescriptor = NSSortDescriptor(keyPath: \TodoItemEntity.createdAt, ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]

        do {
            return try context.fetch(fetchRequest)
        } catch {
            throw TodoServiceError.fetchFailed
        }
    }

    /// Fetch incomplete todos
    /// - Returns: Array of incomplete todos
    /// - Throws: TodoServiceError if fetch fails
    public func fetchIncompleteTodos() throws -> [TodoItemEntity] {
        let fetchRequest = TodoItemEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isCompleted == false")

        let sortDescriptors = [
            NSSortDescriptor(keyPath: \TodoItemEntity.priority, ascending: false),
            NSSortDescriptor(keyPath: \TodoItemEntity.dueDate, ascending: true),
            NSSortDescriptor(keyPath: \TodoItemEntity.createdAt, ascending: false),
        ]
        fetchRequest.sortDescriptors = sortDescriptors

        do {
            return try context.fetch(fetchRequest)
        } catch {
            throw TodoServiceError.fetchFailed
        }
    }

    /// Fetch completed todos
    /// - Returns: Array of completed todos
    /// - Throws: TodoServiceError if fetch fails
    public func fetchCompletedTodos() throws -> [TodoItemEntity] {
        let fetchRequest = TodoItemEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isCompleted == true")

        let sortDescriptor = NSSortDescriptor(keyPath: \TodoItemEntity.completedAt, ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]

        do {
            return try context.fetch(fetchRequest)
        } catch {
            throw TodoServiceError.fetchFailed
        }
    }

    /// Fetch todos with a specific priority
    /// - Parameter priority: The priority level
    /// - Returns: Array of matching todos
    /// - Throws: TodoServiceError if fetch fails
    public func fetchTodosByPriority(_ priority: TodoPriority) throws -> [TodoItemEntity] {
        let fetchRequest = TodoItemEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "priority == %d", priority.rawValue)

        let sortDescriptor = NSSortDescriptor(keyPath: \TodoItemEntity.createdAt, ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]

        do {
            return try context.fetch(fetchRequest)
        } catch {
            throw TodoServiceError.fetchFailed
        }
    }

    /// Fetch todos due by a specific date
    /// - Parameter date: The due date cutoff
    /// - Returns: Array of todos due on or before the date
    /// - Throws: TodoServiceError if fetch fails
    public func fetchTodosDueBy(_ date: Date) throws -> [TodoItemEntity] {
        let fetchRequest = TodoItemEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "dueDate <= %@", date as NSDate)

        let sortDescriptor = NSSortDescriptor(keyPath: \TodoItemEntity.dueDate, ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]

        do {
            return try context.fetch(fetchRequest)
        } catch {
            throw TodoServiceError.fetchFailed
        }
    }

    // MARK: - Batch Operations

    /// Delete all todos
    /// - Returns: Count of deleted todos
    /// - Throws: TodoServiceError if deletion fails
    public func deleteAllTodos() throws -> Int {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "TodoItem")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        do {
            let result = try context.execute(deleteRequest)
            try save()
            return (result as? NSBatchDeleteResult)?.result as? Int ?? 0
        } catch {
            throw TodoServiceError.deleteFailed
        }
    }

    /// Complete all todos
    /// - Returns: Count of completed todos
    /// - Throws: TodoServiceError if operation fails
    public func completeAllTodos() throws -> Int {
        let todos = try fetchIncompleteTodos()

        for todo in todos {
            todo.isCompleted = true
            todo.completedAt = Date()
        }

        try save()

        return todos.count
    }

    /// Get todo count
    /// - Returns: Total number of todos
    /// - Throws: TodoServiceError if count fails
    public func getTodoCount() throws -> Int {
        let fetchRequest = TodoItemEntity.fetchRequest()

        do {
            return try context.count(for: fetchRequest)
        } catch {
            throw TodoServiceError.fetchFailed
        }
    }

    /// Get incomplete count
    /// - Returns: Count of incomplete todos
    /// - Throws: TodoServiceError if count fails
    public func getIncompleteCount() throws -> Int {
        let fetchRequest = TodoItemEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isCompleted == false")

        do {
            return try context.count(for: fetchRequest)
        } catch {
            throw TodoServiceError.fetchFailed
        }
    }

    /// Get completion percentage
    /// - Returns: Percentage of completed todos (0-100)
    /// - Throws: TodoServiceError if calculation fails
    public func getCompletionPercentage() throws -> Int {
        let total = try getTodoCount()
        guard total > 0 else { return 0 }

        let fetchRequest = TodoItemEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isCompleted == true")

        do {
            let completed = try context.count(for: fetchRequest)
            return Int((Double(completed) / Double(total)) * 100)
        } catch {
            throw TodoServiceError.fetchFailed
        }
    }

    // MARK: - Private Helpers

    private func save() throws {
        do {
            try context.save()
        } catch {
            throw TodoServiceError.saveFailed
        }
    }

    // MARK: - Export

    /// Export todos to plain text
    /// - Parameter todos: Array of todos to export
    /// - Returns: Formatted text string
    public static func exportToText(_ todos: [TodoItemEntity]) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        return todos.enumerated().map { index, todo in
            let priority = TodoPriority(rawValue: todo.priority) ?? .normal
            let priorityStr = "\(priority.emoji) \(priority.displayName)"
            let checkbox = todo.isCompleted ? "☑" : "☐"
            let dueStr = todo.dueDate.map { " (Due: \(formatter.string(from: $0)))" } ?? ""

            return "\(checkbox) \(todo.description)\n   \(priorityStr)\(dueStr)"
        }.joined(separator: "\n")
    }

    /// Get summary statistics
    /// - Parameter todos: Array of todos
    /// - Returns: Dictionary with statistics
    public static func getStatistics(_ todos: [TodoItemEntity]) -> [String: Any] {
        let total = todos.count
        let completed = todos.filter { $0.isCompleted }.count
        let incomplete = total - completed
        let completionPercentage = total > 0 ? Int((Double(completed) / Double(total)) * 100) : 0

        var priorityCounts: [String: Int] = [:]
        for todo in todos {
            let priority = TodoPriority(rawValue: todo.priority) ?? .normal
            priorityCounts[priority.displayName, default: 0] += 1
        }

        let overdue = todos.filter { !$0.isCompleted && $0.dueDate ?? Date.distantFuture < Date() }.count

        return [
            "total": total,
            "completed": completed,
            "incomplete": incomplete,
            "completionPercentage": completionPercentage,
            "overdue": overdue,
            "priorityCounts": priorityCounts,
        ]
    }
}

// MARK: - TCA Integration

extension DependencyValues {
    var todoService: TodoService {
        get { self[TodoServiceKey.self] }
        set { self[TodoServiceKey.self] = newValue }
    }
}

private enum TodoServiceKey: DependencyKey {
    static let liveValue = TodoService(context: NSManagedObjectContext(concurrencyType: .mainThreadPrivateQueueConcurrencyType))
    static let previewValue = TodoService(context: NSManagedObjectContext(concurrencyType: .mainThreadPrivateQueueConcurrencyType))
    static let testValue = TodoService(context: NSManagedObjectContext(concurrencyType: .mainThreadPrivateQueueConcurrencyType))
}
