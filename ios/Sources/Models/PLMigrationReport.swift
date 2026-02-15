import Foundation

struct PLMigrationReport {
    var importedTodos: Int
    var updatedTodos: Int
    var importedSessions: Int
    var updatedSessions: Int
    var importedTaskRefs: Int
    var updatedTaskRefs: Int
    var importedAuthConfig: Bool
    var skippedByFingerprint: Bool

    static let empty = PLMigrationReport(
        importedTodos: 0,
        updatedTodos: 0,
        importedSessions: 0,
        updatedSessions: 0,
        importedTaskRefs: 0,
        updatedTaskRefs: 0,
        importedAuthConfig: false,
        skippedByFingerprint: false
    )
}
