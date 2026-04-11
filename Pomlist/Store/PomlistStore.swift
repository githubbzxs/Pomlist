import Foundation
import SwiftUI

@MainActor
final class PomlistStore: ObservableObject {
    @Published private(set) var isBootstrapping = true
    @Published private(set) var database = AppDatabase()
    @Published var errorMessage: String?
    @Published var infoMessage: String?
    @Published var lastEndedDurationSeconds: Int?

    private let storage: PomlistStorageService
    private var hasLoaded = false

    init(storage: PomlistStorageService = PomlistStorageService()) {
        self.storage = storage
    }

    var isAuthenticated: Bool {
        database.auth.isAuthenticated
    }

    var todos: [TodoItem] {
        database.todos.sorted { left, right in
            if left.status != right.status {
                return left.status == .pending
            }
            if left.isCompleted != right.isCompleted {
                return !left.isCompleted
            }
            return left.updatedAt > right.updatedAt
        }
    }

    var activeSession: FocusSession? {
        database.sessions.first(where: { $0.state == .active })
    }

    var sessionHistory: [FocusSession] {
        database.sessions
            .filter { $0.state == .ended }
            .sorted { ($0.endedAt ?? $0.startedAt) > ($1.endedAt ?? $1.startedAt) }
    }

    var dashboard: DashboardMetrics {
        PomlistAnalyticsService.buildDashboard(from: database.sessions)
    }

    var categories: [String] {
        let values = Set(database.categoryRegistry + database.todos.map(\.category).filter { !$0.isEmpty })
        return values.sorted()
    }

