import Foundation

struct PLMigrationReport {
    var importedTodos: Int = 0
    var importedSessions: Int = 0
    var importedAuthConfig: Bool = false

    static let empty = PLMigrationReport()
}
