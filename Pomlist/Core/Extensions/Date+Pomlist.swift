import Foundation

extension Date {
    func pomlistTimeText() -> String {
        formatted(.dateTime.hour().minute())
    }

    func pomlistMonthDayText() -> String {
        formatted(.dateTime.month(.abbreviated).day())
    }

    func pomlistFullStampText() -> String {
        formatted(.dateTime.month().day().hour().minute())
    }

    var pomlistDayKey: String {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day], from: self)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}

extension Int {
    func pomlistDurationText() -> String {
        let safeValue = Swift.max(self, 0)
        let minutes = safeValue / 60

        if minutes < 60 {
            return "\(minutes) 分钟"
        }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return "\(hours) 小时 \(remainingMinutes) 分钟"
    }

    func pomlistClockText() -> String {
        let safeValue = Swift.max(self, 0)
        let minutes = safeValue / 60
        let seconds = safeValue % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
