import XCTest
@testable import Hex

/// Comprehensive test suite for productivity tools
/// Tests timers, calculators, notes, todos, and persistence
///
/// Used by User Story 3: Voice Productivity Tools (T058)
final class ProductivityToolsTests: XCTestCase {
    // MARK: - Timer Tests

    func testCreateTimer() throws {
        var manager = TimerManager()
        
        let timer = try manager.createTimer(name: "Pomodoro", duration: 1500)
        
        XCTAssertEqual(timer.duration, 1500)
        XCTAssertEqual(timer.name, "Pomodoro")
        XCTAssertFalse(timer.isRunning)
        XCTAssertFalse(timer.isPaused)
    }

    func testStartTimer() throws {
        var manager = TimerManager()
        
        let timer = try manager.createTimer(name: "Test", duration: 60)
        try manager.startTimer(timer.id)
        
        let runningTimer = manager.getTimer(timer.id)
        XCTAssertTrue(runningTimer?.isRunning ?? false)
    }

    func testPauseResumeTimer() throws {
        var manager = TimerManager()
        
        let timer = try manager.createTimer(name: "Test", duration: 60)
        try manager.startTimer(timer.id)
        try manager.pauseTimer(timer.id)
        
        var pausedTimer = manager.getTimer(timer.id)
        XCTAssertTrue(pausedTimer?.isPaused ?? false)
        
        try manager.resumeTimer(timer.id)
        pausedTimer = manager.getTimer(timer.id)
        XCTAssertFalse(pausedTimer?.isPaused ?? true)
    }

    func testTimerProgress() throws {
        var manager = TimerManager()
        
        let timer = try manager.createTimer(name: "Test", duration: 100)
        try manager.startTimer(timer.id)
        
        let activeTimer = manager.getTimer(timer.id)
        let progress = activeTimer?.progress ?? 0
        
        XCTAssertGreaterThanOrEqual(progress, 0)
        XCTAssertLessThanOrEqual(progress, 1)
    }

    func testFormatTime() {
        XCTAssertEqual(TimerManager.formatTime(300), "05:00")
        XCTAssertEqual(TimerManager.formatTime(61), "01:01")
        XCTAssertEqual(TimerManager.formatTime(3661), "61:01")
    }

    func testParseTimerInput() {
        XCTAssertEqual(TimerManager.parseTimerInput("5 minutes"), 300)
        XCTAssertEqual(TimerManager.parseTimerInput("30 seconds"), 30)
        XCTAssertEqual(TimerManager.parseTimerInput("1 hour"), 3600)
        XCTAssertNil(TimerManager.parseTimerInput("invalid"))
    }

    // MARK: - Calculator Tests

    func testBasicCalculation() throws {
        let calculator = Calculator()
        
        let result = try calculator.calculate("2 + 3")
        XCTAssertEqual(result.result, 5)
    }

    func testCalculationWithSpaces() throws {
        let calculator = Calculator()
        
        let result = try calculator.calculate("10 * 5")
        XCTAssertEqual(result.result, 50)
    }

    func testPercentageCalculation() throws {
        let calculator = Calculator()
        
        let result = try calculator.calculateNaturalLanguage("15 percent of 250")
        XCTAssertEqual(result.result, 37.5)
    }

    func testPercentageConversion() throws {
        let calculator = Calculator()
        
        let result = try calculator.calculateNaturalLanguage("25 percent")
        XCTAssertEqual(result.result, 0.25)
    }

    func testComplexExpression() throws {
        let calculator = Calculator()
        
        let result = try calculator.calculate("(5 + 3) * 2")
        XCTAssertEqual(result.result, 16)
    }

    func testDivisionByZero() throws {
        let calculator = Calculator()
        
        XCTAssertThrowsError(try calculator.calculate("10 / 0"))
    }

    func testCalculatorFormatting() {
        let formatted = Calculator.formatNumber(3.14159, precision: 2)
        XCTAssertEqual(formatted, "3.14")
        
        let intFormatted = Calculator.formatNumber(42.0)
        XCTAssertEqual(intFormatted, "42")
    }

