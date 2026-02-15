import Foundation
import SwiftUI

enum PLTodayPanel: CaseIterable {
    case center
    case right
    case down
    case up
}

struct PLTodayDisplayTask: Identifiable {
    let id: String
    let title: String
    let completed: Bool
}

@MainActor
final class TodayCanvasViewModel: ObservableObject {
    private let serviceHub: PLServiceHub
    private var ticker: Timer?

    @Published private(set) var isInitialLoading = true
    @Published private(set) var isRefreshing = false
    @Published private(set) var isStartingSession = false
    @Published private(set) var isEndingSession = false
    @Published private(set) var isCreatingTask = false
    @Published private(set) var isSavingTaskEditor = false
    @Published private(set) var isDeletingTask = false
    @Published private(set) var isMutatingTags = false

    @Published private(set) var todos: [PLTodo] = []
    @Published private(set) var activeSession: PLFocusSession?
    @Published private(set) var historySessions: [PLFocusSession] = []
    @Published private(set) var analyticsSnapshot: PLAnalyticsSnapshot = .empty
    @Published private(set) var elapsedSeconds = 0
    @Published private(set) var lastEndedSeconds: Int?

    @Published var plannedTodoIDs: [String] = []
    @Published var draftChecks: [String: Bool] = [:]

    @Published var tagRegistry: [String] = []
    @Published var tagColorMap: [String: String] = [:]

    @Published var errorMessage: String?

    private let tagRegistryKey = "pomlist.meta.tags.ios"
    private let tagColorMapKey = "pomlist.meta.colors.ios"

    init(serviceHub: PLServiceHub) {
        self.serviceHub = serviceHub
        loadTagRegistry()
    }

    deinit {
        ticker?.invalidate()
    }

    var pendingTodos: [PLTodo] {
        todos.filter { $0.status == "pending" }
    }

