import Foundation
import SwiftData

enum TodoFilter {
    case all
    case pending
    case completed
}

struct TodoDraft {
    var title: String
    var subject: String
    var notes: String
    var priority: TodoPriority
    var dueAt: Date?
}

enum TodoValidationError: LocalizedError {
    case emptyTitle

    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "任务标题不能为空。"
        }
    }
}

enum TodoService {
    @discardableResult
    static func createTodo(from draft: TodoDraft, context: ModelContext, now: Date = .now) throws -> TodoItem {
        let cleanTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else {
            throw TodoValidationError.emptyTitle
        }

        let todo = TodoItem(
            title: cleanTitle,
            subject: normalized(draft.subject),
            notes: normalized(draft.notes),
            priority: draft.priority,
            dueAt: draft.dueAt,
            createdAt: now,
            updatedAt: now
        )
        context.insert(todo)
        try context.save()
        return todo
    }

    static func updateTodo(_ item: TodoItem, with draft: TodoDraft, context: ModelContext, now: Date = .now) throws {
        let cleanTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else {
            throw TodoValidationError.emptyTitle
        }

        item.title = cleanTitle
        item.subject = normalized(draft.subject)
        item.notes = normalized(draft.notes)
        item.priority = draft.priority
        item.dueAt = draft.dueAt
        item.updatedAt = now
        try context.save()
    }

    static func setCompleted(_ item: TodoItem, isCompleted: Bool, context: ModelContext, now: Date = .now) throws {
        item.status = isCompleted ? .completed : .pending
        item.completedAt = isCompleted ? now : nil
        item.updatedAt = now
        try context.save()
    }

    static func fetchTodos(filter: TodoFilter, context: ModelContext) throws -> [TodoItem] {
        let descriptor = FetchDescriptor<TodoItem>(
            sortBy: [
                SortDescriptor(\TodoItem.createdAt, order: .forward),
                SortDescriptor(\TodoItem.updatedAt, order: .reverse)
            ]
        )
        let all = try context.fetch(descriptor)
        switch filter {
        case .all:
            return all
        case .pending:
            return all.filter { $0.status == .pending }
        case .completed:
            return all.filter { $0.status == .completed }
        }
    }

    private static func normalized(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

