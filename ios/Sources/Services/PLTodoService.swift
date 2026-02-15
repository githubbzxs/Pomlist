import Foundation
import SwiftData

@MainActor
final class PLTodoService: TodoManaging {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchTodos(status: String? = nil) throws -> [PLTodo] {
        var descriptor = FetchDescriptor<PLTodo>(sortBy: [
            SortDescriptor(\.updatedAt, order: .reverse)
        ])

        if let status, !status.isEmpty {
            descriptor.predicate = #Predicate<PLTodo> { todo in
                todo.status == status
            }
        }

        return try context.fetch(descriptor)
    }

    func createTodo(
        title: String,
        notes: String,
        category: String,
        tags: [String],
        priority: Int,
        dueAt: Date?
    ) throws -> PLTodo {
        let now = Date()
        let todo = PLTodo(
            id: UUID().uuidString,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            category: normalizedCategory(category),
            tags: normalizedTags(tags),
            priority: max(1, min(3, priority)),
            status: "pending",
            dueAt: dueAt,
            completedAt: nil,
            createdAt: now,
            updatedAt: now
        )
        context.insert(todo)
        try context.saveIfChanged()
        return todo
    }

    func updateTodo(
        _ todo: PLTodo,
        title: String,
        notes: String,
        category: String,
        tags: [String],
        priority: Int,
        dueAt: Date?
    ) throws {
        todo.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        todo.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        todo.category = normalizedCategory(category)
        todo.tags = normalizedTags(tags)
        todo.priority = max(1, min(3, priority))
        todo.dueAt = dueAt
        todo.touch()
        try context.saveIfChanged()
    }

    func toggleTodo(_ todo: PLTodo, completed: Bool) throws {
        todo.status = completed ? "completed" : "pending"
        todo.completedAt = completed ? Date() : nil
        todo.touch()
        try context.saveIfChanged()
    }

    func deleteTodo(_ todo: PLTodo) throws {
        context.delete(todo)
        try context.saveIfChanged()
    }

    private func normalizedCategory(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未分类" : trimmed
    }

    private func normalizedTags(_ tags: [String]) -> [String] {
        let values = tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(Set(values)).sorted()
    }
}