    // MARK: - Calculation Parser Tests

    func testParseSimpleExpression() throws {
        let expr = try CalculationParser.parse("2 plus 3")
        XCTAssertTrue(expr.contains("+"))
    }

    func testParsePercentage() throws {
        let expr = try CalculationParser.parse("25 percent of 100")
        XCTAssertTrue(expr.contains("*"))
    }

    func testParseComparison() throws {
        let expr = try CalculationParser.parse("10 more than 20")
        XCTAssertTrue(expr.contains("+"))
    }

    func testExtractNumbers() {
        let numbers = CalculationParser.extractNumbers("10 + 20 * 30")
        XCTAssertEqual(numbers, [10, 20, 30])
    }

    func testExtractOperators() {
        let operators = CalculationParser.extractOperators("10 + 20 - 30 * 40")
        XCTAssertTrue(operators.contains("+"))
        XCTAssertTrue(operators.contains("-"))
        XCTAssertTrue(operators.contains("*"))
    }

    func testValidateExpression() {
        XCTAssertTrue(CalculationParser.isValidExpression("10 + 20"))
        XCTAssertFalse(CalculationParser.isValidExpression(""))
        XCTAssertFalse(CalculationParser.isValidExpression("abc"))
    }

    // MARK: - Note Service Tests

    func testCreateNote() throws {
        let context = NSManagedObjectContext(concurrencyType: .mainThreadPrivateQueueConcurrencyType)
        let service = NoteService(context: context)
        
        let note = try service.createNote(content: "Test note", tags: ["test"])
        
        XCTAssertEqual(note.content, "Test note")
        XCTAssertTrue(note.tags.contains("test"))
    }

    func testUpdateNote() throws {
        let context = NSManagedObjectContext(concurrencyType: .mainThreadPrivateQueueConcurrencyType)
        let service = NoteService(context: context)
        
        let note = try service.createNote(content: "Original", tags: [])
        let updated = try service.updateNote(id: note.id, content: "Updated")
        
        XCTAssertEqual(updated.content, "Updated")
    }

    func testDeleteNote() throws {
        let context = NSManagedObjectContext(concurrencyType: .mainThreadPrivateQueueConcurrencyType)
        let service = NoteService(context: context)
        
        let note = try service.createNote(content: "Delete me", tags: [])
        try service.deleteNote(id: note.id)
        
        XCTAssertThrowsError(try service.fetchNote(id: note.id))
    }

    func testFetchAllNotes() throws {
        let context = NSManagedObjectContext(concurrencyType: .mainThreadPrivateQueueConcurrencyType)
        let service = NoteService(context: context)
        
        _ = try service.createNote(content: "Note 1", tags: [])
        _ = try service.createNote(content: "Note 2", tags: [])
        
        let notes = try service.fetchAllNotes()
        XCTAssertEqual(notes.count, 2)
    }

    func testSearchNotes() throws {
        let context = NSManagedObjectContext(concurrencyType: .mainThreadPrivateQueueConcurrencyType)
        let service = NoteService(context: context)
        
        _ = try service.createNote(content: "Swift programming", tags: [])
        _ = try service.createNote(content: "Python tutorial", tags: [])
        
        let results = try service.searchNotes(searchText: "Swift")
        XCTAssertEqual(results.count, 1)
    }

    // MARK: - Todo Service Tests

    func testCreateTodo() throws {
        let context = NSManagedObjectContext(concurrencyType: .mainThreadPrivateQueueConcurrencyType)
        let service = TodoService(context: context)
        
        let todo = try service.createTodo(description: "Buy milk", priority: .high)
        
        XCTAssertEqual(todo.description, "Buy milk")
        XCTAssertEqual(todo.priority, 3) // High priority
        XCTAssertFalse(todo.isCompleted)
    }

