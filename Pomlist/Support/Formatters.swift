import Foundation

enum TimeTextFormatter {
    static func mmss(_ totalSeconds: Int) -> String {
        let clamped = max(0, totalSeconds)
        let minutes = clamped / 60
        let seconds = clamped % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    static func hourMinute(_ totalSeconds: Int) -> String {
        let clamped = max(0, totalSeconds)
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60
        if hours == 0 {
            return "\(minutes) 分钟"
        }
        return "\(hours) 小时 \(minutes) 分钟"
    }
}

enum DateTextFormatter {
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    private static let dayTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter
    }()

    static func day(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    static func dayTime(_ date: Date) -> String {
        dayTimeFormatter.string(from: date)
    }
}

