import SwiftData
import XCTest
@testable import Pomlist

final class SessionServiceTests: XCTestCase {
    func testSessionCanRecordEightOfTen() throws {
        let container = try TestContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let startTime = Date(timeIntervalSince1970: 1_700_000_000)

        var todoIDs: [UUID] = []
        for index in 0..<10 {
            let todo = try TodoService.createTodo(
                from: TodoDraft(
                    title: "任务\(index)",
                    subject: "数学",
                    notes: "",
                    priority: .medium,
                    dueAt: nil
                ),
                context: context,
                now: startTime
            )
            todoIDs.append(todo.id)
        }

        let session = try SessionService.startSession(todoIDs: todoIDs, context: context, now: startTime)
        XCTAssertEqual(session.totalTaskCount, 10)
        XCTAssertEqual(session.completedTaskCount, 0)

        for id in todoIDs.prefix(8) {
            try SessionService.toggleTask(
                sessionId: session.id,
                todoId: id,
                isCompleted: true,
                context: context,
                now: startTime.addingTimeInterval(300)
            )
        }

        let ended = try SessionService.endSession(
            sessionId: session.id,
            context: context,
            now: startTime.addingTimeInterval(1800)
        )

        XCTAssertEqual(ended.completedTaskCount, 8)
        XCTAssertEqual(ended.totalTaskCount, 10)
        XCTAssertEqual(ended.state, .ended)
        XCTAssertEqual(ended.elapsedSeconds, 1800)

        let allTodos = try TodoService.fetchTodos(filter: .all, context: context)
        let completedCount = allTodos.filter { $0.status == .completed }.count
        let pendingCount = allTodos.filter { $0.status == .pending }.count
        XCTAssertEqual(completedCount, 8)
        XCTAssertEqual(pendingCount, 2)
    }

    func testOnlyOneActiveSessionAllowed() throws {
        let container = try TestContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_700_100_000)

        let todoA = try TodoService.createTodo(
            from: TodoDraft(title: "A", subject: "", notes: "", priority: .medium, dueAt: nil),
            context: context,
            now: now
        )
        let todoB = try TodoService.createTodo(
            from: TodoDraft(title: "B", subject: "", notes: "", priority: .medium, dueAt: nil),
            context: context,
            now: now
        )

        _ = try SessionService.startSession(todoIDs: [todoA.id], context: context, now: now)

        XCTAssertThrowsError(try SessionService.startSession(todoIDs: [todoB.id], context: context, now: now.addingTimeInterval(10))) { error in
            XCTAssertEqual(error as? SessionError, .activeSessionExists)
        }
    }
}

