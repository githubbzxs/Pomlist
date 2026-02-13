import SwiftData
import XCTest
@testable import Pomlist

final class AnalyticsServiceTests: XCTestCase {
    func testStreakAndDailyTrend() throws {
        let container = try TestContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_700_300_000)

        try insertEndedSession(
            context: context,
            startedAt: now.addingTimeInterval(-3600),
            endedAt: now.addingTimeInterval(-1800),
            total: 10,
            completed: 8,
            elapsed: 1800
        )

        try insertEndedSession(
            context: context,
            startedAt: now.addingTimeInterval(-86_400 - 3600),
            endedAt: now.addingTimeInterval(-86_400 - 1200),
            total: 5,
            completed: 5,
            elapsed: 2400
        )

        let streak = try AnalyticsService.streakDays(context: context, now: now, calendar: calendar)
        XCTAssertEqual(streak, 2)

        let trend = try AnalyticsService.dailyTrend(days: 2, context: context, now: now, calendar: calendar)
        XCTAssertEqual(trend.count, 2)
        XCTAssertEqual(trend.last?.sessionCount, 1)
        XCTAssertEqual(Int((trend.last?.completionRate ?? 0) * 100), 80)
    }

    func testDurationDistributionBuckets() throws {
        let container = try TestContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_700_500_000)

        try insertEndedSession(context: context, startedAt: now, endedAt: now, total: 1, completed: 1, elapsed: 600)
        try insertEndedSession(context: context, startedAt: now, endedAt: now, total: 1, completed: 1, elapsed: 1200)
        try insertEndedSession(context: context, startedAt: now, endedAt: now, total: 1, completed: 1, elapsed: 2100)
        try insertEndedSession(context: context, startedAt: now, endedAt: now, total: 1, completed: 1, elapsed: 3000)

        let buckets = try AnalyticsService.durationDistribution(days: 30, context: context, now: now)
        let map = Dictionary(uniqueKeysWithValues: buckets.map { ($0.label, $0.count) })

        XCTAssertEqual(map["0-15 分钟"], 1)
        XCTAssertEqual(map["15-30 分钟"], 1)
        XCTAssertEqual(map["30-45 分钟"], 1)
        XCTAssertEqual(map["45+ 分钟"], 1)
    }

    private func insertEndedSession(
        context: ModelContext,
        startedAt: Date,
        endedAt: Date,
        total: Int,
        completed: Int,
        elapsed: Int
    ) throws {
        let session = FocusSession(
            startedAt: startedAt,
            endedAt: endedAt,
            elapsedSeconds: elapsed,
            state: .ended,
            totalTaskCount: total,
            completedTaskCount: completed
        )
        context.insert(session)
        try context.save()
    }
}

