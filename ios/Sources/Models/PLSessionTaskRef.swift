import Foundation
import SwiftData

@Model
final class PLSessionTaskRef {
    @Attribute(.unique) var id: String
    var todoId: String?
    var titleSnapshot: String
    var orderIndex: Int
    var isCompletedInSession: Bool
    var completedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    var session: PLFocusSession?

    init(
        id: String,
        todoId: String?,
        titleSnapshot: String,
        orderIndex: Int,
        isCompletedInSession: Bool,
        completedAt: Date?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.todoId = todoId
        self.titleSnapshot = titleSnapshot
        self.orderIndex = max(0, orderIndex)
        self.isCompletedInSession = isCompletedInSession
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
