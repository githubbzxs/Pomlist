import Foundation

enum PLServiceError: LocalizedError {
    case emptyTitle
    case invalidPlannedMinutes
    case activeSessionExists
    case noActiveSession
    case invalidPasscodeFormat
    case passcodeMismatch
    case passcodeUnchanged
    case missingAuthConfig

    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            "任务标题不能为空。"
        case .invalidPlannedMinutes:
            "计划时长必须大于 0。"
        case .activeSessionExists:
            "当前已有进行中的专注会话。"
        case .noActiveSession:
            "没有可操作的进行中会话。"
        case .invalidPasscodeFormat:
            "口令必须是 4 个字符。"
        case .passcodeMismatch:
            "旧口令不正确。"
        case .passcodeUnchanged:
            "新口令不能与旧口令一致。"
        case .missingAuthConfig:
            "未找到鉴权配置。"
        }
    }
}
