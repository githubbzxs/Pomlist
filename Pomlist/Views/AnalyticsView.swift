import Charts
import SwiftData
import SwiftUI

struct AnalyticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var appState: AppState

    @State private var metrics = AnalyticsDashboardMetrics(
        todaySessionCount: 0,
        todayFocusSeconds: 0,
        todayCompletionRate: 0,
        currentStreakDays: 0
    )
    @State private var trend: [DailyTrendPoint] = []
    @State private var buckets: [DurationBucket] = []
    @State private var localError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    metricsGrid
                    trendChart
                    distributionChart
                }
                .padding(16)
            }
            .navigationTitle("复盘")
            .onAppear {
                reloadAnalytics()
            }
            .onChange(of: scenePhase) { _, value in
                if value == .active {
                    reloadAnalytics()
                }
            }
            .onChange(of: appState.activeSessionID) { _, _ in
                reloadAnalytics()
            }
            .alert(
                "加载失败",
                isPresented: Binding(
                    get: { localError != nil },
                    set: { isPresented in
                        if !isPresented {
                            localError = nil
                        }
                    }
                )
            ) {
                Button("知道了", role: .cancel) {
                    localError = nil
                }
            } message: {
                Text(localError ?? "")
            }
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            metricCard(title: "今日任务钟", value: "\(metrics.todaySessionCount)")
            metricCard(title: "今日专注时长", value: TimeTextFormatter.hourMinute(metrics.todayFocusSeconds))
            metricCard(title: "今日完成率", value: "\(Int(metrics.todayCompletionRate * 100))%")
            metricCard(title: "连续天数", value: "\(metrics.currentStreakDays) 天")
        }
    }

    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("近 7 天趋势")
                .font(.headline)
            Chart(trend) { point in
                LineMark(
                    x: .value("日期", point.date),
                    y: .value("完成率", point.completionRate * 100)
                )
                .foregroundStyle(.blue)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("日期", point.date),
                    y: .value("完成率", point.completionRate * 100)
                )
                .foregroundStyle(.blue.opacity(0.14))
            }
            .frame(height: 220)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var distributionChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("近 30 天时长分布")
                .font(.headline)
            Chart(buckets) { bucket in
                BarMark(
                    x: .value("区间", bucket.label),
                    y: .value("次数", bucket.count)
                )
                .foregroundStyle(.teal)
            }
            .frame(height: 220)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func reloadAnalytics() {
        do {
            metrics = try AnalyticsService.dashboardMetrics(context: modelContext)
            trend = try AnalyticsService.dailyTrend(days: 7, context: modelContext)
            buckets = try AnalyticsService.durationDistribution(days: 30, context: modelContext)
        } catch {
            localError = error.localizedDescription
        }
    }
}

