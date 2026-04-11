import XCTest
@testable import Pomlist

final class PomlistAnalyticsTests: XCTestCase {
    func testDashboardBuildAggregatesPeriods() {
        let now = Date()

        let session = FocusSession(
            state: .ended,
            startedAt: Calendar(identifier: .gregorian).date(byAdding: .minute, value: -40, to: now) ?? now,
            endedAt: now,
            elapsedSeconds: 1_800,
            totalTaskCount: 3,
            completedTaskCount: 2,
            completionRate: 2.0 / 3.0,
            tasks: [
                SessionTaskSnapshot(todoID: "1", titleSnapshot: "任务 A", categorySnapshot: "工作", tagSnapshot: ["工作"], orderIndex: 0, isCompletedInSession: true),
                SessionTaskSnapshot(todoID: "2", titleSnapshot: "任务 B", categorySnapshot: "学习", tagSnapshot: ["学习"], orderIndex: 1, isCompletedInSession: true),
                SessionTaskSnapshot(todoID: "3", titleSnapshot: "任务 C", categorySnapshot: "工作", tagSnapshot: ["工作"], orderIndex: 2, isCompletedInSession: false)
            ]
        )

        let dashboard = PomlistAnalyticsService.buildDashboard(from: [session])

        XCTAssertEqual(dashboard.today.sessionCount, 1)
        XCTAssertEqual(dashboard.today.completedTaskCount, 2)
        XCTAssertEqual(dashboard.last7Days.totalDurationSeconds, 1_800)
        XCTAssertEqual(dashboard.categoryStats.first?.category, "工作")
        XCTAssertEqual(dashboard.hourlyDistribution.reduce(0) { $0 + $1.sessionCount }, 1)
    }
}
