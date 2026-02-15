import Foundation
import SwiftData

@Model
final class PLSessionTaskRef {
    @Attribute(.unique) var id: UUID
    var todoID: UUID
    var todoTitleSnapshot: String
    var categorySnapshot: String
    var tagsSnapshot: String
    var wasDoneAtEnd: Bool
    var createdAt: Date
    var session: PLFocusSession?

    init(
        id: UUID = UUID(),
        todoID: UUID,
        todoTitleSnapshot: String,
        categorySnapshot: String,
        tagsSnapshot: String,
        wasDoneAtEnd: Bool,
        createdAt: Date = .now
    ) {
        self.id = id
        self.todoID = todoID
        self.todoTitleSnapshot = todoTitleSnapshot
        self.categorySnapshot = categorySnapshot
        self.tagsSnapshot = tagsSnapshot
        self.wasDoneAtEnd = wasDoneAtEnd
        self.createdAt = createdAt
    }

    var tags: [String] {
        tagsSnapshot
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
