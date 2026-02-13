import Foundation
import SwiftData

struct AnalyticsDashboardMetrics {
    let todaySessionCount: Int
    let todayFocusSeconds: Int
    let todayCompletionRate: Double
    let currentStreakDays: Int
}

struct DailyTrendPoint: Identifiable {
    let date: Date
    let sessionCount: Int
    let completionRate: Double
    let totalSeconds: Int

    var id: Date { date }
}

struct DurationBucket: Identifiable {
    let label: String
    let count: Int

    var id: String { label }
}

enum AnalyticsService {
    static func dashboardMetrics(context: ModelContext, now: Date = .now, calendar: Calendar = .current) throws -> AnalyticsDashboardMetrics {
        let sessions = try endedSessions(context: context)
        let startOfDay = calendar.startOfDay(for: now)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return AnalyticsDashboardMetrics(todaySessionCount: 0, todayFocusSeconds: 0, todayCompletionRate: 0, currentStreakDays: 0)
        }

        let todaySessions = sessions.filter { session in
            guard let endedAt = session.endedAt else { return false }
            return endedAt >= startOfDay && endedAt < nextDay
        }

        let todayFocusSeconds = todaySessions.reduce(0) { $0 + $1.elapsedSeconds }
        let totalTasks = todaySessions.reduce(0) { $0 + $1.totalTaskCount }
        let completedTasks = todaySessions.reduce(0) { $0 + $1.completedTaskCount }
        let completionRate = totalTasks > 0 ? Double(completedTasks) / Double(totalTasks) : 0
        let streak = streakDays(from: sessions, now: now, calendar: calendar)

        return AnalyticsDashboardMetrics(
            todaySessionCount: todaySessions.count,
            todayFocusSeconds: todayFocusSeconds,
            todayCompletionRate: completionRate,
            currentStreakDays: streak
        )
    }

    static func dailyTrend(days: Int, context: ModelContext, now: Date = .now, calendar: Calendar = .current) throws -> [DailyTrendPoint] {
        guard days > 0 else { return [] }
        let sessions = try endedSessions(context: context)
        let startOfToday = calendar.startOfDay(for: now)

        return (0..<days).compactMap { offset -> DailyTrendPoint? in
            guard let date = calendar.date(byAdding: .day, value: -(days - 1 - offset), to: startOfToday),
                  let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else {
                return nil
            }

            let daySessions = sessions.filter { session in
                guard let endedAt = session.endedAt else { return false }
                return endedAt >= date && endedAt < nextDate
            }

            let totalTasks = daySessions.reduce(0) { $0 + $1.totalTaskCount }
            let completedTasks = daySessions.reduce(0) { $0 + $1.completedTaskCount }
            let completionRate = totalTasks > 0 ? Double(completedTasks) / Double(totalTasks) : 0
            let focusSeconds = daySessions.reduce(0) { $0 + $1.elapsedSeconds }

            return DailyTrendPoint(
                date: date,
                sessionCount: daySessions.count,
                completionRate: completionRate,
                totalSeconds: focusSeconds
            )
        }
    }

    static func durationDistribution(days: Int, context: ModelContext, now: Date = .now, calendar: Calendar = .current) throws -> [DurationBucket] {
        let sessions = try endedSessions(context: context)
        let validSessions: [FocusSession]

        if days > 0,
           let startDate = calendar.date(byAdding: .day, value: -days + 1, to: calendar.startOfDay(for: now)),
           let endDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
            validSessions = sessions.filter { session in
                guard let endedAt = session.endedAt else { return false }
                return endedAt >= startDate && endedAt < endDate
            }
        } else {
            validSessions = sessions
        }

        var buckets: [String: Int] = [
            "0-15 分钟": 0,
            "15-30 分钟": 0,
            "30-45 分钟": 0,
            "45+ 分钟": 0
        ]

        for session in validSessions {
            let minutes = session.elapsedSeconds / 60
            switch minutes {
            case ..<15:
                buckets["0-15 分钟", default: 0] += 1
            case 15..<30:
                buckets["15-30 分钟", default: 0] += 1
            case 30..<45:
                buckets["30-45 分钟", default: 0] += 1
            default:
                buckets["45+ 分钟", default: 0] += 1
            }
        }

        return [
            DurationBucket(label: "0-15 分钟", count: buckets["0-15 分钟", default: 0]),
            DurationBucket(label: "15-30 分钟", count: buckets["15-30 分钟", default: 0]),
            DurationBucket(label: "30-45 分钟", count: buckets["30-45 分钟", default: 0]),
            DurationBucket(label: "45+ 分钟", count: buckets["45+ 分钟", default: 0])
        ]
    }

    static func streakDays(context: ModelContext, now: Date = .now, calendar: Calendar = .current) throws -> Int {
        let sessions = try endedSessions(context: context)
        return streakDays(from: sessions, now: now, calendar: calendar)
    }

    private static func endedSessions(context: ModelContext) throws -> [FocusSession] {
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate<FocusSession> { session in
                session.stateValue == "ended"
            },
            sortBy: [SortDescriptor(\FocusSession.endedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    private static func streakDays(from sessions: [FocusSession], now: Date, calendar: Calendar) -> Int {
        let daySet: Set<Date> = Set(
            sessions.compactMap { $0.endedAt }.map { calendar.startOfDay(for: $0) }
        )

        var streak = 0
        var cursor = calendar.startOfDay(for: now)
        while daySet.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previous
        }
        return streak
    }
}

