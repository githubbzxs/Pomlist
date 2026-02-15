import Foundation
import SwiftData

@MainActor
final class PLSessionService: SessionManaging {
    private let context: ModelContext
    private(set) var activeSession: PLFocusSession?

    init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    func loadActiveSession() throws -> PLFocusSession? {
        var descriptor = FetchDescriptor<PLFocusSession>(
            predicate: #Predicate<PLFocusSession> {
                $0.endedAt == nil && $0.isCancelled == false
            },
            sortBy: [SortDescriptor(\PLFocusSession.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        activeSession = try context.fetch(descriptor).first
        return activeSession
    }

    func startSession(with todos: [PLTodo], plannedMinutes: Int) throws -> PLFocusSession {
        guard plannedMinutes > 0 else {
            throw PLServiceError.invalidPlannedMinutes
        }
        if try loadActiveSession() != nil {
            throw PLServiceError.activeSessionExists
        }

        let now = Date()
        let session = PLFocusSession(
            startedAt: now,
            plannedMinutes: plannedMinutes,
            elapsedSeconds: 0,
            isCancelled: false
        )
        context.insert(session)

        for todo in todos {
            let ref = PLSessionTaskRef(
                todoID: todo.id,
                todoTitleSnapshot: todo.title,
                categorySnapshot: todo.category,
                tagsSnapshot: todo.tags.joined(separator: ","),
                wasDoneAtEnd: todo.isDone,
                createdAt: now
            )
            ref.session = session
            context.insert(ref)
        }

        try context.saveIfNeeded()
        activeSession = session
        return session
    }

    func appendTasks(_ todos: [PLTodo], to session: PLFocusSession) throws {
        guard session.isActive else {
            throw PLServiceError.noActiveSession
        }

        let existingIDs = Set(session.taskRefs.map(\.todoID))
        let now = Date()
        for todo in todos where !existingIDs.contains(todo.id) {
            let ref = PLSessionTaskRef(
                todoID: todo.id,
                todoTitleSnapshot: todo.title,
                categorySnapshot: todo.category,
                tagsSnapshot: todo.tags.joined(separator: ","),
                wasDoneAtEnd: todo.isDone,
                createdAt: now
            )
            ref.session = session
            context.insert(ref)
        }
        try context.saveIfNeeded()
    }

    func finishSession(_ session: PLFocusSession, elapsedSeconds: Int) throws {
        guard session.isActive else {
            throw PLServiceError.noActiveSession
        }

        let now = Date()
        let actualElapsed = max(elapsedSeconds, Int(now.timeIntervalSince(session.startedAt)))
        session.endedAt = now
        session.elapsedSeconds = max(0, actualElapsed)
        session.isCancelled = false

        // 为了保持快照准确，结束时按任务当前状态回写完成标记。
        let allTodos = try context.fetch(FetchDescriptor<PLTodo>())
        let todoMap = Dictionary(uniqueKeysWithValues: allTodos.map { ($0.id, $0) })
        for ref in session.taskRefs {
            if let todo = todoMap[ref.todoID] {
                ref.wasDoneAtEnd = todo.isDone
            }
        }
        session.completedTaskCount = session.taskRefs.filter { $0.wasDoneAtEnd }.count

        if activeSession?.id == session.id {
            activeSession = nil
        }
        try context.saveIfNeeded()
    }

    func cancelSession(_ session: PLFocusSession) throws {
        guard session.isActive else {
            throw PLServiceError.noActiveSession
        }

        let now = Date()
        session.endedAt = now
        session.elapsedSeconds = max(0, Int(now.timeIntervalSince(session.startedAt)))
        session.isCancelled = true

        if activeSession?.id == session.id {
            activeSession = nil
        }
        try context.saveIfNeeded()
    }

    func fetchHistory(limit: Int = 120) throws -> [PLFocusSession] {
        var descriptor = FetchDescriptor<PLFocusSession>(
            predicate: #Predicate<PLFocusSession> { $0.endedAt != nil },
            sortBy: [SortDescriptor(\PLFocusSession.endedAt, order: .reverse)]
        )
        descriptor.fetchLimit = max(1, limit)
        return try context.fetch(descriptor)
    }
}
