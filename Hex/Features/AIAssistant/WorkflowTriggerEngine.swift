import Foundation
import ComposableArchitecture

/// Workflow trigger engine supporting time-based, event-based, and context-based automation
actor WorkflowTriggerEngine {
    enum TriggerType: String, Codable {
        case time
        case event
        case context
        case command
        case schedule
    }
    
    enum WorkflowError: LocalizedError {
        case invalidWorkflow
        case triggerNotFound
        case executionFailed(String)
        case contextMismatch
        
        var errorDescription: String? {
            switch self {
            case .invalidWorkflow:
                return "Invalid workflow configuration"
            case .triggerNotFound:
                return "Trigger not found"
            case .executionFailed(let reason):
                return "Workflow execution failed: \(reason)"
            case .contextMismatch:
                return "Workflow context does not match"
            }
        }
    }
    
    struct Workflow: Codable, Identifiable {
        let id: UUID
        let name: String
        let description: String
        let triggers: [WorkflowTrigger]
        let actions: [WorkflowAction]
        var isEnabled: Bool = true
        var lastExecutedAt: Date?
        var executionCount: Int = 0
    }
    
    struct WorkflowTrigger: Codable, Identifiable {
        let id: UUID
        let type: TriggerType
        let condition: String
        var isActive: Bool = true
        
        // Time-based
        let scheduledTime: String? // "09:00" format
        let daysOfWeek: [Int]? // 0-6, Sunday-Saturday
        let repeatInterval: TimeInterval? // seconds
        
        // Event-based
        let eventName: String?
        let eventMatchPattern: String?
        
        // Context-based
        let contextKey: String?
        let contextValue: String?
        let contextOperator: String? // "equals", "contains", "regex"
    }
    
    struct WorkflowAction: Codable, Identifiable {
        let id: UUID
        let type: String // "command", "notification", "script", "http"
        let payload: [String: AnyCodable]
        var delay: TimeInterval = 0
    }
    
    struct WorkflowContext {
        let currentApp: String
        let timeOfDay: Date
        let userPreferences: [String: String]
        let recentCommands: [String]
        let systemMetrics: [String: Double]
    }
    
    private var workflows: [UUID: Workflow] = [:]
    private var activeTriggers: [UUID: Task<Void, Never>] = [:]
    private let logger: ErrorLogger
    private let commandHistory: CommandHistory
    private let contextAwareness: ContextAwareness
    private let voiceFeedback: VoiceFeedback
    
    init(
        logger: ErrorLogger = ErrorLogger.shared,
        history: CommandHistory = CommandHistory.shared,
        awareness: ContextAwareness = ContextAwareness.shared,
        feedback: VoiceFeedback = VoiceFeedback()
    ) {
        self.logger = logger
        self.commandHistory = history
        self.contextAwareness = awareness
        self.voiceFeedback = feedback
    }
    
    // MARK: - Workflow Management
    
    /// Add a new workflow
    func addWorkflow(_ workflow: Workflow) throws {
        guard !workflow.name.isEmpty else {
            throw WorkflowError.invalidWorkflow
        }
        workflows[workflow.id] = workflow
        
        if workflow.isEnabled {
            activateWorkflow(workflow.id)
        }
    }
    
    /// Remove a workflow
    func removeWorkflow(_ id: UUID) throws {
        deactivateWorkflow(id)
        workflows.removeValue(forKey: id)
    }
    
    /// Update a workflow
    func updateWorkflow(_ workflow: Workflow) throws {
        guard workflows[workflow.id] != nil else {
            throw WorkflowError.invalidWorkflow
        }
        workflows[workflow.id] = workflow
        
        deactivateWorkflow(workflow.id)
        if workflow.isEnabled {
            activateWorkflow(workflow.id)
        }
    }
    
    /// List all workflows
    func listWorkflows() -> [Workflow] {
        Array(workflows.values)
    }
    
    /// Get specific workflow
    func getWorkflow(_ id: UUID) throws -> Workflow {
        guard let workflow = workflows[id] else {
            throw WorkflowError.triggerNotFound
        }
        return workflow
    }
    
    // MARK: - Trigger Management
    
    /// Activate workflow triggers
    private func activateWorkflow(_ id: UUID) {
        guard let workflow = workflows[id] else { return }
        
        let task = Task {
            for trigger in workflow.triggers {
                guard trigger.isActive else { continue }
                
                switch trigger.type {
                case .time:
                    await handleTimeTrigger(trigger, workflowId: id)
                case .event:
                    await handleEventTrigger(trigger, workflowId: id)
                case .context:
                    await handleContextTrigger(trigger, workflowId: id)
                case .command:
                    await handleCommandTrigger(trigger, workflowId: id)
                case .schedule:
                    await handleScheduleTrigger(trigger, workflowId: id)
                }
            }
        }
        
        activeTriggers[id] = task
    }
    
    /// Deactivate workflow triggers
    private func deactivateWorkflow(_ id: UUID) {
        activeTriggers[id]?.cancel()
        activeTriggers.removeValue(forKey: id)
    }
    
    // MARK: - Trigger Handlers
    
    private func handleTimeTrigger(_ trigger: WorkflowTrigger, workflowId: UUID) async {
        guard let scheduledTime = trigger.scheduledTime else { return }
        
        while !Task.isCancelled {
            let now = Date()
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: now)
            
            let parts = scheduledTime.split(separator: ":").map { String($0) }
            guard parts.count == 2,
                  let hour = Int(parts[0]),
                  let minute = Int(parts[1]) else { continue }
            
            if components.hour == hour && components.minute == minute {
                await executeWorkflow(workflowId)
                try? await Task.sleep(nanoseconds: 60_000_000_000) // Wait 1 minute
            }
            
            try? await Task.sleep(nanoseconds: 30_000_000_000) // Check every 30 seconds
        }
    }
    
    private func handleEventTrigger(_ trigger: WorkflowTrigger, workflowId: UUID) async {
        guard let eventName = trigger.eventName else { return }
        
        // Monitor for events
        // This would integrate with app event bus
        while !Task.isCancelled {
            let recentEvents = commandHistory.getRecentCommands(limit: 10)
                .filter { $0.contains(eventName) }
            
            if !recentEvents.isEmpty {
                if let pattern = trigger.eventMatchPattern {
                    let matchesPattern = recentEvents.contains {
                        $0.range(of: pattern, options: .regularExpression) != nil
                    }
                    if matchesPattern {
                        await executeWorkflow(workflowId)
                    }
                } else {
                    await executeWorkflow(workflowId)
                }
            }
            
            try? await Task.sleep(nanoseconds: 1_000_000_000) // Check every 1 second
        }
    }
    
    private func handleContextTrigger(_ trigger: WorkflowTrigger, workflowId: UUID) async {
        guard let contextKey = trigger.contextKey,
              let contextValue = trigger.contextValue else { return }
        
        while !Task.isCancelled {
            let context = await contextAwareness.getCurrentContext()
            let userPrefs = context.userPreferences
            
            if let value = userPrefs[contextKey] {
                let matches = matchesCondition(
                    value,
                    contextValue,
                    operator: trigger.contextOperator ?? "equals"
                )
                
                if matches {
                    await executeWorkflow(workflowId)
                }
            }
            
            try? await Task.sleep(nanoseconds: 5_000_000_000) // Check every 5 seconds
        }
    }
    
    private func handleCommandTrigger(_ trigger: WorkflowTrigger, workflowId: UUID) async {
        let pattern = trigger.eventMatchPattern ?? trigger.condition
        
        while !Task.isCancelled {
            let recentCommands = commandHistory.getRecentCommands(limit: 1)
            
            if let command = recentCommands.first,
               command.range(of: pattern, options: .regularExpression) != nil {
                await executeWorkflow(workflowId)
            }
            
            try? await Task.sleep(nanoseconds: 500_000_000) // Check every 500ms
        }
    }
    
    private func handleScheduleTrigger(_ trigger: WorkflowTrigger, workflowId: UUID) async {
        guard let interval = trigger.repeatInterval else { return }
        
        while !Task.isCancelled {
            await executeWorkflow(workflowId)
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
    }
    
    // MARK: - Workflow Execution
    
    /// Execute workflow actions
    private func executeWorkflow(_ workflowId: UUID) async {
        guard var workflow = workflows[workflowId] else { return }
        
        do {
            for action in workflow.actions {
                if action.delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(action.delay * 1_000_000_000))
                }
                
                try await executeAction(action)
            }
            
            // Update workflow metadata
            workflow.lastExecutedAt = Date()
            workflow.executionCount += 1
            workflows[workflowId] = workflow
            
            logger.logInfo("Workflow executed: \(workflow.name)", context: [
                "workflow_id": workflowId.uuidString,
                "execution_count": workflow.executionCount
            ])
        } catch {
            logger.logError(error, context: [
                "operation": "execute_workflow",
                "workflow_id": workflowId.uuidString
            ])
        }
    }
    
    /// Execute a single workflow action
    private func executeAction(_ action: WorkflowAction) async throws {
        switch action.type {
        case "command":
            if let command = action.payload["command"]?.value as? String {
                // Execute system command
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/sh")
                process.arguments = ["-c", command]
                try process.run()
                process.waitUntilExit()
            }
            
        case "notification":
            if let message = action.payload["message"]?.value as? String {
                try await voiceFeedback.speak(message)
            }
            
        case "script":
            if let scriptPath = action.payload["path"]?.value as? String {
                let url = URL(fileURLWithPath: scriptPath)
                try await executeScript(at: url)
            }
            
        case "http":
            if let urlString = action.payload["url"]?.value as? String,
               let url = URL(string: urlString) {
                try await executeHTTPRequest(url, action: action)
            }
            
        default:
            throw WorkflowError.executionFailed("Unknown action type: \(action.type)")
        }
    }
    
    private func executeScript(at url: URL) async throws {
        let process = Process()
        process.executableURL = url
        try process.run()
        process.waitUntilExit()
    }
    
    private func executeHTTPRequest(_ url: URL, action: WorkflowAction) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = action.payload["method"]?.value as? String ?? "GET"
        
        if let headers = action.payload["headers"]?.value as? [String: String] {
            request.allHTTPHeaderFields = headers
        }
        
        if let body = action.payload["body"]?.value as? String {
            request.httpBody = body.data(using: .utf8)
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard (response as? HTTPURLResponse)?.statusCode ?? 0 < 400 else {
            throw WorkflowError.executionFailed("HTTP request failed")
        }
    }
    
    // MARK: - Helper Methods
    
    private func matchesCondition(
        _ value: String,
        _ expected: String,
        operator: String
    ) -> Bool {
        switch `operator` {
        case "equals":
            return value == expected
        case "contains":
            return value.contains(expected)
        case "regex":
            return value.range(of: expected, options: .regularExpression) != nil
        default:
            return false
        }
    }
}

// MARK: - AnyCodable

struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        if value is NSNull {
            try container.encodeNil()
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let string = value as? String {
            try container.encode(string)
        } else {
            try container.encodeNil()
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else {
            value = NSNull()
        }
    }
}

// MARK: - TCA Integration

extension WorkflowTriggerEngine: DependencyKey {
    static let liveValue = WorkflowTriggerEngine()
    
    static let testValue = WorkflowTriggerEngine(
        logger: ErrorLogger.testValue,
        history: CommandHistory.testValue,
        awareness: ContextAwareness.testValue,
        feedback: VoiceFeedback.testValue
    )
}

extension DependencyValues {
    var workflowEngine: WorkflowTriggerEngine {
        get { self[WorkflowTriggerEngine.self] }
        set { self[WorkflowTriggerEngine.self] = newValue }
    }
}
