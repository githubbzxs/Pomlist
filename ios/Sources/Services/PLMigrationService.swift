import CryptoKit
import Foundation
import SwiftData

@MainActor
final class PLMigrationService: MigrationImporting {
    private let context: ModelContext
    private let decoder: JSONDecoder

    init(context: ModelContext) {
        self.context = context
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            let fractionalFormatter = ISO8601DateFormatter()
            fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractionalFormatter.date(from: value) {
                return date
            }

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date: \(value)")
        }
    }

    func importMigrationFile(from url: URL) throws -> PLMigrationReport {
        let data = try Data(contentsOf: url)
        let fingerprint = sha256(data)

        guard let authConfig = try loadAuthConfig() else {
            throw PLServiceError.invalidPasscode
        }

        if authConfig.lastMigrationFingerprint == fingerprint {
            var report = PLMigrationReport.empty
            report.skippedByFingerprint = true
            return report
        }

        let payload = try decoder.decode(PomlistMigrationV1.self, from: data)
        guard payload.schema == "PomlistMigrationV1" else {
            throw PLServiceError.decodeFailed
        }

        var report = PLMigrationReport.empty
        let existingTodos = try context.fetch(FetchDescriptor<PLTodo>())
        let existingSessions = try context.fetch(FetchDescriptor<PLFocusSession>())
        let existingRefs = try context.fetch(FetchDescriptor<PLSessionTaskRef>())

        var todoById = Dictionary(uniqueKeysWithValues: existingTodos.map { ($0.id, $0) })
        var sessionById = Dictionary(uniqueKeysWithValues: existingSessions.map { ($0.id, $0) })
        var refById = Dictionary(uniqueKeysWithValues: existingRefs.map { ($0.id, $0) })

        for todo in payload.todos {
            if let existing = todoById[todo.id] {
                if existing.updatedAt <= todo.updatedAt {
                    apply(todo: todo, to: existing)
                    report.updatedTodos += 1
                }
            } else {
                let entity = PLTodo(
                    id: todo.id,
                    title: todo.title,
                    notes: todo.notes ?? "",
                    category: todo.category,
                    tags: todo.tags,
                    priority: todo.priority,
                    status: todo.status,
                    dueAt: todo.dueAt,
                    completedAt: todo.completedAt,
                    createdAt: todo.createdAt,
                    updatedAt: todo.updatedAt
                )
                context.insert(entity)
                todoById[todo.id] = entity
                report.importedTodos += 1
            }
        }

        for session in payload.sessions {
            let sessionEntity: PLFocusSession

            if let existing = sessionById[session.id] {
                if existing.updatedAt <= session.updatedAt {
                    apply(session: session, to: existing)
                    report.updatedSessions += 1
                }
                sessionEntity = existing
            } else {
                let entity = PLFocusSession(
                    id: session.id,
                    state: session.state,
                    startedAt: session.startedAt,
                    endedAt: session.endedAt,
                    elapsedSeconds: session.elapsedSeconds,
                    totalTaskCount: session.totalTaskCount,
                    completedTaskCount: session.completedTaskCount,
                    completionRate: session.completionRate,
                    createdAt: session.createdAt,
                    updatedAt: session.updatedAt
                )
                context.insert(entity)
                sessionEntity = entity
                sessionById[session.id] = entity
                report.importedSessions += 1
            }

            for task in session.tasks {
                if let existingRef = refById[task.id] {
                    if existingRef.updatedAt <= task.updatedAt {
                        apply(task: task, to: existingRef)
                        existingRef.session = sessionEntity
                        report.updatedTaskRefs += 1
                    }
                } else {
                    let ref = PLSessionTaskRef(
                        id: task.id,
                        todoId: task.todoId,
                        titleSnapshot: task.titleSnapshot ?? task.todoTitle ?? "",
                        orderIndex: task.orderIndex,
                        isCompletedInSession: task.completed,
                        completedAt: task.completedAt,
                        createdAt: task.createdAt,
                        updatedAt: task.updatedAt
                    )
                    ref.session = sessionEntity
                    context.insert(ref)
                    sessionEntity.taskRefs.append(ref)
                    refById[task.id] = ref
                    report.importedTaskRefs += 1
                }
            }
        }

        if let passcode = payload.user?.passcode, passcode.count == 4 {
            authConfig.passcodeHash = hash(passcode)
            authConfig.touch()
            report.importedAuthConfig = true
        }

        authConfig.lastMigrationFingerprint = fingerprint
        authConfig.touch()

        try context.saveIfChanged()
        return report
    }

    private func loadAuthConfig() throws -> PLAuthConfig? {
        var descriptor = FetchDescriptor<PLAuthConfig>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func apply(todo: TodoDTO, to entity: PLTodo) {
        entity.title = todo.title
        entity.notes = todo.notes ?? ""
        entity.category = todo.category
        entity.tags = todo.tags
        entity.priority = todo.priority
        entity.status = todo.status
        entity.dueAt = todo.dueAt
        entity.completedAt = todo.completedAt
        entity.createdAt = todo.createdAt
        entity.updatedAt = todo.updatedAt
    }

    private func apply(session: SessionDTO, to entity: PLFocusSession) {
        entity.state = session.state
        entity.startedAt = session.startedAt
        entity.endedAt = session.endedAt
        entity.elapsedSeconds = session.elapsedSeconds
        entity.totalTaskCount = session.totalTaskCount
        entity.completedTaskCount = session.completedTaskCount
        entity.completionRate = session.completionRate
        entity.createdAt = session.createdAt
        entity.updatedAt = session.updatedAt
    }

    private func apply(task: SessionTaskDTO, to entity: PLSessionTaskRef) {
        entity.todoId = task.todoId
        entity.titleSnapshot = task.titleSnapshot ?? task.todoTitle ?? ""
        entity.orderIndex = task.orderIndex
        entity.isCompletedInSession = task.completed
        entity.completedAt = task.completedAt
        entity.createdAt = task.createdAt
        entity.updatedAt = task.updatedAt
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func hash(_ text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

private struct PomlistMigrationV1: Decodable {
    let schema: String
    let exportedAt: Date
    let user: UserDTO?
    let todos: [TodoDTO]
    let sessions: [SessionDTO]
}

private struct UserDTO: Decodable {
    let id: String?
    let email: String?
    let passcodeUpdatedAt: Date?
    let passcode: String?
}

private struct TodoDTO: Decodable {
    let id: String
    let title: String
    let subject: String?
    let notes: String?
    let category: String
    let tags: [String]
    let priority: Int
    let status: String
    let dueAt: Date?
    let completedAt: Date?
    let createdAt: Date
    let updatedAt: Date
}

private struct SessionDTO: Decodable {
    let id: String
    let state: String
    let startedAt: Date
    let endedAt: Date?
    let elapsedSeconds: Int
    let totalTaskCount: Int
    let completedTaskCount: Int
    let completionRate: Double
    let createdAt: Date
    let updatedAt: Date
    let tasks: [SessionTaskDTO]
}

private struct SessionTaskDTO: Decodable {
    let id: String
    let todoId: String?
    let todoTitle: String?
    let titleSnapshot: String?
    let orderIndex: Int
    let completed: Bool
    let completedAt: Date?
    let createdAt: Date
    let updatedAt: Date
}
