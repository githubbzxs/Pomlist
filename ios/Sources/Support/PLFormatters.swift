import Foundation

enum PLFormatters {
    static func durationText(seconds: Int) -> String {
        let safe = max(0, seconds)
        let hour = safe / 3600
        let minute = (safe % 3600) / 60
        let second = safe % 60
        if hour > 0 {
            return String(format: "%02d:%02d:%02d", hour, minute, second)
        }
        return String(format: "%02d:%02d", minute, second)
    }

    static func minuteText(seconds: Int) -> String {
        let minute = max(0, Int(round(Double(seconds) / 60)))
        return "\(minute) 分钟"
    }

    static func rateText(_ rate: Double) -> String {
        let percent = Int((max(0, min(1, rate)) * 100).rounded())
        return "\(percent)%"
    }

    static func shortDateTime(_ date: Date?) -> String {
        guard let date else { return "-" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans")
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }
}
