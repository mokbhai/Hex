import Foundation
import CoreData
import ComposableArchitecture

/// Service for managing notes via voice commands
/// Handles CRUD operations for notes stored in CoreData
///
/// Used by User Story 3: Voice Productivity Tools (T049)
public struct NoteService {
    // MARK: - Types

    public enum NoteServiceError: LocalizedError {
        case noteNotFound
        case invalidInput
        case saveFailed
        case deleteFailed
        case fetchFailed

        public var errorDescription: String? {
            switch self {
            case .noteNotFound:
                return "Note not found"
            case .invalidInput:
                return "Invalid note input"
            case .saveFailed:
                return "Failed to save note"
            case .deleteFailed:
                return "Failed to delete note"
            case .fetchFailed:
                return "Failed to fetch notes"
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

    /// Create a new note
    /// - Parameters:
    ///   - content: The note content
    ///   - tags: Optional array of tags
    /// - Returns: Created NoteEntity
    /// - Throws: NoteServiceError if creation fails
    public func createNote(content: String, tags: [String] = []) throws -> NoteEntity {
        guard !content.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw NoteServiceError.invalidInput
        }

        let note = NoteEntity(entity: NoteEntity.entity(), insertInto: context)
        note.content = content
        note.setTags(tags)

        try save()

        return note
    }

    /// Update an existing note
    /// - Parameters:
    ///   - id: The note ID
    ///   - content: New content (optional)
    ///   - tags: New tags (optional)
    /// - Returns: Updated NoteEntity
    /// - Throws: NoteServiceError if update fails
    public func updateNote(id: UUID, content: String? = nil, tags: [String]? = nil) throws -> NoteEntity {
        let note = try fetchNote(id: id)

        if let content = content {
            guard !content.trimmingCharacters(in: .whitespaces).isEmpty else {
                throw NoteServiceError.invalidInput
            }
            note.content = content
        }

        if let tags = tags {
            note.setTags(tags)
        }

        note.updatedAt = Date()

        try save()

        return note
    }

    /// Delete a note
    /// - Parameter id: The note ID
    /// - Throws: NoteServiceError if deletion fails
    public func deleteNote(id: UUID) throws {
        let note = try fetchNote(id: id)
        context.delete(note)
        try save()
    }

    /// Fetch a specific note
    /// - Parameter id: The note ID
    /// - Returns: NoteEntity
    /// - Throws: NoteServiceError if not found
    public func fetchNote(id: UUID) throws -> NoteEntity {
        let fetchRequest = NoteEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            let results = try context.fetch(fetchRequest)
            guard let note = results.first else {
                throw NoteServiceError.noteNotFound
            }
            return note
        } catch {
            throw NoteServiceError.fetchFailed
        }
    }

    /// Fetch all notes
    /// - Returns: Array of NoteEntity sorted by creation date (newest first)
    /// - Throws: NoteServiceError if fetch fails
    public func fetchAllNotes() throws -> [NoteEntity] {
        let fetchRequest = NoteEntity.fetchRequest()
        let sortDescriptor = NSSortDescriptor(keyPath: \NoteEntity.createdAt, ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]

        do {
            return try context.fetch(fetchRequest)
        } catch {
            throw NoteServiceError.fetchFailed
        }
    }

    /// Fetch notes with a specific tag
    /// - Parameter tag: The tag to search for
    /// - Returns: Array of matching notes
    /// - Throws: NoteServiceError if fetch fails
    public func fetchNotesByTag(_ tag: String) throws -> [NoteEntity] {
        let allNotes = try fetchAllNotes()
        return allNotes.filter { $0.tags.contains(tag) }
    }

    /// Search notes by content
    /// - Parameter searchText: Text to search for
    /// - Returns: Array of matching notes
    /// - Throws: NoteServiceError if search fails
    public func searchNotes(searchText: String) throws -> [NoteEntity] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            return try fetchAllNotes()
        }

