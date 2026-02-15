import Foundation

enum PLFormatters {
    static let dateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter
    }()

    static let shortDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM/dd"
        return formatter
    }()

    static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func durationText(seconds: Int) -> String {
        let clamped = max(0, seconds)
        let minutes = clamped / 60
        let remain = clamped % 60
        return String(format: "%02d:%02d", minutes, remain)
    }

    static func minuteText(seconds: Int) -> String {
        let minutes = max(1, Int(round(Double(max(0, seconds)) / 60.0)))
        return "\(minutes) 分钟"
    }
}
