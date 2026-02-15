import Foundation

enum PLServiceError: LocalizedError {
    case activeSessionExists
    case noActiveSession
    case emptySessionTasks
    case invalidPasscode
    case passcodeMismatch
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .activeSessionExists:
            return "当前已有进行中的专注会话。"
        case .noActiveSession:
            return "当前没有进行中的专注会话。"
        case .emptySessionTasks:
            return "至少选择一个任务后再开始专注。"
        case .invalidPasscode:
            return "口令错误，请重试。"
        case .passcodeMismatch:
            return "旧口令不正确。"
        case .decodeFailed:
            return "迁移文件解析失败。"
        }
    }
}
