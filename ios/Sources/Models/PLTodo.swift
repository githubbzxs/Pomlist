import Foundation
import SwiftData

@Model
final class PLTodo {
    @Attribute(.unique) var id: UUID
    var title: String
    var detail: String
    var category: String
    var tagsRaw: String
    var isDone: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        detail: String = "",
        category: String = "默认",
        tags: [String] = [],
        isDone: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.category = category
        self.tagsRaw = tags.joined(separator: ",")
        self.isDone = isDone
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var tags: [String] {
        get {
            tagsRaw
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        set {
            tagsRaw = newValue
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: ",")
        }
    }

    func touch() {
        updatedAt = .now
    }
}