        let fetchRequest = NoteEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "content CONTAINS[cd] %@", searchText)

        let sortDescriptor = NSSortDescriptor(keyPath: \NoteEntity.createdAt, ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]

        do {
            return try context.fetch(fetchRequest)
        } catch {
            throw NoteServiceError.fetchFailed
        }
    }

    // MARK: - Batch Operations

    /// Delete all notes
    /// - Returns: Count of deleted notes
    /// - Throws: NoteServiceError if deletion fails
    public func deleteAllNotes() throws -> Int {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Note")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        do {
            let result = try context.execute(deleteRequest)
            try save()
            return (result as? NSBatchDeleteResult)?.result as? Int ?? 0
        } catch {
            throw NoteServiceError.deleteFailed
        }
    }

    /// Get note count
    /// - Returns: Total number of notes
    /// - Throws: NoteServiceError if count fails
    public func getNoteCount() throws -> Int {
        let fetchRequest = NoteEntity.fetchRequest()

        do {
            return try context.count(for: fetchRequest)
        } catch {
            throw NoteServiceError.fetchFailed
        }
    }

    /// Get recent notes
    /// - Parameter limit: Maximum number of notes to return
    /// - Returns: Array of recent notes
    /// - Throws: NoteServiceError if fetch fails
    public func getRecentNotes(limit: Int = 10) throws -> [NoteEntity] {
        let fetchRequest = NoteEntity.fetchRequest()
        let sortDescriptor = NSSortDescriptor(keyPath: \NoteEntity.createdAt, ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        fetchRequest.fetchLimit = limit

        do {
            return try context.fetch(fetchRequest)
        } catch {
            throw NoteServiceError.fetchFailed
        }
    }

    /// Get all unique tags from all notes
    /// - Returns: Array of tag strings
    /// - Throws: NoteServiceError if fetch fails
    public func getAllTags() throws -> [String] {
        let notes = try fetchAllNotes()
        var tags = Set<String>()

        for note in notes {
            tags.formUnion(note.tags)
        }

        return Array(tags).sorted()
    }

    // MARK: - Private Helpers

    private func save() throws {
        do {
            try context.save()
        } catch {
            throw NoteServiceError.saveFailed
        }
    }

    // MARK: - Export

    /// Export notes to plain text
    /// - Parameter notes: Array of notes to export
    /// - Returns: Formatted text string
    public static func exportToText(_ notes: [NoteEntity]) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        return notes.enumerated().map { index, note in
            let dateStr = formatter.string(from: note.createdAt)
            let tagsStr = note.tags.isEmpty ? "" : "Tags: \(note.tags.joined(separator: ", "))\n"
            return "[\(index + 1)] \(dateStr)\n\(tagsStr)\(note.content)\n"
        }.joined(separator: "\n---\n\n")
    }

    /// Get summary statistics
    /// - Parameter notes: Array of notes
    /// - Returns: Dictionary with statistics
    public static func getStatistics(_ notes: [NoteEntity]) -> [String: Any] {
        let totalNotes = notes.count
        let totalWords = notes.reduce(0) { $0 + $1.content.split(separator: " ").count }
        let totalCharacters = notes.reduce(0) { $0 + $1.content.count }

        var tagFrequency: [String: Int] = [:]
        for note in notes {
            for tag in note.tags {
                tagFrequency[tag, default: 0] += 1
            }
        }

        return [
            "totalNotes": totalNotes,
            "totalWords": totalWords,
            "totalCharacters": totalCharacters,
            "tagFrequency": tagFrequency,
            "averageWordsPerNote": totalNotes > 0 ? totalWords / totalNotes : 0,
        ]
    }
}

// MARK: - TCA Integration

extension DependencyValues {
    var noteService: NoteService {
        get { self[NoteServiceKey.self] }
        set { self[NoteServiceKey.self] = newValue }
    }
}

private enum NoteServiceKey: DependencyKey {
    static let liveValue = NoteService(context: NSManagedObjectContext(concurrencyType: .mainThreadPrivateQueueConcurrencyType))
    static let previewValue = NoteService(context: NSManagedObjectContext(concurrencyType: .mainThreadPrivateQueueConcurrencyType))
    static let testValue = NoteService(context: NSManagedObjectContext(concurrencyType: .mainThreadPrivateQueueConcurrencyType))
}
