import Foundation
import SwiftData

@Model
final class PLTodo {
    @Attribute(.unique) var id: String
    var title: String
    var notes: String
    var category: String
    var tagsCSV: String
    var priority: Int
    var status: String
    var dueAt: Date?
    var completedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String,
        title: String,
        notes: String,
        category: String,
        tags: [String],
        priority: Int,
        status: String,
        dueAt: Date?,
        completedAt: Date?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.category = category
        self.tagsCSV = tags.joined(separator: ",")
        self.priority = max(1, min(3, priority))
        self.status = status
        self.dueAt = dueAt
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var tags: [String] {
        get {
            tagsCSV
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        set {
            tagsCSV = newValue
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: ",")
        }
    }

    var isCompleted: Bool {
        status == "completed"
    }

    func touch() {
        updatedAt = .now
    }
}
