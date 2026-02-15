import Foundation
import SwiftData

@MainActor
final class PLTodoService: TodoManaging {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchTodos(includeCompleted: Bool = true) throws -> [PLTodo] {
        var descriptor = FetchDescriptor<PLTodo>(
            sortBy: [
                SortDescriptor(\PLTodo.isDone),
                SortDescriptor(\PLTodo.updatedAt, order: .reverse)
            ]
        )
        if !includeCompleted {
            descriptor.predicate = #Predicate<PLTodo> { !$0.isDone }
        }
        return try context.fetch(descriptor)
    }

    func createTodo(title: String, detail: String, category: String, tags: [String]) throws -> PLTodo {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty else {
            throw PLServiceError.emptyTitle
        }

        let todo = PLTodo(
            title: normalizedTitle,
            detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
            category: normalizedCategory(category),
            tags: normalizedTags(tags)
        )
        context.insert(todo)
        try context.saveIfNeeded()
        return todo
    }

    func toggleTodo(_ todo: PLTodo) throws {
        todo.isDone.toggle()
        todo.touch()
        try context.saveIfNeeded()
    }

    func updateTodo(_ todo: PLTodo, title: String, detail: String, category: String, tags: [String]) throws {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty else {
            throw PLServiceError.emptyTitle
        }

        todo.title = normalizedTitle
        todo.detail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        todo.category = normalizedCategory(category)
        todo.tags = normalizedTags(tags)
        todo.touch()
        try context.saveIfNeeded()
    }

    func deleteTodo(_ todo: PLTodo) throws {
        context.delete(todo)
        try context.saveIfNeeded()
    }

    private func normalizedCategory(_ category: String) -> String {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "默认" : trimmed
    }

    private func normalizedTags(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for tag in tags {
            let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            guard seen.insert(key).inserted else { continue }
            result.append(trimmed)
        }
        return result
    }
}
