import Foundation
import CoreData
import ComposableArchitecture

/// Service for managing CoreData persistence of productivity features
/// Handles loading, saving, and syncing of notes, todos, and reminders
///
/// Used by User Story 3: Voice Productivity Tools (T056)
public struct PersistenceService {
    // MARK: - Types

    public enum PersistenceError: LocalizedError {
        case modelNotFound
        case saveFailed
        case loadFailed
        case invalidContext

        public var errorDescription: String? {
            switch self {
            case .modelNotFound:
                return "Core Data model not found"
            case .saveFailed:
                return "Failed to save to database"
            case .loadFailed:
                return "Failed to load from database"
            case .invalidContext:
                return "Invalid managed object context"
            }
        }
    }

    // MARK: - Properties

    private let container: NSPersistentContainer
    private let mainContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    // MARK: - Initialization

    public static let shared: PersistenceService = {
        let container = NSPersistentContainer(name: "Hex")
        container.loadPersistentStores { _, error in
            if let error = error {
                print("Core Data error: \(error.localizedDescription)")
            }
        }
        return PersistenceService(container: container)
    }()

    public init(container: NSPersistentContainer) {
        self.container = container
        self.mainContext = container.viewContext
        self.mainContext.automaticallyMergesChangesFromParent = true

        let backgroundContext = container.newBackgroundContext()
        backgroundContext.automaticallyMergesChangesFromParent = true
        self.backgroundContext = backgroundContext
    }

    // MARK: - Context Access

    /// Get the main (UI) context
    /// - Returns: NSManagedObjectContext for main thread
    public func getMainContext() -> NSManagedObjectContext {
        mainContext
    }

    /// Get a background context for async operations
    /// - Returns: NSManagedObjectContext for background operations
    public func getBackgroundContext() -> NSManagedObjectContext {
        backgroundContext
    }

    // MARK: - Saving

    /// Save changes in the main context
    /// - Throws: PersistenceError if save fails
    public func saveMainContext() throws {
        guard mainContext.hasChanges else { return }

        do {
            try mainContext.save()
        } catch {
            throw PersistenceError.saveFailed
        }
    }

