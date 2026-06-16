import Foundation

enum TaskStatus: String, CaseIterable, Codable, Identifiable {
    case todo
    case completed
    case archived

    var id: String { rawValue }

    var title: String {
        switch self {
        case .todo:
            return "待办"
        case .completed:
            return "完成"
        case .archived:
            return "归档"
        }
    }

    var systemImage: String {
        switch self {
        case .todo:
            return "circle"
        case .completed:
            return "checkmark.circle.fill"
        case .archived:
            return "archivebox.fill"
        }
    }
}

enum FocusSessionState: String, Codable {
    case active
    case ended
}

enum StatsRange: String, CaseIterable, Identifiable {
    case today
    case sevenDays
    case thirtyDays

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today:
            return "今日"
        case .sevenDays:
            return "近 7 天"
        case .thirtyDays:
            return "近 30 天"
        }
    }

    var days: Int {
        switch self {
        case .today:
            return 1
        case .sevenDays:
            return 7
        case .thirtyDays:
            return 30
        }
    }
}

struct PomTask: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var notes: String
    var category: String
    var tags: [String]
    var status: TaskStatus
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        category: String = "默认",
        tags: [String] = [],
        status: TaskStatus = .todo,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.category = category
        self.tags = tags
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }
}

struct SessionTaskSnapshot: Identifiable, Codable, Equatable {
    var id: UUID
    var taskId: UUID
    var titleSnapshot: String
    var categorySnapshot: String
    var tagSnapshot: [String]
    var orderIndex: Int
    var isCompletedInSession: Bool
    var completedAt: Date?

    init(task: PomTask, orderIndex: Int) {
        self.id = UUID()
        self.taskId = task.id
        self.titleSnapshot = task.title
        self.categorySnapshot = task.category
        self.tagSnapshot = task.tags
        self.orderIndex = orderIndex
        self.isCompletedInSession = task.status == .completed
        self.completedAt = task.status == .completed ? task.completedAt ?? Date() : nil
    }
}

struct FocusSession: Identifiable, Codable, Equatable {
    var id: UUID
    var state: FocusSessionState
    var startedAt: Date
    var endedAt: Date?
    var elapsedSeconds: Int
    var tasks: [SessionTaskSnapshot]

    init(
        id: UUID = UUID(),
        state: FocusSessionState = .active,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        elapsedSeconds: Int = 0,
        tasks: [SessionTaskSnapshot] = []
    ) {
        self.id = id
        self.state = state
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.elapsedSeconds = elapsedSeconds
        self.tasks = tasks
    }

    var totalTaskCount: Int {
        tasks.count
    }

    var completedTaskCount: Int {
        tasks.filter(\.isCompletedInSession).count
    }

    var completionRate: Double {
        guard totalTaskCount > 0 else { return 0 }
        return Double(completedTaskCount) / Double(totalTaskCount)
    }

    func elapsedSecondsNow(referenceDate: Date = Date()) -> Int {
        if state == .ended {
            return elapsedSeconds
        }
        return max(0, Int(referenceDate.timeIntervalSince(startedAt)))
    }
}

struct PomlistData: Codable {
    var tasks: [PomTask]
    var sessions: [FocusSession]
    var categories: [String]
    var tags: [String]

    static func seed() -> PomlistData {
        let now = Date()
        let calendar = Calendar.current
        let tasks = [
            PomTask(
                title: "整理今日关键任务",
                notes: "选择 2-3 个本轮真正要推进的任务。",
                category: "计划",
                tags: ["启动", "今日"],
                createdAt: now
            ),
            PomTask(
                title: "完成 Pomlist 首轮原型验证",
                notes: "检查专注会话、任务快照、历史与统计是否形成闭环。",
                category: "开发",
                tags: ["SwiftUI", "验证"],
                createdAt: calendar.date(byAdding: .hour, value: -3, to: now) ?? now
            ),
            PomTask(
                title: "复盘昨天的工作节奏",
                notes: "记录中断来源与下一轮改进点。",
                category: "复盘",
                tags: ["节奏"],
                createdAt: calendar.date(byAdding: .day, value: -1, to: now) ?? now
            )
        ]

        return PomlistData(
            tasks: tasks,
            sessions: PomlistData.sampleSessions(referenceDate: now),
            categories: ["默认", "计划", "开发", "学习", "复盘"],
            tags: ["启动", "今日", "SwiftUI", "验证", "节奏"]
        )
    }

    private static func sampleSessions(referenceDate: Date) -> [FocusSession] {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: referenceDate) ?? referenceDate
        let start = calendar.date(bySettingHour: 10, minute: 15, second: 0, of: yesterday) ?? yesterday
        let end = calendar.date(byAdding: .minute, value: 42, to: start) ?? yesterday
        let task = PomTask(
            id: UUID(),
            title: "梳理任务驱动番茄钟结构",
            category: "计划",
            tags: ["复盘"],
            status: .completed,
            createdAt: start,
            updatedAt: end,
            completedAt: end
        )
        var snapshot = SessionTaskSnapshot(task: task, orderIndex: 0)
        snapshot.isCompletedInSession = true
        snapshot.completedAt = end
        return [
            FocusSession(
                state: .ended,
                startedAt: start,
                endedAt: end,
                elapsedSeconds: 42 * 60,
                tasks: [snapshot]
            )
        ]
    }
}

struct PomlistStats: Equatable {
    var sessionCount: Int
    var totalSeconds: Int
    var completedTaskCount: Int
    var averageCompletionRate: Double
    var focusStreak: Int
    var categoryContributions: [CategoryContribution]
    var hourlyDistribution: [HourlyContribution]
    var trend: [DailyFocusPoint]

    static let empty = PomlistStats(
        sessionCount: 0,
        totalSeconds: 0,
        completedTaskCount: 0,
        averageCompletionRate: 0,
        focusStreak: 0,
        categoryContributions: [],
        hourlyDistribution: [],
        trend: []
    )
}

struct CategoryContribution: Identifiable, Equatable {
    var id: String { category }
    var category: String
    var seconds: Int
    var completedTasks: Int
}

struct HourlyContribution: Identifiable, Equatable {
    var id: Int { hour }
    var hour: Int
    var seconds: Int
}

struct DailyFocusPoint: Identifiable, Equatable {
    var id: Date { date }
    var date: Date
    var seconds: Int
    var completionRate: Double
}
