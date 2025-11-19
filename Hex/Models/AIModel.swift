import Foundation
import CoreData

/// CoreData model for downloaded AI models
public final class AIModelEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var displayName: String
    @NSManaged public var version: String
    @NSManaged public var size: Int64
    @NSManaged public var localPath: String?
    @NSManaged public var downloadDate: Date?
    @NSManaged public var lastUsed: Date?
    @NSManaged public var capabilitiesData: Data? // JSON-encoded array of capabilities
    @NSManaged public var isDownloaded: Bool

    override public func awakeFromInsert() {
        super.awakeFromInsert()
        setValue(UUID(), forKey: "id")
    }
}

extension AIModelEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<AIModelEntity> {
        return NSFetchRequest<AIModelEntity>(entityName: "AIModel")
    }

    /// Get capabilities as array of strings
    public var capabilities: [String] {
        guard let data = capabilitiesData,
              let array = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return array
    }

    /// Set capabilities from array of strings
    public func setCapabilities(_ capabilities: [String]) {
        if let data = try? JSONEncoder().encode(capabilities) {
            capabilitiesData = data
        }
    }
}

/// CoreData model for user notes
public final class NoteEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var content: String
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var tagsData: Data? // JSON-encoded array of tags

    override public func awakeFromInsert() {
        super.awakeFromInsert()
        setValue(UUID(), forKey: "id")
        setValue(Date(), forKey: "createdAt")
        setValue(Date(), forKey: "updatedAt")
    }
}

extension NoteEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<NoteEntity> {
        return NSFetchRequest<NoteEntity>(entityName: "Note")
    }

    /// Get tags as array of strings
    public var tags: [String] {
        guard let data = tagsData,
              let array = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return array
    }

    /// Set tags from array of strings
    public func setTags(_ tags: [String]) {
        if let data = try? JSONEncoder().encode(tags) {
            tagsData = data
        }
    }
}

/// CoreData model for todo items
public final class TodoItemEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var descriptionText: String
    @NSManaged public var isCompleted: Bool
    @NSManaged public var priority: Int32
    @NSManaged public var createdAt: Date
    @NSManaged public var dueDate: Date?
    @NSManaged public var completedAt: Date?

    override public func awakeFromInsert() {
        super.awakeFromInsert()
        setValue(UUID(), forKey: "id")
        setValue(Date(), forKey: "createdAt")
        setValue(false, forKey: "isCompleted")
        setValue(Int32(2), forKey: "priority") // Default to normal priority
    }
}

extension TodoItemEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TodoItemEntity> {
        return NSFetchRequest<TodoItemEntity>(entityName: "TodoItem")
    }
}

/// CoreData model for reminders
public final class ReminderEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var message: String
    @NSManaged public var triggerTime: Date
    @NSManaged public var isRecurring: Bool
    @NSManaged public var recurrenceInterval: TimeInterval
    @NSManaged public var nextTrigger: Date
    @NSManaged public var isActive: Bool

    override public func awakeFromInsert() {
        super.awakeFromInsert()
        setValue(UUID(), forKey: "id")
        setValue(false, forKey: "isRecurring")
        setValue(0.0, forKey: "recurrenceInterval")
        setValue(true, forKey: "isActive")
    }
}

extension ReminderEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ReminderEntity> {
        return NSFetchRequest<ReminderEntity>(entityName: "Reminder")
    }
}

/// CoreData model for workflows
public final class WorkflowEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var triggerCondition: String
    @NSManaged public var actionsData: Data? // JSON-encoded array of actions
    @NSManaged public var isActive: Bool
    @NSManaged public var createdAt: Date

    override public func awakeFromInsert() {
        super.awakeFromInsert()
        setValue(UUID(), forKey: "id")
        setValue(Date(), forKey: "createdAt")
        setValue(true, forKey: "isActive")
    }
}

extension WorkflowEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<WorkflowEntity> {
        return NSFetchRequest<WorkflowEntity>(entityName: "Workflow")
    }

    /// Get actions as array of strings
    public var actions: [String] {
        guard let data = actionsData,
              let array = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return array
    }

    /// Set actions from array of strings
    public func setActions(_ actions: [String]) {
        if let data = try? JSONEncoder().encode(actions) {
            actionsData = data
        }
    }
}

/// CoreData model for user behavior patterns
public final class UserPatternEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var patternType: String
    @NSManaged public var trigger: String
    @NSManaged public var preferredAction: String
    @NSManaged public var confidence: Double
    @NSManaged public var lastObserved: Date
    @NSManaged public var usageCount: Int32

    override public func awakeFromInsert() {
        super.awakeFromInsert()
        setValue(UUID(), forKey: "id")
        setValue(Date(), forKey: "lastObserved")
        setValue(Int32(0), forKey: "usageCount")
    }
}

extension UserPatternEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserPatternEntity> {
        return NSFetchRequest<UserPatternEntity>(entityName: "UserPattern")
    }
}
