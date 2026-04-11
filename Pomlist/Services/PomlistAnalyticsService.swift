import Foundation

enum PomlistAnalyticsService {
    static func buildDashboard(from sessions: [FocusSession]) -> DashboardMetrics {
        let endedSessions = sessions
            .filter { $0.state == .ended }
            .sorted { ($0.endedAt ?? $0.startedAt) > ($1.endedAt ?? $1.startedAt) }

        guard !endedSessions.isEmpty else {
            return .empty
        }

        let now = Date()
        let todayRange = range(days: 1, from: now)
        let last7Range = range(days: 7, from: now)
        let last30Range = range(days: 30, from: now)
        let previous7Range = previousRange(days: 7, from: now)

        let todaySessions = filterSessions(endedSessions, in: todayRange)
        let last7Sessions = filterSessions(endedSessions, in: last7Range)
        let last30Sessions = filterSessions(endedSessions, in: last30Range)
        let previous7Sessions = filterSessions(endedSessions, in: previous7Range)

        return DashboardMetrics(
            today: summarize(todaySessions),
            last7Days: summarize(last7Sessions),
            last30Days: summarize(last30Sessions),
            streakDays: computeStreak(from: endedSessions, relativeTo: now),
            categoryStats: buildCategoryMetrics(from: last30Sessions),
            hourlyDistribution: buildHourlyMetrics(from: last30Sessions),
            efficiency: buildEfficiency(recent: last7Sessions, previous: previous7Sessions)
        )
    }

    private static func filterSessions(_ sessions: [FocusSession], in range: ClosedRange<Date>) -> [FocusSession] {
        sessions.filter {
            let anchor = $0.endedAt ?? $0.startedAt
            return range.contains(anchor)
        }
    }

    private static func summarize(_ sessions: [FocusSession]) -> PeriodMetrics {
        let totalDuration = sessions.reduce(0) { $0 + $1.elapsedSeconds }
        let completedTasks = sessions.reduce(0) { $0 + $1.completedTaskCount }
        let totalTasks = sessions.reduce(0) { $0 + $1.totalTaskCount }

        return PeriodMetrics(
            sessionCount: sessions.count,
            totalDurationSeconds: totalDuration,
            completedTaskCount: completedTasks,
            completionRate: completionRate(completed: completedTasks, total: totalTasks)
        )
    }

    private static func buildCategoryMetrics(from sessions: [FocusSession]) -> [CategoryMetrics] {
        var stats: [String: (taskCount: Int, completedCount: Int, totalDurationSeconds: Int)] = [:]

        for session in sessions {
            let divisor = max(session.tasks.count, 1)
            let sharedDuration = session.elapsedSeconds / divisor

            for task in session.tasks {
                let key = task.tagSnapshot.first ?? task.categorySnapshot
                var value = stats[key, default: (0, 0, 0)]
                value.taskCount += 1
                value.totalDurationSeconds += sharedDuration
                if task.isCompletedInSession {
                    value.completedCount += 1
                }
                stats[key] = value
            }
        }

        return stats
            .map { key, value in
                CategoryMetrics(
                    category: key,
                    taskCount: value.taskCount,
                    completedCount: value.completedCount,
                    completionRate: completionRate(completed: value.completedCount, total: value.taskCount),
                    totalDurationSeconds: value.totalDurationSeconds
                )
            }
            .sorted { $0.totalDurationSeconds > $1.totalDurationSeconds }
    }

    private static func buildHourlyMetrics(from sessions: [FocusSession]) -> [HourlyMetrics] {
        let calendar = Calendar(identifier: .gregorian)
        var metrics = Array(0..<24).map {
            HourlyMetrics(hour: $0, sessionCount: 0, totalDurationSeconds: 0, completedTaskCount: 0)
        }

        for session in sessions {
            let hour = calendar.component(.hour, from: session.endedAt ?? session.startedAt)
            guard metrics.indices.contains(hour) else { continue }
            metrics[hour].sessionCount += 1
            metrics[hour].totalDurationSeconds += session.elapsedSeconds
            metrics[hour].completedTaskCount += session.completedTaskCount
        }

        return metrics
    }

    private static func buildEfficiency(recent: [FocusSession], previous: [FocusSession]) -> EfficiencyMetrics {
        let recentSummary = summarize(recent)
        let previousSummary = summarize(previous)

        let tasksPerHour: Double
        if recentSummary.totalDurationSeconds > 0 {
            tasksPerHour = round((Double(recentSummary.completedTaskCount) / Double(recentSummary.totalDurationSeconds)) * 3600 * 100) / 100
        } else {
            tasksPerHour = 0
        }

        let averageDuration = recentSummary.sessionCount > 0 ? recentSummary.totalDurationSeconds / recentSummary.sessionCount : 0

        return EfficiencyMetrics(
            tasksPerHour: tasksPerHour,
            averageCompletionRate: recentSummary.completionRate,
            averageSessionDurationSeconds: averageDuration,
            sessionDelta: recentSummary.sessionCount - previousSummary.sessionCount,
            durationDeltaSeconds: recentSummary.totalDurationSeconds - previousSummary.totalDurationSeconds,
            completionRateDelta: recentSummary.completionRate - previousSummary.completionRate
        )
    }

    private static func computeStreak(from sessions: [FocusSession], relativeTo currentDate: Date) -> Int {
        let calendar = Calendar(identifier: .gregorian)
        let daySet = Set(sessions.map { ($0.endedAt ?? $0.startedAt).pomlistDayKey })
        var cursor = calendar.startOfDay(for: currentDate)
        var streak = 0

        while daySet.contains(cursor.pomlistDayKey) {
            streak += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }

        return streak
    }

    private static func completionRate(completed: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    private static func range(days: Int, from currentDate: Date) -> ClosedRange<Date> {
        let calendar = Calendar(identifier: .gregorian)
        let end = currentDate
        let startOfToday = calendar.startOfDay(for: currentDate)
        let start = calendar.date(byAdding: .day, value: -(max(days, 1) - 1), to: startOfToday) ?? startOfToday
        return start...end
    }

    private static func previousRange(days: Int, from currentDate: Date) -> ClosedRange<Date> {
        let calendar = Calendar(identifier: .gregorian)
        let endOfPrevious = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: currentDate)) ?? currentDate
        let start = calendar.date(byAdding: .day, value: -max(days, 1), to: endOfPrevious) ?? endOfPrevious
        return start...endOfPrevious
    }
}
