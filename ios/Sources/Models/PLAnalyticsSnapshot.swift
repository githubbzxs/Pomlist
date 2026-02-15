import Foundation

struct PLAnalyticsSnapshot {
    let days: Int
    let totalSessions: Int
    let totalFocusSeconds: Int
    let completedTodos: Int
    let completedTaskRefs: Int
    let averageFocusSeconds: Int
    let categoryBreakdown: [PLCategoryMetric]
    let hourlyDistribution: [PLHourlyMetric]
    let dailyTrend: [PLDailyMetric]

    static func empty(days: Int) -> PLAnalyticsSnapshot {
        PLAnalyticsSnapshot(
            days: days,
            totalSessions: 0,
            totalFocusSeconds: 0,
            completedTodos: 0,
            completedTaskRefs: 0,
            averageFocusSeconds: 0,
            categoryBreakdown: [],
            hourlyDistribution: (0 ... 23).map { PLHourlyMetric(hour: $0, count: 0) },
            dailyTrend: []
        )
    }
}

struct PLCategoryMetric: Identifiable {
    let name: String
    let count: Int

    var id: String { name }
}

struct PLHourlyMetric: Identifiable {
    let hour: Int
    let count: Int

    var id: Int { hour }
}

struct PLDailyMetric: Identifiable {
    let dateKey: String
    let label: String
    let focusSeconds: Int

    var id: String { dateKey }
}
