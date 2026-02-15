import Foundation
import SwiftData

@MainActor
final class PLAnalyticsService: AnalyticsProviding {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func buildSnapshot(days: Int) throws -> PLAnalyticsSnapshot {
        let normalizedDays = max(1, days)
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)
        let startDate = calendar.date(byAdding: .day, value: -(normalizedDays - 1), to: startOfToday) ?? .distantPast

        let sessions = try fetchFinishedSessions(since: startDate)
        let completedTodos = try fetchCompletedTodoCount(since: startDate)

        var totalFocusSeconds = 0
        var completedTaskRefs = 0
        var categoryCounter: [String: Int] = [:]
        var hourlyCounter: [Int: Int] = [:]
        var dailyCounter: [String: Int] = [:]
        let dayKeyFormatter = PLFormatters.dayKeyFormatter

        for session in sessions {
            let elapsed = max(0, session.elapsedSeconds)
            totalFocusSeconds += elapsed
            completedTaskRefs += session.completedTaskCount

            let hour = calendar.component(.hour, from: session.startedAt)
            hourlyCounter[hour, default: 0] += 1

            if let endedAt = session.endedAt {
                let dayKey = dayKeyFormatter.string(from: endedAt)
                dailyCounter[dayKey, default: 0] += elapsed
            }

            for ref in session.taskRefs where ref.wasDoneAtEnd {
                let category = ref.categorySnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
                categoryCounter[category.isEmpty ? "未分类" : category, default: 0] += 1
            }
        }

        let avgFocus = sessions.isEmpty ? 0 : totalFocusSeconds / sessions.count
        let categoryBreakdown = categoryCounter
            .map { PLCategoryMetric(name: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count { return lhs.name < rhs.name }
                return lhs.count > rhs.count
            }
        let hourlyDistribution = (0 ... 23).map { hour in
            PLHourlyMetric(hour: hour, count: hourlyCounter[hour, default: 0])
        }

        var dailyTrend: [PLDailyMetric] = []
        for offset in stride(from: normalizedDays - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: startOfToday) else { continue }
            let key = dayKeyFormatter.string(from: day)
            let label = PLFormatters.shortDay.string(from: day)
            dailyTrend.append(
                PLDailyMetric(
                    dateKey: key,
                    label: label,
                    focusSeconds: dailyCounter[key, default: 0]
                )
            )
        }

        return PLAnalyticsSnapshot(
            days: normalizedDays,
            totalSessions: sessions.count,
            totalFocusSeconds: totalFocusSeconds,
            completedTodos: completedTodos,
            completedTaskRefs: completedTaskRefs,
            averageFocusSeconds: avgFocus,
            categoryBreakdown: categoryBreakdown,
            hourlyDistribution: hourlyDistribution,
            dailyTrend: dailyTrend
        )
    }

    private func fetchFinishedSessions(since date: Date) throws -> [PLFocusSession] {
        let descriptor = FetchDescriptor<PLFocusSession>(
            predicate: #Predicate<PLFocusSession> {
                $0.endedAt != nil && $0.isCancelled == false && $0.startedAt >= date
            },
            sortBy: [SortDescriptor(\PLFocusSession.startedAt)]
        )
        return try context.fetch(descriptor)
    }

    private func fetchCompletedTodoCount(since date: Date) throws -> Int {
        let descriptor = FetchDescriptor<PLTodo>(
            predicate: #Predicate<PLTodo> {
                $0.isDone == true && $0.updatedAt >= date
            }
        )
        return try context.fetchCount(descriptor)
    }
}
