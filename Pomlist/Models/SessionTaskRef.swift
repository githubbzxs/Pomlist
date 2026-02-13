import Foundation
import SwiftData

@Model
final class SessionTaskRef {
    @Attribute(.unique) var id: UUID
    var session: FocusSession?
    var todoId: UUID
    var titleSnapshot: String
    var orderIndex: Int
    var isCompletedInSession: Bool
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        session: FocusSession? = nil,
        todoId: UUID,
        titleSnapshot: String,
        orderIndex: Int,
        isCompletedInSession: Bool = false,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.session = session
        self.todoId = todoId
        self.titleSnapshot = titleSnapshot
        self.orderIndex = orderIndex
        self.isCompletedInSession = isCompletedInSession
        self.completedAt = completedAt
    }
}

