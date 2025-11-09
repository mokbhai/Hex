import Foundation
import ComposableArchitecture

/// ConversationContextManager handles persistent multi-turn conversation support
/// 
/// Supports SC-005 requirement: "AI maintains context across 10+ interactions for continuous conversation"
/// 
/// This component:
/// - Maintains a sliding window of recent interactions
/// - Persists context to CoreData when enabled
/// - Supports privacy mode (disables persistence)
/// - Provides context for prompt enrichment
/// - Tracks user patterns and preferences learned from conversation
public struct ConversationContextManager {
    // MARK: - Configuration

    /// Maximum number of interactions to maintain in memory
    public static let defaultMaxInteractions = 10

    /// Maximum age of interactions to consider (24 hours)
    public static let maxContextAge: TimeInterval = 86400

    // MARK: - Context Management

    /// Add an interaction to the conversation context
    /// - Parameters:
    ///   - userInput: What the user said
    ///   - aiResponse: The AI's response
    ///   - context: Optional metadata about the interaction
    /// - Returns: Updated conversation context
    public static func addInteraction(
        to context: inout AIAssistantFeature.ConversationContext,
        userInput: String,
        aiResponse: String,
        contextMetadata: String? = nil
    ) {
        let interaction = AIAssistantFeature.ConversationContext.Interaction(
            userInput: userInput,
            aiResponse: aiResponse,
            context: contextMetadata
        )

        context.interactions.append(interaction)

        // Remove oldest interactions if over limit
        if context.interactions.count > context.maxInteractions {
            context.interactions.removeFirst(context.interactions.count - context.maxInteractions)
        }

        // TODO: T014 Persistence
        // - If settings.contextPersistenceEnabled && !settings.privacyMode:
        //   - Persist interaction to CoreData
        //   - Update conversation metadata
        // - If settings.privacyMode:
        //   - Skip persistence, keep only in memory
    }

    /// Get context window for prompt enrichment
    /// Returns formatted string of recent interactions for AI context
    /// - Parameter context: Conversation context
    /// - Returns: Formatted context string for AI inference
    public static func getContextWindow(from context: AIAssistantFeature.ConversationContext) -> String {
        let recentInteractions = context.interactions.suffix(5) // Last 5 interactions

        return recentInteractions.map { interaction in
            "User: \(interaction.userInput)\nAssistant: \(interaction.aiResponse)"
        }.joined(separator: "\n\n")
    }

    /// Clear context based on user settings
    /// - Parameter respectPrivacyMode: If true, only clear if privacy mode enabled
    public static func clearContext(
        _ context: inout AIAssistantFeature.ConversationContext,
        respectPrivacyMode: Bool = true
    ) {
        context.reset()

        // TODO: T014 Persistence Cleanup
        // - Delete persisted interactions from CoreData
        // - Update conversation metadata
    }

    // MARK: - Pattern Learning

    /// Extract user patterns from conversation history
    /// - Parameter context: Conversation context
    /// - Returns: Learned patterns for prediction
    public static func extractPatterns(
        from context: AIAssistantFeature.ConversationContext
    ) -> [UserPattern] {
        // TODO: T014 Pattern Learning
        // 1. Analyze interactions for repeated queries
        // 2. Identify user preferences (search providers, model preferences, etc.)
        // 3. Track time-of-day patterns (when user is most active)
        // 4. Recognize frequently used commands
        // 5. Return as array of UserPattern entities

        return []
    }

    // MARK: - Context Persistence

    /// Load context from CoreData
    /// - Returns: Restored conversation context
    public static func loadContext() -> AIAssistantFeature.ConversationContext {
        // TODO: T014 CoreData Loading
        // 1. Query ConversationContextEntity from CoreData
        // 2. Reconstruct interactions array
        // 3. Filter out stale interactions (> maxContextAge)
        // 4. Return restored context

        return AIAssistantFeature.ConversationContext()
    }