    var libraryTodos: [PLTodo] {
        todos.sorted { lhs, rhs in
            if lhs.status == rhs.status {
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.status == "pending"
        }
    }

    var centerTasks: [PLTodayDisplayTask] {
        if let activeSession {
            return activeSession.taskRefs
                .sorted(by: { $0.orderIndex < $1.orderIndex })
                .map { ref in
                    PLTodayDisplayTask(
                        id: ref.todoId ?? ref.id,
                        title: ref.titleSnapshot,
                        completed: ref.isCompletedInSession
                    )
                }
        }

        let map = Dictionary(uniqueKeysWithValues: todos.map { ($0.id, $0) })
        return plannedTodoIDs.compactMap { id in
            guard let todo = map[id], todo.status == "pending" else { return nil }
            return PLTodayDisplayTask(id: todo.id, title: todo.title, completed: draftChecks[id] == true)
        }
    }

    var completedCount: Int {
        centerTasks.filter(\.completed).count
    }

    var totalCount: Int {
        centerTasks.count
    }

    var displaySeconds: Int {
        guard activeSession != nil else { return 0 }
        return elapsedSeconds
    }

    var tagOptions: [String] {
        let fromTodos = todos.flatMap(\.tags)
        let merged = mergeUniqueValues(tagRegistry + fromTodos)
        return merged.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var canStartSession: Bool {
        activeSession == nil && !plannedTodoIDs.isEmpty && !isStartingSession
    }

    func loadInitialData() {
        isInitialLoading = true
        reloadAll()
        isInitialLoading = false
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        reloadAll()
        isRefreshing = false
    }

    func togglePlan(todoID: String) {
        if let session = activeSession {
            guard let todo = todos.first(where: { $0.id == todoID }) else { return }
            let existing = Set(session.taskRefs.compactMap(\.todoId))
            if existing.contains(todoID) || todo.status != "pending" {
                return
            }

            do {
                try requireSessionService().addTasks([todo], to: session)
                reloadAll()
            } catch {
                setError(error)
            }
            return
        }

        if plannedTodoIDs.contains(todoID) {
            plannedTodoIDs.removeAll(where: { $0 == todoID })
            draftChecks.removeValue(forKey: todoID)
        } else {
            plannedTodoIDs.append(todoID)
        }
    }

    func toggleCenterTask(taskID: String, completed: Bool) {
        if let activeSession {
            do {
                guard let ref = activeSession.taskRefs.first(where: { ($0.todoId ?? $0.id) == taskID }) else { return }
                try requireSessionService().toggleTask(ref, completed: completed)
                reloadAll()
            } catch {
                setError(error)
            }
            return
        }

        draftChecks[taskID] = completed
    }

    func startSession() {
        guard canStartSession else { return }
        isStartingSession = true
        defer { isStartingSession = false }

        do {
            let todoMap = Dictionary(uniqueKeysWithValues: pendingTodos.map { ($0.id, $0) })
            let picked = plannedTodoIDs.compactMap { todoMap[$0] }
            let created = try requireSessionService().startSession(with: picked)
            activeSession = created
            plannedTodoIDs = created.taskRefs.sorted(by: { $0.orderIndex < $1.orderIndex }).compactMap(\.todoId)
            draftChecks = [:]
            lastEndedSeconds = nil
            syncElapsed()
            startTicker()
            refresh()
        } catch {
            setError(error)
        }
    }

    func endSession() {
        guard let activeSession, !isEndingSession else { return }
        isEndingSession = true
        defer { isEndingSession = false }

        do {
            let elapsed = displaySeconds
            try requireSessionService().endSession(activeSession, elapsedSeconds: elapsed)
            lastEndedSeconds = elapsed
            stopTicker()
            refresh()
        } catch {
            setError(error)
        }
    }

    func createTask(
        title: String,
        primaryTag: String,
        secondaryTag: String,
        content: String
    ) {
        guard !isCreatingTask else { return }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else {
            errorMessage = "任务标题不能为空。"
            return
        }

        isCreatingTask = true
        defer { isCreatingTask = false }

        do {
            let tags = normalizeTags([primaryTag, secondaryTag])
            let created = try requireTodoService().createTodo(
                title: cleanTitle,
                notes: content.trimmingCharacters(in: .whitespacesAndNewlines),
                category: tags.first ?? "未分类",
                tags: tags,
                priority: 2,
                dueAt: nil
            )

            attachTagDefaults(tags)

            if let activeSession {
                try requireSessionService().addTasks([created], to: activeSession)
            } else {
                plannedTodoIDs.append(created.id)
            }

            refresh()
        } catch {
            setError(error)
        }
    }

    func saveTaskEditor(
        todoID: String,
        primaryTag: String,
        secondaryTag: String,
        content: String
    ) {
        guard !isSavingTaskEditor else { return }
        guard let todo = todos.first(where: { $0.id == todoID }) else {
            errorMessage = "未找到任务。"
            return
        }

        isSavingTaskEditor = true
        defer { isSavingTaskEditor = false }

        do {
            let tags = normalizeTags([primaryTag, secondaryTag])
            try requireTodoService().updateTodo(
                todo,
                title: todo.title,
                notes: content.trimmingCharacters(in: .whitespacesAndNewlines),
                category: tags.first ?? "未分类",
                tags: tags,
                priority: todo.priority,
                dueAt: todo.dueAt
            )
            attachTagDefaults(tags)
            refresh()
        } catch {
            setError(error)
        }
    }

    func deleteTask(todoID: String) {
        guard !isDeletingTask else { return }
        guard let todo = todos.first(where: { $0.id == todoID }) else {
            errorMessage = "未找到任务。"
            return
        }

        isDeletingTask = true
        defer { isDeletingTask = false }

        do {
            try requireTodoService().deleteTodo(todo)
            plannedTodoIDs.removeAll(where: { $0 == todoID })
            draftChecks.removeValue(forKey: todoID)
            refresh()
        } catch {
            setError(error)
        }
    }

    func addTag(name: String, colorHex: String) -> String {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            return "标签名不能为空。"
        }
        guard !tagOptions.contains(normalizedName) else {
            return "标签已存在。"
        }

        let normalizedColor = normalizedHex(colorHex) ?? Self.defaultTagColor
        tagRegistry = mergeUniqueValues(tagRegistry + [normalizedName])
        tagColorMap[normalizedName] = normalizedColor
        persistTagRegistry()
        return "已新增标签。"
    }

    func renameTag(source: String, target: String) -> String {
        guard !isMutatingTags else { return "标签操作进行中，请稍后。" }
        let normalized = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return "标签不能为空。"
        }
        guard normalized != source else {
            return "标签名没有变化。"
        }
        guard !tagOptions.contains(normalized) else {
            return "标签已存在。"
        }

        isMutatingTags = true
        defer { isMutatingTags = false }

        do {
            for todo in todos where todo.tags.contains(source) {
                let updatedTags = normalizeTags(todo.tags.map { $0 == source ? normalized : $0 })
                try requireTodoService().updateTodo(
                    todo,
                    title: todo.title,
                    notes: todo.notes,
                    category: updatedTags.first ?? "未分类",
                    tags: updatedTags,
                    priority: todo.priority,
                    dueAt: todo.dueAt
                )
            }

            let sourceColor = tagColorMap[source]
            tagRegistry = mergeUniqueValues(tagRegistry.filter { $0 != source } + [normalized])
            tagColorMap.removeValue(forKey: source)
            tagColorMap[normalized] = normalizedHex(sourceColor) ?? Self.defaultTagColor
            persistTagRegistry()
            refresh()
            return "标签已重命名。"
        } catch {
            setError(error)
            return "重命名失败。"
        }
    }

