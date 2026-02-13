import Foundation
import SwiftData

enum SessionError: LocalizedError, Equatable {
    case noTaskSelected
    case noPendingTask
    case activeSessionExists
    case sessionNotFound
    case sessionAlreadyEnded
    case taskNotFoundInSession

    var errorDescription: String? {
        switch self {
        case .noTaskSelected:
            return "请至少选择一个任务。"
        case .noPendingTask:
            return "所选任务中没有可执行的待办项。"
        case .activeSessionExists:
            return "当前已有进行中的任务钟，请先结束后再创建。"
        case .sessionNotFound:
            return "未找到对应的任务钟。"
        case .sessionAlreadyEnded:
            return "这个任务钟已经结束。"
        case .taskNotFoundInSession:
            return "任务不在当前任务钟中。"
        }
    }
}

enum SessionService {
    @discardableResult
    static func startSession(todoIDs: [UUID], context: ModelContext, now: Date = .now) throws -> FocusSession {
        var seen = Set<UUID>()
        let deduplicatedIDs = todoIDs.filter { seen.insert($0).inserted }
        guard !deduplicatedIDs.isEmpty else {
            throw SessionError.noTaskSelected
        }

        if try activeSession(context: context) != nil {
            throw SessionError.activeSessionExists
        }

        let todoDescriptor = FetchDescriptor<TodoItem>()
        let todos = try context.fetch(todoDescriptor)
        let todoMap = Dictionary(uniqueKeysWithValues: todos.map { ($0.id, $0) })
        let chosenPendingTodos = deduplicatedIDs.compactMap { id -> TodoItem? in
            guard let item = todoMap[id], item.status == .pending else { return nil }
            return item
        }

        guard !chosenPendingTodos.isEmpty else {
            throw SessionError.noPendingTask
        }

        let session = FocusSession(
            startedAt: now,
            totalTaskCount: chosenPendingTodos.count
        )
        context.insert(session)

        for (idx, todo) in chosenPendingTodos.enumerated() {
            let ref = SessionTaskRef(
                session: session,
                todoId: todo.id,
                titleSnapshot: todo.title,
                orderIndex: idx
            )
            context.insert(ref)
        }

        try context.save()
        return session
    }

    static func toggleTask(sessionId: UUID, todoId: UUID, isCompleted: Bool, context: ModelContext, now: Date = .now) throws {
        guard let session = try fetchSession(id: sessionId, context: context) else {
            throw SessionError.sessionNotFound
        }
        guard session.state == .active else {
            throw SessionError.sessionAlreadyEnded
        }

        guard let ref = session.taskRefs.first(where: { $0.todoId == todoId }) else {
            throw SessionError.taskNotFoundInSession
        }

        ref.isCompletedInSession = isCompleted
        ref.completedAt = isCompleted ? now : nil

        if let todo = try fetchTodo(id: todoId, context: context) {
            todo.status = isCompleted ? .completed : .pending
            todo.completedAt = isCompleted ? now : nil
            todo.updatedAt = now
        }

        session.completedTaskCount = session.taskRefs.filter(\.isCompletedInSession).count
        try context.save()
    }

    @discardableResult
    static func endSession(sessionId: UUID, context: ModelContext, now: Date = .now) throws -> FocusSession {
        guard let session = try fetchSession(id: sessionId, context: context) else {
            throw SessionError.sessionNotFound
        }
        guard session.state == .active else {
            throw SessionError.sessionAlreadyEnded
        }

        session.completedTaskCount = session.taskRefs.filter(\.isCompletedInSession).count
        session.totalTaskCount = session.taskRefs.count
        session.endedAt = now
        session.elapsedSeconds = max(0, Int(now.timeIntervalSince(session.startedAt)))
        session.state = .ended
        try context.save()
        return session
    }

    static func activeSession(context: ModelContext) throws -> FocusSession? {
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate<FocusSession> { session in
                session.stateValue == "active"
            },
            sortBy: [SortDescriptor(\FocusSession.startedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).first
    }

    static func restoreActiveSession(context: ModelContext, now: Date = .now) throws -> FocusSession? {
        guard let session = try activeSession(context: context) else {
            return nil
        }
        session.elapsedSeconds = max(0, Int(now.timeIntervalSince(session.startedAt)))
        try context.save()
        return session
    }

    static func fetchSession(id: UUID, context: ModelContext) throws -> FocusSession? {
        let descriptor = FetchDescriptor<FocusSession>(
            sortBy: [SortDescriptor(\FocusSession.startedAt, order: .reverse)]
        )
        let sessions = try context.fetch(descriptor)
        return sessions.first { $0.id == id }
    }

    static func fetchLatestEndedSession(context: ModelContext) throws -> FocusSession? {
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate<FocusSession> { session in
                session.stateValue == "ended"
            },
            sortBy: [SortDescriptor(\FocusSession.endedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).first
    }

    private static func fetchTodo(id: UUID, context: ModelContext) throws -> TodoItem? {
        let descriptor = FetchDescriptor<TodoItem>()
        return try context.fetch(descriptor).first(where: { $0.id == id })
    }
}
