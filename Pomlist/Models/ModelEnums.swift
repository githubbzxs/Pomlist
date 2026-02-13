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

enum SessionState: String, Codable, CaseIterable {
    case active
    case ended
}

enum TodoPriority: Int, Codable, CaseIterable, Identifiable {
    case low = 1
    case medium = 2
    case high = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .low:
            return "低"
        case .medium:
            return "中"
        case .high:
            return "高"
        }
    }
}

