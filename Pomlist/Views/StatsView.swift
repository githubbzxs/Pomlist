import Charts
import SwiftUI

struct StatsView: View {
    @EnvironmentObject private var store: PomlistStore
    @State private var range: StatsRange = .sevenDays

    var stats: PomlistStats {
        store.stats(for: range)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("周期", selection: $range) {
                        ForEach(StatsRange.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("概览") {
                    LabeledContent("专注次数", value: "\(stats.sessionCount)")
                    LabeledContent("总时长", value: PomlistFormatters.duration(stats.totalSeconds))
                    LabeledContent("完成任务", value: "\(stats.completedTaskCount)")
                    LabeledContent("平均完成率", value: PomlistFormatters.percent(stats.averageCompletionRate))
                    LabeledContent("连续专注", value: "\(stats.focusStreak) 天")
                }

                Section("效率趋势") {
                    TrendChart(points: stats.trend)
                        .frame(height: 150)
                }

                Section("分类贡献") {
                    if stats.categoryContributions.isEmpty {
                        Text("暂无分类数据")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(stats.categoryContributions.prefix(5)) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                LabeledContent(item.category, value: PomlistFormatters.duration(item.seconds))
                                ProgressView(value: Double(item.seconds), total: Double(maxCategorySeconds))
                                    .tint(PomlistStyle.categoryColor(item.category))
                            }
                        }
                    }
                }

                Section("时段分布") {
                    if stats.hourlyDistribution.allSatisfy({ $0.seconds == 0 }) {
                        Text("暂无时段数据")
                            .foregroundStyle(.secondary)
                    } else {
                        HourChart(hours: stats.hourlyDistribution)
                            .frame(height: 130)
                    }
                }
            }
            .navigationTitle("统计")
        }
    }

    private var maxCategorySeconds: Int {
        max(stats.categoryContributions.map(\.seconds).max() ?? 0, 1)
    }
}

private struct TrendChart: View {
    var points: [DailyFocusPoint]

    var body: some View {
        Chart(points) { point in
            BarMark(
                x: .value("日期", PomlistFormatters.shortDay.string(from: point.date)),
                y: .value("分钟", max(0, point.seconds / 60))
            )
            .foregroundStyle(.tint)

            if point.completionRate > 0 {
                PointMark(
                    x: .value("日期", PomlistFormatters.shortDay.string(from: point.date)),
                    y: .value("分钟", max(0, point.seconds / 60))
                )
            }
        }
        .chartYAxisLabel("分钟")
    }
}

private struct HourChart: View {
    var hours: [HourlyContribution]

    var body: some View {
        Chart(hours) { item in
            BarMark(
                x: .value("小时", item.hour),
                y: .value("分钟", max(0, item.seconds / 60))
            )
            .foregroundStyle(item.seconds > 0 ? Color.accentColor : Color.secondary.opacity(0.35))
        }
        .chartXAxis {
            AxisMarks(values: [0, 12, 23]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let hour = value.as(Int.self) {
                        Text(String(format: "%02d", hour))
                    }
                }
            }
        }
        .chartYAxisLabel("分钟")
    }
}
