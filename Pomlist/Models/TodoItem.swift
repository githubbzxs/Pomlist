import Foundation
import SwiftData

@Model
final class TodoItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var subject: String?
    var notes: String?
    var priorityValue: Int
    var dueAt: Date?
    var statusValue: String
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        subject: String? = nil,
        notes: String? = nil,
        priority: TodoPriority = .medium,
        dueAt: Date? = nil,
        status: TodoStatus = .pending,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.subject = subject
        self.notes = notes
        self.priorityValue = priority.rawValue
        self.dueAt = dueAt
        self.statusValue = status.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }

    var status: TodoStatus {
        get { TodoStatus(rawValue: statusValue) ?? .pending }
        set { statusValue = newValue.rawValue }
    }

    var priority: TodoPriority {
        get { TodoPriority(rawValue: priorityValue) ?? .medium }
        set { priorityValue = newValue.rawValue }
    }
}