    var tags: [String] {
        let values = Set(database.tagRegistry + database.todos.flatMap(\.tags).filter { !$0.isEmpty })
        return values.sorted()
    }

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        do {
            database = try storage.load()
        } catch {
            errorMessage = "读取本地数据失败：\(error.localizedDescription)"
        }
        isBootstrapping = false
    }

    func signIn(passcode: String) {
        let normalized = passcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count == 4 else {
            errorMessage = "口令必须是 4 个字符。"
            return
        }
        guard normalized == database.auth.passcode else {
            errorMessage = "口令不正确。"
            return
        }

        database.auth.isAuthenticated = true
        database.auth.updatedAt = .now
        persist(successMessage: nil)
    }

    func signOut() {
        database.auth.isAuthenticated = false
        database.auth.updatedAt = .now
        persist(successMessage: "已退出登录。")
    }

    func changePasscode(oldPasscode: String, newPasscode: String) {
        guard oldPasscode == database.auth.passcode else {
            errorMessage = "旧口令不正确。"
            return
        }

        let normalized = newPasscode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count == 4 else {
            errorMessage = "新口令必须是 4 个字符。"
            return
        }

        database.auth.passcode = normalized
        database.auth.updatedAt = .now
        persist(successMessage: "口令已更新。")
    }

    func upsertTodo(_ draft: TaskDraft, editing todo: TodoItem? = nil) {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            errorMessage = "任务标题不能为空。"
            return
        }

        let category = normalizeCategory(draft.category)
        let tags = normalizeTags(draft.tags)
        let notes = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)

        if let todo {
            guard let index = database.todos.firstIndex(where: { $0.id == todo.id }) else { return }
            database.todos[index].title = title
            database.todos[index].category = category
            database.todos[index].tags = tags
            database.todos[index].notes = notes
            database.todos[index].updatedAt = .now
            registerMetadata(category: category, tags: tags)
            syncActiveSessionSnapshots(for: database.todos[index])
            persist(successMessage: "任务已保存。")
            return
        }

        let newTodo = TodoItem(title: title, notes: notes, category: category, tags: tags)
        registerMetadata(category: category, tags: tags)
        database.todos.insert(newTodo, at: 0)
        persist(successMessage: "任务已创建。")
    }

    func toggleTodoCompletion(id: String) {
        guard let index = database.todos.firstIndex(where: { $0.id == id }) else { return }
        let now = Date()
        let willComplete = !database.todos[index].isCompleted
        database.todos[index].status = willComplete ? .completed : .pending
        database.todos[index].completedAt = willComplete ? now : nil
        database.todos[index].updatedAt = now
        persist(successMessage: nil)
    }

    func deleteTodo(id: String) {
        database.todos.removeAll { $0.id == id }
        persist(successMessage: "任务已删除。")
    }

    func startSession(todoIDs: [String]) {
        guard activeSession == nil else {
            errorMessage = "当前已有进行中的任务钟。"
            return
        }

        let selectedTodos = todoIDs.compactMap { id in
            database.todos.first(where: { $0.id == id })
        }

        guard !selectedTodos.isEmpty else {
            errorMessage = "至少选择一个任务后再开始。"
            return
        }

        let snapshots = selectedTodos.enumerated().map { index, todo in
            SessionTaskSnapshot(
                todoID: todo.id,
                titleSnapshot: todo.title,
                categorySnapshot: todo.category,
                tagSnapshot: todo.tags,
                orderIndex: index
            )
        }

        let session = FocusSession(
            state: .active,
            startedAt: .now,
            totalTaskCount: snapshots.count,
            tasks: snapshots
        )

        database.sessions.insert(session, at: 0)
        persist(successMessage: "任务钟已开始。")
    }

    func addTasksToActiveSession(todoIDs: [String]) {
        guard let sessionIndex = database.sessions.firstIndex(where: { $0.state == .active }) else {
            errorMessage = "当前没有进行中的任务钟。"
            return
        }

        let existingTodoIDs = Set(database.sessions[sessionIndex].tasks.map(\.todoID))
        let candidates = todoIDs
            .filter { !existingTodoIDs.contains($0) }
            .compactMap { id in database.todos.first(where: { $0.id == id }) }

        guard !candidates.isEmpty else {
            errorMessage = "没有可追加的新任务。"
            return
        }

        let currentCount = database.sessions[sessionIndex].tasks.count
        let newSnapshots = candidates.enumerated().map { offset, todo in
            SessionTaskSnapshot(
                todoID: todo.id,
                titleSnapshot: todo.title,
                categorySnapshot: todo.category,
                tagSnapshot: todo.tags,
                orderIndex: currentCount + offset
            )
        }

        database.sessions[sessionIndex].tasks.append(contentsOf: newSnapshots)
        recalculateProgress(forSessionAt: sessionIndex)
        persist(successMessage: "任务已加入当前专注。")
    }

    func toggleSessionTask(sessionID: String, taskID: String) {
        guard let sessionIndex = database.sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        guard let taskIndex = database.sessions[sessionIndex].tasks.firstIndex(where: { $0.id == taskID }) else { return }

        database.sessions[sessionIndex].tasks[taskIndex].isCompletedInSession.toggle()
        database.sessions[sessionIndex].tasks[taskIndex].completedAt = database.sessions[sessionIndex].tasks[taskIndex].isCompletedInSession ? .now : nil
        recalculateProgress(forSessionAt: sessionIndex)
        persist(successMessage: nil)
    }

    func endActiveSession() {
        guard let sessionIndex = database.sessions.firstIndex(where: { $0.state == .active }) else {
            errorMessage = "当前没有进行中的任务钟。"
            return
        }

        let now = Date()
        database.sessions[sessionIndex].state = .ended
        database.sessions[sessionIndex].endedAt = now
        database.sessions[sessionIndex].elapsedSeconds = max(0, Int(now.timeIntervalSince(database.sessions[sessionIndex].startedAt)))
        database.sessions[sessionIndex].updatedAt = now
        recalculateProgress(forSessionAt: sessionIndex)
        lastEndedDurationSeconds = database.sessions[sessionIndex].elapsedSeconds
        persist(successMessage: "本次任务钟已结束。")
    }

    func dismissMessage() {
        errorMessage = nil
        infoMessage = nil
    }

    func addCategory(_ value: String) {
        let normalized = normalizeCategory(value)
        registerMetadata(category: normalized, tags: [])
        persist(successMessage: "分类已加入。")
    }

    func renameCategory(from oldValue: String, to newValue: String) {
        let normalized = normalizeCategory(newValue)
        guard normalized != oldValue else { return }

        database.categoryRegistry.removeAll { $0 == oldValue }
        database.categoryRegistry.append(normalized)

        for index in database.todos.indices where database.todos[index].category == oldValue {
            database.todos[index].category = normalized
            database.todos[index].updatedAt = .now
        }

        syncAllActiveSessionSnapshots()
        persist(successMessage: "分类已重命名。")
    }

    func deleteCategory(_ value: String) {
        database.categoryRegistry.removeAll { $0 == value }

        for index in database.todos.indices where database.todos[index].category == value {
            database.todos[index].category = "未分类"
            database.todos[index].updatedAt = .now
        }

        registerMetadata(category: "未分类", tags: [])
        syncAllActiveSessionSnapshots()
        persist(successMessage: "分类已删除，关联任务已回落到未分类。")
    }

    func addTag(_ value: String) {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            errorMessage = "标签不能为空。"
            return
        }

        if !database.tagRegistry.contains(normalized) {
            database.tagRegistry.append(normalized)
            database.tagRegistry.sort()
        }
        persist(successMessage: "标签已加入。")
    }

    func renameTag(from oldValue: String, to newValue: String) {
        let normalized = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            errorMessage = "标签不能为空。"
            return
        }
        guard normalized != oldValue else { return }

        database.tagRegistry.removeAll { $0 == oldValue }
        if !database.tagRegistry.contains(normalized) {
            database.tagRegistry.append(normalized)
        }

        for index in database.todos.indices {
            if database.todos[index].tags.contains(oldValue) {
                database.todos[index].tags = normalizeTags(
                    database.todos[index].tags.map { $0 == oldValue ? normalized : $0 }
                )
                database.todos[index].updatedAt = .now
            }
        }

        database.tagRegistry.sort()
        syncAllActiveSessionSnapshots()
        persist(successMessage: "标签已重命名。")
    }

    func deleteTag(_ value: String) {
        database.tagRegistry.removeAll { $0 == value }

        for index in database.todos.indices where database.todos[index].tags.contains(value) {
            database.todos[index].tags.removeAll { $0 == value }
            database.todos[index].updatedAt = .now
        }

        syncAllActiveSessionSnapshots()
        persist(successMessage: "标签已删除，并同步到任务数据。")
    }

    func draft(for todo: TodoItem?) -> TaskDraft {
        guard let todo else { return TaskDraft() }
        return TaskDraft(
            title: todo.title,
            category: todo.category,
            tagsText: todo.tags.joined(separator: ", "),
            notes: todo.notes
        )
    }

    private func normalizeCategory(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未分类" : trimmed
    }

    private func normalizeTags(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { tag in
                guard !seen.contains(tag) else { return false }
                seen.insert(tag)
                return true
            }
    }

    private func registerMetadata(category: String, tags: [String]) {
        if !database.categoryRegistry.contains(category) {
            database.categoryRegistry.append(category)
            database.categoryRegistry.sort()
        }

        for tag in tags where !database.tagRegistry.contains(tag) {
            database.tagRegistry.append(tag)
        }

        database.tagRegistry.sort()
    }

    private func recalculateProgress(forSessionAt sessionIndex: Int) {
        let completed = database.sessions[sessionIndex].tasks.filter(\.isCompletedInSession).count
        let total = database.sessions[sessionIndex].tasks.count
        database.sessions[sessionIndex].completedTaskCount = completed
        database.sessions[sessionIndex].totalTaskCount = total
        database.sessions[sessionIndex].completionRate = total == 0 ? 0 : Double(completed) / Double(total)
        database.sessions[sessionIndex].updatedAt = .now
    }

    private func syncActiveSessionSnapshots(for todo: TodoItem) {
        guard let sessionIndex = database.sessions.firstIndex(where: { $0.state == .active }) else { return }
        for taskIndex in database.sessions[sessionIndex].tasks.indices where database.sessions[sessionIndex].tasks[taskIndex].todoID == todo.id {
            database.sessions[sessionIndex].tasks[taskIndex].titleSnapshot = todo.title
            database.sessions[sessionIndex].tasks[taskIndex].categorySnapshot = todo.category
            database.sessions[sessionIndex].tasks[taskIndex].tagSnapshot = todo.tags
        }
    }

    private func syncAllActiveSessionSnapshots() {
        for todo in database.todos {
            syncActiveSessionSnapshots(for: todo)
        }
    }

    private func persist(successMessage: String?) {
        do {
            try storage.save(database)
            if let successMessage {
                infoMessage = successMessage
            }
        } catch {
            errorMessage = "写入本地数据失败：\(error.localizedDescription)"
        }
    }
}
