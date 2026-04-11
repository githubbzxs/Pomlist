import Foundation

enum TodoStatus: String, Codable, CaseIterable, Identifiable {
    case pending
    case completed
    case archived

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pending:
            return "待办"
        case .completed:
            return "已完成"
        case .archived:
            return "已归档"
        }
    }
}

enum FocusSessionState: String, Codable {
    case active
    case ended
}

struct TodoItem: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var notes: String
    var category: String
    var tags: [String]
    var status: TodoStatus
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?

    init(
        id: String = UUID().uuidString,
        title: String,
        notes: String = "",
        category: String = "未分类",
        tags: [String] = [],
        status: TodoStatus = .pending,
        createdAt: Date = .now,
        updatedAt: Date = .now,
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

    var isCompleted: Bool {
        status == .completed
    }
}

struct SessionTaskSnapshot: Identifiable, Codable, Equatable {
    var id: String
    var todoID: String
    var titleSnapshot: String
    var categorySnapshot: String
    var tagSnapshot: [String]
    var orderIndex: Int
    var isCompletedInSession: Bool
    var completedAt: Date?

    init(
        id: String = UUID().uuidString,
        todoID: String,
        titleSnapshot: String,
        categorySnapshot: String,
        tagSnapshot: [String],
        orderIndex: Int,
        isCompletedInSession: Bool = false,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.todoID = todoID
        self.titleSnapshot = titleSnapshot
        self.categorySnapshot = categorySnapshot
        self.tagSnapshot = tagSnapshot
        self.orderIndex = orderIndex
        self.isCompletedInSession = isCompletedInSession
        self.completedAt = completedAt
    }
}

struct FocusSession: Identifiable, Codable, Equatable {
    var id: String
    var state: FocusSessionState
    var startedAt: Date
    var endedAt: Date?
    var elapsedSeconds: Int
    var totalTaskCount: Int
    var completedTaskCount: Int
    var completionRate: Double
    var tasks: [SessionTaskSnapshot]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        state: FocusSessionState,
        startedAt: Date = .now,
        endedAt: Date? = nil,
        elapsedSeconds: Int = 0,
        totalTaskCount: Int,
        completedTaskCount: Int = 0,
        completionRate: Double = 0,
        tasks: [SessionTaskSnapshot],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.state = state
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.elapsedSeconds = elapsedSeconds
        self.totalTaskCount = totalTaskCount
        self.completedTaskCount = completedTaskCount
        self.completionRate = completionRate
        self.tasks = tasks
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func elapsedSeconds(at currentDate: Date = .now) -> Int {
        if state == .active {
            return max(Int(currentDate.timeIntervalSince(startedAt)), elapsedSeconds)
        }
        return elapsedSeconds
    }
}

struct AppAuthState: Codable, Equatable {
    var passcode: String
    var isAuthenticated: Bool
    var updatedAt: Date

    init(passcode: String = "0xbp", isAuthenticated: Bool = false, updatedAt: Date = .now) {
        self.passcode = passcode
        self.isAuthenticated = isAuthenticated
        self.updatedAt = updatedAt
    }
}

struct AppDatabase: Codable, Equatable {
    var version: Int
    var auth: AppAuthState
    var todos: [TodoItem]
    var sessions: [FocusSession]
    var categoryRegistry: [String]
    var tagRegistry: [String]

    init(
        version: Int = 2,
        auth: AppAuthState = AppAuthState(),
        todos: [TodoItem] = [],
        sessions: [FocusSession] = [],
        categoryRegistry: [String] = [],
        tagRegistry: [String] = []
    ) {
        self.version = version
        self.auth = auth
        self.todos = todos
        self.sessions = sessions
        self.categoryRegistry = categoryRegistry
        self.tagRegistry = tagRegistry
    }

    enum CodingKeys: String, CodingKey {
        case version
        case auth
        case todos
        case sessions
        case categoryRegistry
        case tagRegistry
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 2
        auth = try container.decodeIfPresent(AppAuthState.self, forKey: .auth) ?? AppAuthState()
        todos = try container.decodeIfPresent([TodoItem].self, forKey: .todos) ?? []
        sessions = try container.decodeIfPresent([FocusSession].self, forKey: .sessions) ?? []
        categoryRegistry = try container.decodeIfPresent([String].self, forKey: .categoryRegistry) ?? []
        tagRegistry = try container.decodeIfPresent([String].self, forKey: .tagRegistry) ?? []
    }
}

struct TaskDraft: Equatable {
    var title: String = ""
    var category: String = "未分类"
    var tagsText: String = ""
    var notes: String = ""

    var tags: [String] {
        tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

struct PeriodMetrics: Equatable {
    var sessionCount: Int
    var totalDurationSeconds: Int
    var completedTaskCount: Int
    var completionRate: Double

    static let empty = PeriodMetrics(sessionCount: 0, totalDurationSeconds: 0, completedTaskCount: 0, completionRate: 0)
}

struct CategoryMetrics: Identifiable, Equatable {
    var id: String { category }
    var category: String
    var taskCount: Int
    var completedCount: Int
    var completionRate: Double
    var totalDurationSeconds: Int
}

struct HourlyMetrics: Identifiable, Equatable {
    var id: Int { hour }
    var hour: Int
    var sessionCount: Int
    var totalDurationSeconds: Int
    var completedTaskCount: Int
}

struct EfficiencyMetrics: Equatable {
    var tasksPerHour: Double
    var averageCompletionRate: Double
    var averageSessionDurationSeconds: Int
    var sessionDelta: Int
    var durationDeltaSeconds: Int
    var completionRateDelta: Double

    static let empty = EfficiencyMetrics(
        tasksPerHour: 0,
        averageCompletionRate: 0,
        averageSessionDurationSeconds: 0,
        sessionDelta: 0,
        durationDeltaSeconds: 0,
        completionRateDelta: 0
    )
}

struct DashboardMetrics: Equatable {
    var today: PeriodMetrics
    var last7Days: PeriodMetrics
    var last30Days: PeriodMetrics
    var streakDays: Int
    var categoryStats: [CategoryMetrics]
    var hourlyDistribution: [HourlyMetrics]
    var efficiency: EfficiencyMetrics

    static let empty = DashboardMetrics(
        today: .empty,
        last7Days: .empty,
        last30Days: .empty,
        streakDays: 0,
        categoryStats: [],
        hourlyDistribution: [],
        efficiency: .empty
    )
}
