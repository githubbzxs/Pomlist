import Foundation

@MainActor
protocol SessionManaging {
    var activeSession: PLFocusSession? { get }
    @discardableResult func loadActiveSession() throws -> PLFocusSession?
    func startSession(with todos: [PLTodo], plannedMinutes: Int) throws -> PLFocusSession
    func appendTasks(_ todos: [PLTodo], to session: PLFocusSession) throws
    func finishSession(_ session: PLFocusSession, elapsedSeconds: Int) throws
    func cancelSession(_ session: PLFocusSession) throws
    func fetchHistory(limit: Int) throws -> [PLFocusSession]
}

@MainActor
protocol TodoManaging {
    func fetchTodos(includeCompleted: Bool) throws -> [PLTodo]
    func createTodo(title: String, detail: String, category: String, tags: [String]) throws -> PLTodo
    func toggleTodo(_ todo: PLTodo) throws
    func updateTodo(_ todo: PLTodo, title: String, detail: String, category: String, tags: [String]) throws
    func deleteTodo(_ todo: PLTodo) throws
}

@MainActor
protocol AnalyticsProviding {
    func buildSnapshot(days: Int) throws -> PLAnalyticsSnapshot
}

@MainActor
protocol AuthUnlocking: AnyObject {
    var isUnlocked: Bool { get }
    func ensureConfigExists() throws
    func unlock(passcode: String) throws -> Bool
    func updatePasscode(oldPasscode: String, newPasscode: String) throws
    func lock()
}

@MainActor
protocol MigrationImporting {
    @discardableResult
    func importLegacyDataIfNeeded(from fileURL: URL?) throws -> PLMigrationReport
}