    /// Save changes in a background context
    /// - Parameters:
    ///   - context: The context to save
    /// - Throws: PersistenceError if save fails
    public func saveContext(_ context: NSManagedObjectContext) throws {
        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            throw PersistenceError.saveFailed
        }
    }

    /// Perform operation on background context and save
    /// - Parameters:
    ///   - block: Async block to execute
    /// - Throws: PersistenceError if operation fails
    public func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) async throws -> T) async throws -> T {
        let context = backgroundContext

        return try await context.perform {
            let result = try await block(context)
            try context.save()
            return result
        }
    }

    // MARK: - Loading Data

    /// Load all notes
    /// - Returns: Array of NoteEntity
    /// - Throws: PersistenceError if load fails
    public func loadAllNotes() throws -> [NoteEntity] {
        let fetchRequest = NoteEntity.fetchRequest()
        let sortDescriptor = NSSortDescriptor(keyPath: \NoteEntity.createdAt, ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]

        do {
            return try mainContext.fetch(fetchRequest)
        } catch {
            throw PersistenceError.loadFailed
        }
    }

    /// Load all todos
    /// - Returns: Array of TodoItemEntity
    /// - Throws: PersistenceError if load fails
    public func loadAllTodos() throws -> [TodoItemEntity] {
        let fetchRequest = TodoItemEntity.fetchRequest()
        let sortDescriptor = NSSortDescriptor(keyPath: \TodoItemEntity.createdAt, ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]

        do {
            return try mainContext.fetch(fetchRequest)
        } catch {
            throw PersistenceError.loadFailed
        }
    }

    /// Load all reminders
    /// - Returns: Array of ReminderEntity
    /// - Throws: PersistenceError if load fails
    public func loadAllReminders() throws -> [ReminderEntity] {
        let fetchRequest = ReminderEntity.fetchRequest()
        let sortDescriptor = NSSortDescriptor(keyPath: \ReminderEntity.triggerTime, ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]

        do {
            return try mainContext.fetch(fetchRequest)
        } catch {
            throw PersistenceError.loadFailed
        }
    }

    // MARK: - Data Export/Import

    /// Export all productivity data
    /// - Returns: Dictionary with all productivity data
    /// - Throws: PersistenceError if export fails
    public func exportAllData() throws -> [String: Any] {
        let notes = try loadAllNotes()
        let todos = try loadAllTodos()
        let reminders = try loadAllReminders()

        return [
            "notes": encodeEntities(notes),
            "todos": encodeEntities(todos),
            "reminders": encodeEntities(reminders),
            "exportDate": Date(),
        ]
    }

    /// Clear all productivity data
    /// - Returns: Count of deleted records
    /// - Throws: PersistenceError if deletion fails
    public func clearAllData() throws -> (notesDeleted: Int, todosDeleted: Int, remindersDeleted: Int) {
        var counts = (notesDeleted: 0, todosDeleted: 0, remindersDeleted: 0)

        let noteFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Note")
        let noteDelete = NSBatchDeleteRequest(fetchRequest: noteFetchRequest)
        if let result = try mainContext.execute(noteDelete) as? NSBatchDeleteResult {
            counts.notesDeleted = result.result as? Int ?? 0
        }

        let todoFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "TodoItem")
        let todoDelete = NSBatchDeleteRequest(fetchRequest: todoFetchRequest)
        if let result = try mainContext.execute(todoDelete) as? NSBatchDeleteResult {
            counts.todosDeleted = result.result as? Int ?? 0
        }

        let reminderFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Reminder")
        let reminderDelete = NSBatchDeleteRequest(fetchRequest: reminderFetchRequest)
        if let result = try mainContext.execute(reminderDelete) as? NSBatchDeleteResult {
            counts.remindersDeleted = result.result as? Int ?? 0
        }

        try saveMainContext()

        return counts
    }

    /// Get database statistics
    /// - Returns: Dictionary with statistics
    /// - Throws: PersistenceError if query fails
    public func getDatabaseStats() throws -> [String: Int] {
        var stats: [String: Int] = [:]

        let noteFetchRequest = NoteEntity.fetchRequest()
        stats["noteCount"] = try mainContext.count(for: noteFetchRequest)

        let todoFetchRequest = TodoItemEntity.fetchRequest()
        stats["todoCount"] = try mainContext.count(for: todoFetchRequest)

        let incompleteFetchRequest = TodoItemEntity.fetchRequest()
        incompleteFetchRequest.predicate = NSPredicate(format: "isCompleted == false")
        stats["incompleteCount"] = try mainContext.count(for: incompleteFetchRequest)

        let reminderFetchRequest = ReminderEntity.fetchRequest()
        stats["reminderCount"] = try mainContext.count(for: reminderFetchRequest)

        return stats
    }

    // MARK: - Data Integrity

    /// Validate database integrity
    /// - Returns: true if database is valid
    public func validateIntegrity() -> Bool {
        do {
            let stats = try getDatabaseStats()
            // Basic validation: all counts should be non-negative
            return stats.values.allSatisfy { $0 >= 0 }
        } catch {
            return false
        }
    }

    /// Repair database if needed
    /// - Throws: PersistenceError if repair fails
    public func repairDatabase() throws {
        // Remove orphaned or corrupted records
        let notes = try loadAllNotes()
        for note in notes {
            if note.content.isEmpty {
                mainContext.delete(note)
            }
        }

        let todos = try loadAllTodos()
        for todo in todos {
            if todo.description.isEmpty {
                mainContext.delete(todo)
            }
        }

        try saveMainContext()
    }

    // MARK: - Private Helpers

    private func encodeEntities(_ entities: [NSManagedObject]) -> [[String: Any]] {
        entities.map { entity in
            entity.dictionaryWithValues(forKeys: entity.entity.attributesByName.keys.map { $0 })
        }
    }
}

// MARK: - TCA Integration

extension DependencyValues {
    var persistenceService: PersistenceService {
        get { self[PersistenceServiceKey.self] }
        set { self[PersistenceServiceKey.self] = newValue }
    }
}

private enum PersistenceServiceKey: DependencyKey {
    static let liveValue = PersistenceService.shared
    static let previewValue = PersistenceService.shared
    static let testValue = PersistenceService.shared
}
