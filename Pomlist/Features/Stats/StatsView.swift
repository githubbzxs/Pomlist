import Charts
import SwiftUI

struct StatsView: View {
    @EnvironmentObject private var store: PomlistStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    SectionTitle(
                        eyebrow: "Stats",
                        title: "从任务钟结果里看效率，而不是只看倒计时。",
                        subtitle: "今日、近 7 天、近 30 天、分类贡献与时间分布都保留了。"
                    )

                    periodSection
                    efficiencySection
                    categorySection
                    hourlySection
                }
                .padding(20)
            }
            .navigationTitle("Statistic")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var periodSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("周期指标")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(PomlistPalette.ink)

                HStack(spacing: 12) {
                    periodBlock(title: "今日", metrics: store.dashboard.today)
                    periodBlock(title: "7 天", metrics: store.dashboard.last7Days)
                    periodBlock(title: "30 天", metrics: store.dashboard.last30Days)
                }
            }
        }
    }

    private var efficiencySection: some View {
        let efficiency = store.dashboard.efficiency

        return GlassCard(tint: PomlistPalette.accent.opacity(0.12)) {
            VStack(alignment: .leading, spacing: 14) {
                Text("效率视角")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(PomlistPalette.ink)

                HStack(spacing: 12) {
                    MetricCell(title: "每小时完成任务", value: String(format: "%.2f", efficiency.tasksPerHour), tint: PomlistPalette.accent)
                    MetricCell(title: "平均时长", value: efficiency.averageSessionDurationSeconds.pomlistDurationText(), tint: PomlistPalette.warning)
                }

                HStack(spacing: 12) {
                    MetricCell(title: "平均完成率", value: "\(Int(efficiency.averageCompletionRate * 100))%", tint: PomlistPalette.success)
                    MetricCell(title: "7 天会话增量", value: "\(efficiency.sessionDelta)", tint: PomlistPalette.accentSoft)
                }
            }
        }
    }

    private var categorySection: some View {
        GlassCard(tint: Color.white.opacity(0.16)) {
            VStack(alignment: .leading, spacing: 14) {
                Text("分类贡献")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(PomlistPalette.ink)

                if store.dashboard.categoryStats.isEmpty {
                    Text("完成至少一轮任务钟后，这里会统计分类或首标签对时长的贡献。")
                        .font(.subheadline)
                        .foregroundStyle(PomlistPalette.secondaryInk)
                } else {
                    Chart(store.dashboard.categoryStats.prefix(6)) { item in
                        BarMark(
                            x: .value("分类", item.category),
                            y: .value("分钟", item.totalDurationSeconds / 60)
                        )
                        .foregroundStyle(PomlistPalette.accent.gradient)
                    }
                    .frame(height: 220)
                }
            }
        }
    }

    private var hourlySection: some View {
        GlassCard(tint: Color.white.opacity(0.14)) {
            VStack(alignment: .leading, spacing: 14) {
                Text("时间分布")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(PomlistPalette.ink)

                if store.dashboard.hourlyDistribution.allSatisfy({ $0.sessionCount == 0 }) {
                    Text("还没有足够数据来展示 24 小时分布。")
                        .font(.subheadline)
                        .foregroundStyle(PomlistPalette.secondaryInk)
                } else {
                    Chart(store.dashboard.hourlyDistribution) { item in
                        BarMark(
                            x: .value("小时", String(format: "%02d:00", item.hour)),
                            y: .value("会话数", item.sessionCount)
                        )
                        .foregroundStyle(PomlistPalette.accentSoft.gradient)
                    }
                    .frame(height: 220)
                }
            }
        }
    }

    private func periodBlock(title: String, metrics: PeriodMetrics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(PomlistPalette.ink)
            Text("\(metrics.sessionCount) 次")
                .font(.title3.weight(.semibold))
                .foregroundStyle(PomlistPalette.accent)
            Text(metrics.totalDurationSeconds.pomlistDurationText())
                .font(.footnote)
                .foregroundStyle(PomlistPalette.secondaryInk)
            Text("完成 \(metrics.completedTaskCount) 项 · \(Int(metrics.completionRate * 100))%")
                .font(.caption)
                .foregroundStyle(PomlistPalette.secondaryInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.6))
        )
    }
}