    func deleteTag(name: String) -> String {
        guard !isMutatingTags else { return "标签操作进行中，请稍后。" }
        isMutatingTags = true
        defer { isMutatingTags = false }

        do {
            for todo in todos where todo.tags.contains(name) {
                let updatedTags = normalizeTags(todo.tags.filter { $0 != name })
                try requireTodoService().updateTodo(
                    todo,
                    title: todo.title,
                    notes: todo.notes,
                    category: updatedTags.first ?? "未分类",
                    tags: updatedTags,
                    priority: todo.priority,
                    dueAt: todo.dueAt
                )
            }

            tagRegistry.removeAll(where: { $0 == name })
            tagColorMap.removeValue(forKey: name)
            persistTagRegistry()
            refresh()
            return "标签已删除。"
        } catch {
            setError(error)
            return "删除标签失败。"
        }
    }

    func updateTagColor(tag: String, hex: String) {
        guard let normalized = normalizedHex(hex) else { return }
        tagColorMap[tag] = normalized
        persistTagRegistry()
    }

    func tagColorHex(for tag: String) -> String {
        normalizedHex(tagColorMap[tag]) ?? Self.defaultTagColor
    }

    func clearError() {
        errorMessage = nil
    }

    private func reloadAll() {
        do {
            let todoService = try requireTodoService()
            let sessionService = try requireSessionService()
            let analyticsService = try requireAnalyticsService()

            todos = try todoService.fetchTodos(status: nil)
            activeSession = try sessionService.loadActiveSession()
            historySessions = try sessionService.history(limit: 120)
            analyticsSnapshot = try analyticsService.snapshot()

            syncPlannedTasks()
            syncElapsed()
            syncTagRegistryWithTodos()
            errorMessage = nil
        } catch {
            setError(error)
        }
    }

    private func syncPlannedTasks() {
        let pendingIDs = Set(pendingTodos.map(\.id))

        if let activeSession {
            plannedTodoIDs = activeSession.taskRefs
                .sorted(by: { $0.orderIndex < $1.orderIndex })
                .compactMap(\.todoId)
            draftChecks = [:]
            return
        }

        plannedTodoIDs = plannedTodoIDs.filter { pendingIDs.contains($0) }
        draftChecks = draftChecks.filter { pendingIDs.contains($0.key) }
    }

    private func syncElapsed() {
        guard let activeSession else {
            elapsedSeconds = 0
            stopTicker()
            return
        }
        elapsedSeconds = max(activeSession.elapsedSeconds, Int(Date().timeIntervalSince(activeSession.startedAt)))
        startTicker()
    }

