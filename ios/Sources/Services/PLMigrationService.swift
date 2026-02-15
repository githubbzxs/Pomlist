import CryptoKit
import Foundation
import SwiftData

@MainActor
final class PLMigrationService: MigrationImporting {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    func importLegacyDataIfNeeded(from fileURL: URL?) throws -> PLMigrationReport {
        guard let fileURL else { return .empty }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .empty }

        let data = try Data(contentsOf: fileURL)
        let payload = try JSONDecoder().decode(LegacyPayload.self, from: data)
        var report = PLMigrationReport.empty

        if try context.fetchCount(FetchDescriptor<PLTodo>()) == 0 {
            for todo in payload.todos {
                let item = PLTodo(
                    id: todo.id,
                    title: todo.title,
                    detail: todo.detail ?? "",
                    category: todo.category ?? "默认",
                    tags: todo.tags,
                    isDone: todo.isDone,
                    createdAt: todo.createdAt,
                    updatedAt: todo.updatedAt
                )
                context.insert(item)
            }
            report.importedTodos = payload.todos.count
        }

        if try context.fetchCount(FetchDescriptor<PLFocusSession>()) == 0 {
            for rawSession in payload.sessions {
                let session = PLFocusSession(
                    id: rawSession.id,
                    startedAt: rawSession.startedAt,
                    endedAt: rawSession.endedAt,
                    plannedMinutes: rawSession.plannedMinutes,
                    elapsedSeconds: rawSession.elapsedSeconds,
                    isCancelled: rawSession.isCancelled,
                    completedTaskCount: rawSession.taskRefs.filter { $0.wasDoneAtEnd }.count
                )
                context.insert(session)

                for rawRef in rawSession.taskRefs {
                    let ref = PLSessionTaskRef(
                        id: rawRef.id,
                        todoID: rawRef.todoID,
                        todoTitleSnapshot: rawRef.todoTitleSnapshot,
                        categorySnapshot: rawRef.categorySnapshot,
                        tagsSnapshot: rawRef.tagsSnapshot.joined(separator: ","),
                        wasDoneAtEnd: rawRef.wasDoneAtEnd,
                        createdAt: rawRef.createdAt
                    )
                    ref.session = session
                    context.insert(ref)
                }
            }
            report.importedSessions = payload.sessions.count
        }

        if let passcode = payload.passcode, passcode.count == 4,
           try context.fetchCount(FetchDescriptor<PLAuthConfig>()) == 0
        {
            let auth = PLAuthConfig(passcodeHash: hash(passcode))
            context.insert(auth)
            report.importedAuthConfig = true
        }

        try context.saveIfNeeded()
        return report
    }

    private func hash(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

private struct LegacyPayload: Decodable {
    var todos: [LegacyTodo] = []
    var sessions: [LegacySession] = []
    var passcode: String?
}

private struct LegacyTodo: Decodable {
    var id: UUID
    var title: String
    var detail: String?
    var category: String?
    var tags: [String]
    var isDone: Bool
    var createdAt: Date
    var updatedAt: Date
}

private struct LegacySession: Decodable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var plannedMinutes: Int
    var elapsedSeconds: Int
    var isCancelled: Bool
    var taskRefs: [LegacySessionTaskRef]
}

private struct LegacySessionTaskRef: Decodable {
    var id: UUID
    var todoID: UUID
    var todoTitleSnapshot: String
    var categorySnapshot: String
    var tagsSnapshot: [String]
    var wasDoneAtEnd: Bool
    var createdAt: Date
}