    func testCompleteTodo() throws {
        let context = NSManagedObjectContext(concurrencyType: .mainThreadPrivateQueueConcurrencyType)
        let service = TodoService(context: context)
        
        let todo = try service.createTodo(description: "Task", priority: .normal)
        let completed = try service.completeTodo(id: todo.id)
        
        XCTAssertTrue(completed.isCompleted)
        XCTAssertNotNil(completed.completedAt)
    }

    func testIncompleteTodo() throws {
        let context = NSManagedObjectContext(concurrencyType: .mainThreadPrivateQueueConcurrencyType)
        let service = TodoService(context: context)
        
        let todo = try service.createTodo(description: "Task", priority: .normal)
        let completed = try service.completeTodo(id: todo.id)
        let incomplete = try service.incompleteTodo(id: completed.id)
        
        XCTAssertFalse(incomplete.isCompleted)
        XCTAssertNil(incomplete.completedAt)
    }

    func testFetchIncompleteTodos() throws {
        let context = NSManagedObjectContext(concurrencyType: .mainThreadPrivateQueueConcurrencyType)
        let service = TodoService(context: context)
        
        let todo1 = try service.createTodo(description: "Task 1", priority: .normal)
        _ = try service.createTodo(description: "Task 2", priority: .normal)
        
        _ = try service.completeTodo(id: todo1.id)
        
        let incomplete = try service.fetchIncompleteTodos()
        XCTAssertEqual(incomplete.count, 1)
    }

    func testFetchByPriority() throws {
        let context = NSManagedObjectContext(concurrencyType: .mainThreadPrivateQueueConcurrencyType)
        let service = TodoService(context: context)
        
        _ = try service.createTodo(description: "High task", priority: .high)
        _ = try service.createTodo(description: "Low task", priority: .low)
        
        let highPriority = try service.fetchTodosByPriority(.high)
        XCTAssertEqual(highPriority.count, 1)
    }

    func testCompletionPercentage() throws {
        let context = NSManagedObjectContext(concurrencyType: .mainThreadPrivateQueueConcurrencyType)
        let service = TodoService(context: context)
        
        let todo1 = try service.createTodo(description: "Task 1", priority: .normal)
        _ = try service.createTodo(description: "Task 2", priority: .normal)
        
        _ = try service.completeTodo(id: todo1.id)
        
        let percentage = try service.getCompletionPercentage()
        XCTAssertEqual(percentage, 50)
    }

    // MARK: - Persistence Tests

    func testExportStatistics() {
        let notes = [NoteEntity()]
        let stats = NoteService.getStatistics(notes)
        
        XCTAssertNotNil(stats["totalNotes"])
        XCTAssertNotNil(stats["totalWords"])
        XCTAssertNotNil(stats["totalCharacters"])
    }

    func testTodoStatistics() {
        let todos = [TodoItemEntity()]
        let stats = TodoService.getStatistics(todos)
        
        XCTAssertNotNil(stats["total"])
        XCTAssertNotNil(stats["completed"])
        XCTAssertNotNil(stats["incomplete"])
        XCTAssertNotNil(stats["completionPercentage"])
    }

    // MARK: - Integration Tests

    func testTimerCompleteFlow() throws {
        var manager = TimerManager()
        
        // Create and start timer
        let timer = try manager.createTimer(name: "Test", duration: 1)
        try manager.startTimer(timer.id)
        
        // Wait briefly
        try! Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Check progress
        var activeTimer = manager.getTimer(timer.id)
        XCTAssertGreaterThan(activeTimer?.progress ?? 0, 0)
        
        // Can pause
        try manager.pauseTimer(timer.id)
        activeTimer = manager.getTimer(timer.id)
        XCTAssertTrue(activeTimer?.isPaused ?? false)
    }

    func testCalculationCompleteFlow() throws {
        let calculator = Calculator()
        
        // Natural language input
        let result1 = try calculator.calculateNaturalLanguage("what is 20 percent of 500")
        XCTAssertEqual(result1.result, 100)
        
        // Direct calculation
        let result2 = try calculator.calculate("500 * 0.2")
        XCTAssertEqual(result2.result, 100)
    }
}
