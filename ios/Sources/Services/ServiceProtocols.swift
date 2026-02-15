import Foundation

@MainActor
protocol TodoManaging {
    func fetchTodos(status: String?) throws -> [PLTodo]
    func createTodo(title: String, notes: String, category: String, tags: [String], priority: Int, dueAt: Date?) throws -> PLTodo
    func updateTodo(_ todo: PLTodo, title: String, notes: String, category: String, tags: [String], priority: Int, dueAt: Date?) throws
    func toggleTodo(_ todo: PLTodo, completed: Bool) throws
    func deleteTodo(_ todo: PLTodo) throws
}

@MainActor
protocol SessionManaging {
    func loadActiveSession() throws -> PLFocusSession?
    func startSession(with todos: [PLTodo]) throws -> PLFocusSession
    func addTasks(_ todos: [PLTodo], to session: PLFocusSession) throws
    func toggleTask(_ ref: PLSessionTaskRef, completed: Bool?) throws
    func endSession(_ session: PLFocusSession, elapsedSeconds: Int) throws
    func cancelSession(_ session: PLFocusSession) throws
    func history(limit: Int) throws -> [PLFocusSession]
}

@MainActor
protocol AnalyticsProviding {
    func snapshot() throws -> PLAnalyticsSnapshot
}

@MainActor
protocol AuthUnlocking {
    var isUnlocked: Bool { get }
    var isBiometricAvailable: Bool { get }
    func ensureConfigExists() throws
    func unlock(passcode: String) throws -> Bool
    func unlockWithBiometrics() async throws -> Bool
    func updatePasscode(oldPasscode: String, newPasscode: String) throws
    func lock()
}

@MainActor
protocol MigrationImporting {
    func importMigrationFile(from url: URL) throws -> PLMigrationReport
}
