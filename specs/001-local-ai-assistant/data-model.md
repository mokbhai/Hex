# Data Model: Local AI Assistant

**Date**: November 6, 2025
**Feature**: Local AI Assistant

## Overview

The Local AI Assistant feature extends Hex's data model to support AI-driven voice commands, user data persistence, and model management. All data is stored locally using CoreData, following existing project patterns.

## Entities

### AI Model

Represents downloadable AI models from Hugging Face.

**Fields**:

- `id`: UUID (primary key)
- `name`: String (model name, e.g., "microsoft/DialoGPT-medium")
- `displayName`: String (user-friendly name)
- `version`: String (model version/tag)
- `size`: Int64 (file size in bytes)
- `localPath`: String? (local file system path when downloaded)
- `downloadDate`: Date? (when model was downloaded)
- `lastUsed`: Date? (last usage timestamp)
- `capabilities`: [String] (array of supported tasks: "text-generation", "speech-recognition", etc.)
- `isDownloaded`: Bool (computed from localPath existence)

**Relationships**:

- None (standalone entity)

**Validation Rules**:

- `name` must be unique
- `localPath` must exist if `isDownloaded` is true
- `size` must be > 0

**State Transitions**:

- Not Downloaded → Downloading → Downloaded → Deleted

### Note

Represents user-created notes via voice commands.

**Fields**:

- `id`: UUID (primary key)
- `content`: String (note text)
- `createdAt`: Date
- `updatedAt`: Date
- `tags`: [String]? (optional tags for organization)

**Relationships**:

- None

**Validation Rules**:

- `content` cannot be empty
- `createdAt` <= `updatedAt`

### Todo Item

Represents tasks in todo lists managed via voice.

**Fields**:

- `id`: UUID (primary key)
- `description`: String (task description)
- `isCompleted`: Bool
- `priority`: Int (1-3, where 3 is highest)
- `createdAt`: Date
- `dueDate`: Date? (optional deadline)
- `completedAt`: Date? (when marked complete)

**Relationships**:

- None (could be extended to support lists in future)

**Validation Rules**:

- `description` cannot be empty
- `priority` must be 1-3
- `completedAt` is set only when `isCompleted` is true

**State Transitions**:

- Created → In Progress → Completed

### Reminder

Represents scheduled reminders set via voice.

**Fields**:

- `id`: UUID (primary key)
- `message`: String (reminder text)
- `triggerTime`: Date (when to trigger)
- `isRecurring`: Bool
- `recurrenceInterval`: TimeInterval? (seconds between recurrences)
- `nextTrigger`: Date (computed next trigger time)
- `isActive`: Bool

**Relationships**:

- None

**Validation Rules**:

- `message` cannot be empty
- `triggerTime` must be in future for new reminders
- `recurrenceInterval` required if `isRecurring` is true

### Workflow

Represents automated sequences of actions.

**Fields**:

- `id`: UUID (primary key)
- `name`: String (user-defined name)
- `triggerCondition`: String (description of when to trigger)
- `actions`: [String] (array of action descriptions)
- `isActive`: Bool
- `createdAt`: Date

**Relationships**:

- None

**Validation Rules**:

- `name` cannot be empty
- `actions` must contain at least one action

### User Pattern

Represents learned user behavior patterns.

**Fields**:

- `id`: UUID (primary key)
- `patternType`: String (e.g., "time-based", "context-based")
- `trigger`: String (what triggers the pattern)
- `preferredAction`: String (suggested action)
- `confidence`: Double (0.0-1.0, how confident the system is)
- `lastObserved`: Date
- `usageCount`: Int

**Relationships**:

- None

**Validation Rules**:

- `confidence` must be 0.0-1.0
- `usageCount` >= 0

## Data Flow

1. **Model Management**: AI Models are downloaded from Hugging Face and stored locally
2. **Voice Processing**: Audio is captured, processed locally, and immediately deleted
3. **Data Persistence**: User data (notes, todos, reminders) stored in CoreData
4. **Pattern Learning**: User interactions tracked to build User Patterns over time
5. **Workflow Execution**: Workflows triggered based on conditions and execute predefined actions

## Migration Strategy

- Extend existing CoreData model to include new entities
- Migrate existing settings if needed
- Handle first-time model downloads gracefully
- Preserve user data during updates
