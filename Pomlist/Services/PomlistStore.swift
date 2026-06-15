import Foundation

@MainActor
final class PomlistStore: ObservableObject {
    @Published private(set) var data: PomlistData {
        didSet {
            persistence.save(data)
        }
    }
    @Published var isUnlocked: Bool = false
    @Published var selectedTab: AppTab = .today
    @Published var lastError: String?

    private let persistence: PomlistPersistence

    init(persistence: PomlistPersistence = .live) {
        self.persistence = persistence
        self.data = persistence.load()
    }

    var activeSession: FocusSession? {
        data.sessions.first { $0.state == .active }
    }

    var endedSessions: [FocusSession] {
        data.sessions
            .filter { $0.state == .ended }
            .sorted { $0.startedAt > $1.startedAt }
    }

    var todoTasks: [PomTask] {
        data.tasks
            .filter { $0.status == .todo }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var todayTasks: [PomTask] {
        let calendar = Calendar.current
        return data.tasks
            .filter { task in
                task.status == .todo || task.completedAt.map { calendar.isDateInToday($0) } == true
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var categories: [String] {
        data.categories.sorted { lhs, rhs in
            if lhs == rhs { return false }
            if lhs == "默认" { return true }
            if rhs == "默认" { return false }
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
    }

    var tags: [String] {
        data.tags.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    func unlock(passcode: String) -> Bool {
        let ok = PomlistHasher.hash(passcode) == data.passcodeHash
        if ok {
            isUnlocked = true
            lastError = nil
        } else {
            lastError = "口令不正确"
        }
        return ok
    }

    func lock() {
        isUnlocked = false
    }

    func changePasscode(current: String, newPasscode: String) -> Bool {
        guard PomlistHasher.hash(current) == data.passcodeHash else {
            lastError = "当前口令不正确"
            return false
        }
        guard newPasscode.count == 4, newPasscode.allSatisfy(\.isNumber) else {
            lastError = "新口令需为 4 位数字"
            return false
        }
        data.passcodeHash = PomlistHasher.hash(newPasscode)
        lastError = nil
        return true
    }

    func addTask(title: String, notes: String, category: String, tags: [String]) {
        let normalizedCategory = normalizeCategory(category)
        let normalizedTags = normalizeTags(tags)
        let task = PomTask(title: title.trimmingCharacters(in: .whitespacesAndNewlines), notes: notes, category: normalizedCategory, tags: normalizedTags)
        data.tasks.insert(task, at: 0)
        register(category: normalizedCategory, tags: normalizedTags)
    }

    func updateTask(_ task: PomTask, title: String, notes: String, category: String, tags: [String]) {
        guard let index = data.tasks.firstIndex(where: { $0.id == task.id }) else { return }
        let normalizedCategory = normalizeCategory(category)
        let normalizedTags = normalizeTags(tags)
        data.tasks[index].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        data.tasks[index].notes = notes
        data.tasks[index].category = normalizedCategory
        data.tasks[index].tags = normalizedTags
        data.tasks[index].updatedAt = Date()
        register(category: normalizedCategory, tags: normalizedTags)
    }

    func setTaskStatus(_ taskID: UUID, status: TaskStatus) {
        guard let index = data.tasks.firstIndex(where: { $0.id == taskID }) else { return }
        data.tasks[index].status = status
        data.tasks[index].updatedAt = Date()
        data.tasks[index].completedAt = status == .completed ? Date() : nil
    }

    func deleteTask(_ taskID: UUID) {
        data.tasks.removeAll { $0.id == taskID }
    }

    func addCategory(_ category: String) {
        let normalized = normalizeCategory(category)
        guard !data.categories.contains(normalized) else { return }
        data.categories.append(normalized)
    }

    func deleteCategory(_ category: String) {
        guard category != "默认" else { return }
        data.categories.removeAll { $0 == category }
        for index in data.tasks.indices where data.tasks[index].category == category {
            data.tasks[index].category = "默认"
            data.tasks[index].updatedAt = Date()
        }
        if !data.categories.contains("默认") {
            data.categories.append("默认")
        }
    }

    func addTag(_ tag: String) {
        let normalized = normalizeTags([tag])
        guard let value = normalized.first, !data.tags.contains(value) else { return }
        data.tags.append(value)
    }

    func deleteTag(_ tag: String) {
        data.tags.removeAll { $0 == tag }
        for index in data.tasks.indices {
            data.tasks[index].tags.removeAll { $0 == tag }
            data.tasks[index].updatedAt = Date()
        }
    }

    func startSession(taskIDs: Set<UUID>) {
        guard activeSession == nil else {
            lastError = "已有进行中的专注"
            return
        }
        let selectedTasks = data.tasks
            .filter { taskIDs.contains($0.id) }
            .sorted { $0.createdAt < $1.createdAt }
        guard !selectedTasks.isEmpty else {
            lastError = "请选择任务"
            return
        }
        let snapshots = selectedTasks.enumerated().map { index, task in
            SessionTaskSnapshot(task: task, orderIndex: index)
        }
        data.sessions.insert(FocusSession(tasks: snapshots), at: 0)
        selectedTab = .today
        lastError = nil
    }

    func addTasksToActiveSession(taskIDs: Set<UUID>) {
        guard let sessionIndex = activeSessionIndex else { return }
        let existing = Set(data.sessions[sessionIndex].tasks.map(\.taskId))
        let nextTasks = data.tasks
            .filter { taskIDs.contains($0.id) && !existing.contains($0.id) }
            .sorted { $0.createdAt < $1.createdAt }
        let startIndex = data.sessions[sessionIndex].tasks.count
        let snapshots = nextTasks.enumerated().map { offset, task in
            SessionTaskSnapshot(task: task, orderIndex: startIndex + offset)
        }
        data.sessions[sessionIndex].tasks.append(contentsOf: snapshots)
    }

    func toggleSessionTask(_ snapshotID: UUID) {
        guard let sessionIndex = activeSessionIndex,
              let taskIndex = data.sessions[sessionIndex].tasks.firstIndex(where: { $0.id == snapshotID })
        else { return }

        let willComplete = !data.sessions[sessionIndex].tasks[taskIndex].isCompletedInSession
        let completedAt = willComplete ? Date() : nil
        data.sessions[sessionIndex].tasks[taskIndex].isCompletedInSession = willComplete
        data.sessions[sessionIndex].tasks[taskIndex].completedAt = completedAt

        let taskID = data.sessions[sessionIndex].tasks[taskIndex].taskId
        if let libraryIndex = data.tasks.firstIndex(where: { $0.id == taskID }) {
            data.tasks[libraryIndex].status = willComplete ? .completed : .todo
            data.tasks[libraryIndex].completedAt = completedAt
            data.tasks[libraryIndex].updatedAt = Date()
        }
    }

    func endActiveSession() {
        guard let index = activeSessionIndex else { return }
        let now = Date()
        data.sessions[index].state = .ended
        data.sessions[index].endedAt = now
        data.sessions[index].elapsedSeconds = max(1, Int(now.timeIntervalSince(data.sessions[index].startedAt)))
    }

    func stats(for range: StatsRange) -> PomlistStats {
        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -(range.days - 1), to: calendar.startOfDay(for: now)) else {
            return .empty
        }
        let sessions = endedSessions.filter { $0.startedAt >= startDate }
        guard !sessions.isEmpty else {
            return PomlistStats(
                sessionCount: 0,
                totalSeconds: 0,
                completedTaskCount: 0,
                averageCompletionRate: 0,
                focusStreak: focusStreak(),
                categoryContributions: [],
                hourlyDistribution: Self.hoursTemplate(),
                trend: Self.trendTemplate(days: range.days, referenceDate: now)
            )
        }

        let totalSeconds = sessions.reduce(0) { $0 + $1.elapsedSeconds }
        let completedTasks = sessions.reduce(0) { $0 + $1.completedTaskCount }
        let averageRate = sessions.map(\.completionRate).reduce(0, +) / Double(sessions.count)

        var categoryMap: [String: (seconds: Int, completed: Int)] = [:]
        for session in sessions {
            let secondsPerTask = max(1, session.elapsedSeconds / max(1, session.totalTaskCount))
            for task in session.tasks {
                var entry = categoryMap[task.categorySnapshot, default: (0, 0)]
                entry.seconds += secondsPerTask
                entry.completed += task.isCompletedInSession ? 1 : 0
                categoryMap[task.categorySnapshot] = entry
            }
        }

        var hourMap = Dictionary(uniqueKeysWithValues: Self.hoursTemplate().map { ($0.hour, $0.seconds) })
        for session in sessions {
            let hour = calendar.component(.hour, from: session.startedAt)
            hourMap[hour, default: 0] += session.elapsedSeconds
        }

        let trend = Self.trendTemplate(days: range.days, referenceDate: now).map { point in
            let daySessions = sessions.filter { calendar.isDate($0.startedAt, inSameDayAs: point.date) }
            let seconds = daySessions.reduce(0) { $0 + $1.elapsedSeconds }
            let rate = daySessions.isEmpty ? 0 : daySessions.map(\.completionRate).reduce(0, +) / Double(daySessions.count)
            return DailyFocusPoint(date: point.date, seconds: seconds, completionRate: rate)
        }

        return PomlistStats(
            sessionCount: sessions.count,
            totalSeconds: totalSeconds,
            completedTaskCount: completedTasks,
            averageCompletionRate: averageRate,
            focusStreak: focusStreak(),
            categoryContributions: categoryMap.map { category, value in
                CategoryContribution(category: category, seconds: value.seconds, completedTasks: value.completed)
            }
            .sorted { $0.seconds > $1.seconds },
            hourlyDistribution: hourMap.map { HourlyContribution(hour: $0.key, seconds: $0.value) }
                .sorted { $0.hour < $1.hour },
            trend: trend
        )
    }

    func resetDemoData() {
        data = .seed()
        isUnlocked = false
    }

    private var activeSessionIndex: Int? {
        data.sessions.firstIndex { $0.state == .active }
    }

    private func normalizeCategory(_ category: String) -> String {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "默认" : trimmed
    }

    private func normalizeTags(_ tags: [String]) -> [String] {
        Array(
            Set(
                tags
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        )
        .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private func register(category: String, tags: [String]) {
        if !data.categories.contains(category) {
            data.categories.append(category)
        }
        for tag in tags where !data.tags.contains(tag) {
            data.tags.append(tag)
        }
    }

    private func focusStreak() -> Int {
        let calendar = Calendar.current
        let sessionDays = Set(
            endedSessions.map {
                calendar.startOfDay(for: $0.startedAt)
            }
        )
        var cursor = calendar.startOfDay(for: Date())
        var streak = 0
        while sessionDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        if streak == 0,
           let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date())),
           sessionDays.contains(yesterday) {
            cursor = yesterday
            while sessionDays.contains(cursor) {
                streak += 1
                guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = previous
            }
        }
        return streak
    }

    private static func hoursTemplate() -> [HourlyContribution] {
        (0..<24).map { HourlyContribution(hour: $0, seconds: 0) }
    }

    private static func trendTemplate(days: Int, referenceDate: Date) -> [DailyFocusPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)
        return (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -(days - 1 - offset), to: today) else {
                return nil
            }
            return DailyFocusPoint(date: date, seconds: 0, completionRate: 0)
        }
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case today
    case tasks
    case history
    case stats
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today:
            return "今日"
        case .tasks:
            return "任务"
        case .history:
            return "历史"
        case .stats:
            return "统计"
        case .settings:
            return "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .today:
            return "timer"
        case .tasks:
            return "checklist"
        case .history:
            return "clock.arrow.circlepath"
        case .stats:
            return "chart.xyaxis.line"
        case .settings:
            return "gearshape"
        }
    }
}

struct PomlistPersistence {
    var load: () -> PomlistData
    var save: (PomlistData) -> Void

    static let live = PomlistPersistence(
        load: {
            let url = PomlistPersistence.storeURL
            guard let payload = try? Data(contentsOf: url) else {
                return .seed()
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return (try? decoder.decode(PomlistData.self, from: payload)) ?? .seed()
        },
        save: { data in
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            guard let payload = try? encoder.encode(data) else { return }
            let directory = PomlistPersistence.storeDirectory
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            try? payload.write(to: PomlistPersistence.storeURL, options: [.atomic])
        }
    )

    static var storeDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pomlist", isDirectory: true)
    }

    static var storeURL: URL {
        storeDirectory.appendingPathComponent("pomlist-data.json")
    }
}
