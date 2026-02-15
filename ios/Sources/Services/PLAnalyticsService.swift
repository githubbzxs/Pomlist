import Foundation
import SwiftData

@MainActor
final class PLAnalyticsService: AnalyticsProviding {
    private let context: ModelContext
    private let calendar = Calendar.current

    init(context: ModelContext) {
        self.context = context
    }

    func snapshot() throws -> PLAnalyticsSnapshot {
        let sessions = try context.fetch(FetchDescriptor<PLFocusSession>(
            predicate: #Predicate { $0.state == "ended" },
            sortBy: [SortDescriptor(\.endedAt, order: .reverse)]
        ))

        let todos = try context.fetch(FetchDescriptor<PLTodo>())
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOf7 = calendar.date(byAdding: .day, value: -6, to: startOfToday) ?? startOfToday
        let startOf30 = calendar.date(byAdding: .day, value: -29, to: startOfToday) ?? startOfToday

        let todaySessions = sessions.filter {
            guard let ended = $0.endedAt else { return false }
            return ended >= startOfToday
        }

        let sessions7 = sessions.filter {
            guard let ended = $0.endedAt else { return false }
            return ended >= startOf7
        }

        let sessions30 = sessions.filter {
            guard let ended = $0.endedAt else { return false }
            return ended >= startOf30
        }

        let todayDuration = todaySessions.reduce(0) { $0 + $1.elapsedSeconds }
        let avgRate = sessions30.isEmpty ? 0 : sessions30.reduce(0) { $0 + $1.completionRate } / Double(sessions30.count)

        let categoryPoints = buildCategoryPoints(from: todos)
        let hourlyPoints = buildHourlyPoints(from: sessions30)

        return PLAnalyticsSnapshot(
            todaySessions: todaySessions.count,
            todayDurationSeconds: todayDuration,
            streakDays: streakDays(from: sessions),
            sessionsLast7Days: sessions7.count,
            sessionsLast30Days: sessions30.count,
            avgCompletionRate: avgRate,
            categoryDistribution: categoryPoints,
            hourlyDistribution: hourlyPoints
        )
    }

    private func buildCategoryPoints(from todos: [PLTodo]) -> [PLCategoryPoint] {
        let grouped = Dictionary(grouping: todos) { todo in
            let value = todo.category.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? "未分类" : value
        }

        return grouped
            .map { PLCategoryPoint(category: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    private func buildHourlyPoints(from sessions: [PLFocusSession]) -> [PLHourlyPoint] {
        var buckets = Array(repeating: 0, count: 24)
        for session in sessions {
            guard let ended = session.endedAt else { continue }
            let hour = calendar.component(.hour, from: ended)
            if hour >= 0 && hour < 24 {
                buckets[hour] += 1
            }
        }

        return buckets.enumerated().map { index, count in
            PLHourlyPoint(hour: index, count: count)
        }
    }

    private func streakDays(from sessions: [PLFocusSession]) -> Int {
        let days = Set(sessions.compactMap { session -> Date? in
            guard let ended = session.endedAt else { return nil }
            return calendar.startOfDay(for: ended)
        })

        guard !days.isEmpty else { return 0 }

        var streak = 0
        var cursor = calendar.startOfDay(for: Date())

        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previous
        }

        return streak
    }
}
