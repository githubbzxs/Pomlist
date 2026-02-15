import Foundation

struct PLCategoryPoint: Identifiable {
    let id: String
    let category: String
    let count: Int

    init(category: String, count: Int) {
        self.id = category
        self.category = category
        self.count = count
    }
}

struct PLHourlyPoint: Identifiable {
    let id: Int
    let hour: Int
    let count: Int

    init(hour: Int, count: Int) {
        self.id = hour
        self.hour = hour
        self.count = count
    }
}

struct PLAnalyticsSnapshot {
    let todaySessions: Int
    let todayDurationSeconds: Int
    let streakDays: Int
    let sessionsLast7Days: Int
    let sessionsLast30Days: Int
    let avgCompletionRate: Double
    let categoryDistribution: [PLCategoryPoint]
    let hourlyDistribution: [PLHourlyPoint]
}