    private func startTicker() {
        ticker?.invalidate()
        guard let activeSession else { return }

        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard let current = self.activeSession, current.id == activeSession.id else { return }
                self.elapsedSeconds = max(current.elapsedSeconds, Int(Date().timeIntervalSince(current.startedAt)))
            }
        }
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func syncTagRegistryWithTodos() {
        let merged = mergeUniqueValues(tagRegistry + todos.flatMap(\.tags))
        if merged != tagRegistry {
            tagRegistry = merged
        }

        var next = tagColorMap
        for tag in merged where normalizedHex(next[tag]) == nil {
            next[tag] = Self.defaultTagColor
        }
        if next != tagColorMap {
            tagColorMap = next
        }
        persistTagRegistry()
    }

    private func attachTagDefaults(_ tags: [String]) {
        var changed = false

        let merged = mergeUniqueValues(tagRegistry + tags)
        if merged != tagRegistry {
            tagRegistry = merged
            changed = true
        }

        for tag in tags where normalizedHex(tagColorMap[tag]) == nil {
            tagColorMap[tag] = Self.defaultTagColor
            changed = true
        }

        if changed {
            persistTagRegistry()
        }
    }

    private func mergeUniqueValues(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in values {
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { continue }
            if seen.insert(value).inserted {
                result.append(value)
            }
        }
        return result
    }

    private func normalizeTags(_ tags: [String]) -> [String] {
        Array(mergeUniqueValues(tags).prefix(2))
    }

    private func loadTagRegistry() {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: tagRegistryKey),
           let data = raw.data(using: .utf8),
           let parsed = try? JSONDecoder().decode([String].self, from: data) {
            tagRegistry = mergeUniqueValues(parsed)
        }

        if let raw = defaults.string(forKey: tagColorMapKey),
           let data = raw.data(using: .utf8),
           let parsed = try? JSONDecoder().decode([String: String].self, from: data) {
            var cleaned: [String: String] = [:]
            for (key, value) in parsed {
                if let normalized = normalizedHex(value) {
                    cleaned[key] = normalized
                }
            }
            tagColorMap = cleaned
        }
    }

    private func persistTagRegistry() {
        let defaults = UserDefaults.standard
        if let tagsData = try? JSONEncoder().encode(tagRegistry),
           let tagsString = String(data: tagsData, encoding: .utf8) {
            defaults.set(tagsString, forKey: tagRegistryKey)
        }

        if let mapData = try? JSONEncoder().encode(tagColorMap),
           let mapString = String(data: mapData, encoding: .utf8) {
            defaults.set(mapString, forKey: tagColorMapKey)
        }
    }

    private func normalizedHex(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = "^#[0-9a-fA-F]{6}$"
        guard trimmed.range(of: pattern, options: .regularExpression) != nil else {
            return nil
        }
        return trimmed.lowercased()
    }

    private func setError(_ error: Error) {
        if let localized = error as? LocalizedError, let message = localized.errorDescription {
            errorMessage = message
        } else {
            errorMessage = error.localizedDescription
        }
    }

    private func requireTodoService() throws -> PLTodoService {
        guard let service = serviceHub.todoService else {
            throw TodayCanvasViewModelError.serviceUnavailable("任务服务不可用。")
        }
        return service
    }

    private func requireSessionService() throws -> PLSessionService {
        guard let service = serviceHub.sessionService else {
            throw TodayCanvasViewModelError.serviceUnavailable("会话服务不可用。")
        }
        return service
    }

    private func requireAnalyticsService() throws -> PLAnalyticsService {
        guard let service = serviceHub.analyticsService else {
            throw TodayCanvasViewModelError.serviceUnavailable("统计服务不可用。")
        }
        return service
    }

    static let defaultTagColor = "#1d4ed8"
}

private enum TodayCanvasViewModelError: LocalizedError {
    case serviceUnavailable(String)

    var errorDescription: String? {
        switch self {
        case let .serviceUnavailable(message):
            return message
        }
    }
}

extension PLAnalyticsSnapshot {
    static let empty = PLAnalyticsSnapshot(
        todaySessions: 0,
        todayDurationSeconds: 0,
        streakDays: 0,
        sessionsLast7Days: 0,
        sessionsLast30Days: 0,
        avgCompletionRate: 0,
        categoryDistribution: [],
        hourlyDistribution: []
    )
}