    /// Save context to CoreData
    /// - Parameter context: Conversation context to save
    public static func saveContext(_ context: AIAssistantFeature.ConversationContext) {
        // TODO: T014 CoreData Saving
        // 1. Create or update ConversationContextEntity
        // 2. Serialize interactions array
        // 3. Store metadata (updated timestamp, etc.)
        // 4. Handle concurrent access safely
        // 5. Log errors but don't crash
    }

    /// Delete context from CoreData
    public static func deleteContext() {
        // TODO: T014 CoreData Deletion
        // 1. Find ConversationContextEntity
        // 2. Delete all associated interactions
        // 3. Commit transaction
    }

    // MARK: - State Machine

    /// State for conversation lifecycle
    public enum ContextState: Equatable {
        /// No interactions yet
        case empty
        /// Actively conversing with some history
        case active
        /// Context cleared due to privacy mode or user action
        case cleared
        /// Error loading context from storage
        case loadError(String)
    }

    /// Get current state of conversation context
    /// - Parameter context: Conversation context
    /// - Returns: Current ContextState
    public static func getState(of context: AIAssistantFeature.ConversationContext) -> ContextState {
        if context.interactions.isEmpty {
            return .empty
        }
        return .active
    }

    /// Transition context to next state
    /// - Parameter action: Action triggering transition
    /// - Returns: New state after transition
    public static func transition(
        current: ContextState,
        on action: String
    ) -> ContextState {
        // TODO: T014 State Machine
        // State transitions:
        // empty + startConversation → active
        // active + userInteraction → active
        // * + clearContext → cleared
        // cleared + newInteraction → active
        // * + loadError → loadError

        return current
    }

    // MARK: - Memory Management

    /// Get memory usage of context
    /// - Parameter context: Conversation context
    /// - Returns: Estimated memory usage in bytes
    public static func estimateMemoryUsage(
        _ context: AIAssistantFeature.ConversationContext
    ) -> Int {
        // TODO: Estimate memory for debugging
        let interactionSize = context.interactions.reduce(0) { sum, interaction in
            sum + (interaction.userInput.count + interaction.aiResponse.count)
        }
        return interactionSize
    }

    /// Check if context needs cleanup
    /// - Parameter context: Conversation context
    /// - Returns: True if cleanup recommended
    public static func needsCleanup(
        _ context: AIAssistantFeature.ConversationContext
    ) -> Bool {
        // Recommend cleanup if:
        // 1. Memory usage excessive
        // 2. Old interactions present
        // 3. Interaction count at max

        let memoryUsage = estimateMemoryUsage(context)
        let hasOldInteractions = context.interactions.contains { interaction in
            Date().timeIntervalSince(interaction.timestamp) > maxContextAge
        }

        return memoryUsage > 1_000_000 || hasOldInteractions
    }

    /// Perform cleanup on context
    /// - Parameter context: Conversation context to clean
    public static func cleanup(_ context: inout AIAssistantFeature.ConversationContext) {
        // Remove old interactions
        let now = Date()
        context.interactions.removeAll { interaction in
            now.timeIntervalSince(interaction.timestamp) > maxContextAge
        }

        // Trim to max size
        if context.interactions.count > context.maxInteractions {
            context.interactions.removeFirst(
                context.interactions.count - context.maxInteractions
            )
        }
    }
}

// MARK: - Supporting Types

/// User pattern learned from conversation
public struct UserPattern: Equatable {
    public let id: UUID
    public let patternType: String
    public let trigger: String
    public let preferredAction: String
    public let confidence: Double
    public let lastObserved: Date
    public let usageCount: Int

    public init(
        id: UUID = UUID(),
        patternType: String,
        trigger: String,
        preferredAction: String,
        confidence: Double,
        lastObserved: Date = Date(),
        usageCount: Int = 1
    ) {
        self.id = id
        self.patternType = patternType
        self.trigger = trigger
        self.preferredAction = preferredAction
        self.confidence = confidence
        self.lastObserved = lastObserved
        self.usageCount = usageCount
    }
}
