import Foundation
import SwiftData

@MainActor
final class PLSessionService: SessionManaging {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func loadActiveSession() throws -> PLFocusSession? {
        var descriptor = FetchDescriptor<PLFocusSession>(
            predicate: #Predicate { $0.state == "active" },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func startSession(with todos: [PLTodo]) throws -> PLFocusSession {
        if try loadActiveSession() != nil {
            throw PLServiceError.activeSessionExists
        }

        if todos.isEmpty {
            throw PLServiceError.emptySessionTasks
        }

        let now = Date()
        let refs = todos.enumerated().map { index, todo in
            PLSessionTaskRef(
                id: UUID().uuidString,
                todoId: todo.id,
                titleSnapshot: todo.title,
                orderIndex: index,
                isCompletedInSession: false,
                completedAt: nil,
                createdAt: now,
                updatedAt: now
            )
        }

        let session = PLFocusSession(
            id: UUID().uuidString,
            state: "active",
            startedAt: now,
            endedAt: nil,
            elapsedSeconds: 0,
            totalTaskCount: refs.count,
            completedTaskCount: 0,
            completionRate: 0,
            createdAt: now,
            updatedAt: now,
            taskRefs: refs
        )

        context.insert(session)
        for ref in refs {
            ref.session = session
            context.insert(ref)
        }

        try context.saveIfChanged()
        return session
    }

    func addTasks(_ todos: [PLTodo], to session: PLFocusSession) throws {
        guard session.isActive else {
            throw PLServiceError.noActiveSession
        }

        let existing = Set(session.taskRefs.compactMap(\.todoId))
        let candidates = todos.filter { !existing.contains($0.id) }
        guard !candidates.isEmpty else { return }

        let now = Date()
        let startOrder = session.taskRefs.count

        for (offset, todo) in candidates.enumerated() {
            let ref = PLSessionTaskRef(
                id: UUID().uuidString,
                todoId: todo.id,
                titleSnapshot: todo.title,
                orderIndex: startOrder + offset,
                isCompletedInSession: false,
                completedAt: nil,
                createdAt: now,
                updatedAt: now
            )
            ref.session = session
            session.taskRefs.append(ref)
            context.insert(ref)
        }

        session.totalTaskCount = session.taskRefs.count
        session.updatedAt = now
        recalculate(session)
        try context.saveIfChanged()
    }

    func toggleTask(_ ref: PLSessionTaskRef, completed: Bool?) throws {
        let target = completed ?? !ref.isCompletedInSession
        ref.isCompletedInSession = target
        ref.completedAt = target ? Date() : nil
        ref.updatedAt = Date()

        guard let session = ref.session else {
            try context.saveIfChanged()
            return
        }

        recalculate(session)
        try context.saveIfChanged()
    }

    func endSession(_ session: PLFocusSession, elapsedSeconds: Int) throws {
        guard session.isActive else { return }

        session.state = "ended"
        session.elapsedSeconds = max(0, elapsedSeconds)
        session.endedAt = Date()
        session.updatedAt = Date()
        recalculate(session)

        for ref in session.taskRefs where ref.isCompletedInSession {
            if let todo = try fetchTodo(by: ref.todoId) {
                todo.status = "completed"
                todo.completedAt = session.endedAt
                todo.touch()
            }
        }

        try context.saveIfChanged()
    }

    func cancelSession(_ session: PLFocusSession) throws {
        guard session.isActive else { return }
        session.state = "ended"
        session.endedAt = Date()
        session.elapsedSeconds = 0
        session.completedTaskCount = 0
        session.completionRate = 0
        session.updatedAt = Date()
        try context.saveIfChanged()
    }

    func history(limit: Int = 120) throws -> [PLFocusSession] {
        let safeLimit = max(1, min(120, limit))
        var descriptor = FetchDescriptor<PLFocusSession>(
            predicate: #Predicate { $0.state == "ended" },
            sortBy: [SortDescriptor(\.endedAt, order: .reverse)]
        )
        descriptor.fetchLimit = safeLimit
        return try context.fetch(descriptor)
    }

    private func recalculate(_ session: PLFocusSession) {
        let completed = session.taskRefs.filter(\.isCompletedInSession).count
        let total = session.taskRefs.count
        session.completedTaskCount = completed
        session.totalTaskCount = total
        session.completionRate = total > 0 ? Double(completed) / Double(total) : 0
    }

    private func fetchTodo(by id: String?) throws -> PLTodo? {
        guard let id, !id.isEmpty else { return nil }
        let descriptor = FetchDescriptor<PLTodo>(predicate: #Predicate { $0.id == id })
        return try context.fetch(descriptor).first
    }
}
