import CryptoKit
import Foundation

enum TaskStatus: String, CaseIterable, Codable, Identifiable {
    case todo
    case completed
    case archived

    var id: String { rawValue }
}

enum FocusSessionState: String, Codable {
    case active
    case ended
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

    var totalTaskCount: Int { tasks.count }
    var completedTaskCount: Int { tasks.filter(\.isCompletedInSession).count }
    var completionRate: Double {
        guard totalTaskCount > 0 else { return 0 }
        return Double(completedTaskCount) / Double(totalTaskCount)
    }
}

struct PomlistData: Codable {
    var passcodeHash: String
    var tasks: [PomTask]
    var sessions: [FocusSession]
    var categories: [String]
    var tags: [String]
}

enum PomlistHasher {
    static func hash(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

func assert(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("失败：\(message)\n", stderr)
        exit(1)
    }
}

let task = PomTask(title: "原始任务", category: "开发", tags: ["Swift"])
var snapshot = SessionTaskSnapshot(task: task, orderIndex: 0)
snapshot.isCompletedInSession = true
snapshot.completedAt = Date()
let session = FocusSession(state: .ended, elapsedSeconds: 1500, tasks: [snapshot])
let data = PomlistData(
    passcodeHash: PomlistHasher.hash("0000"),
    tasks: [PomTask(id: task.id, title: "已编辑任务", category: "开发", tags: ["Swift"])],
    sessions: [session],
    categories: ["默认", "开发"],
    tags: ["Swift"]
)

assert(data.passcodeHash == PomlistHasher.hash("0000"), "口令 hash 应稳定")
assert(data.sessions.first?.tasks.first?.titleSnapshot == "原始任务", "会话应保留任务快照")
assert(data.sessions.first?.completionRate == 1, "完成率应来自快照状态")

let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .iso8601
let payload = try encoder.encode(data)
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601
let decoded = try decoder.decode(PomlistData.self, from: payload)

assert(decoded.sessions.count == 1, "会话应可编码解码")
assert(decoded.tasks.first?.title == "已编辑任务", "任务库应独立保存当前任务")
assert(decoded.sessions.first?.tasks.first?.titleSnapshot == "原始任务", "历史快照不应受当前任务影响")

print("Pomlist 逻辑测试通过")
