import SwiftUI

struct StatsView: View {
    @EnvironmentObject private var store: PomlistStore
    @State private var range: StatsRange = .sevenDays

    var stats: PomlistStats {
        store.stats(for: range)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PomlistTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        ScreenHeader(title: "统计", subtitle: range.title, systemImage: "chart.xyaxis.line")
                        Picker("周期", selection: $range) {
                            ForEach(StatsRange.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            MetricPill(title: "专注次数", value: "\(stats.sessionCount)", tint: PomlistTheme.accent)
                            MetricPill(title: "总时长", value: PomlistFormatters.duration(stats.totalSeconds), tint: PomlistTheme.blue)
                            MetricPill(title: "完成任务", value: "\(stats.completedTaskCount)", tint: PomlistTheme.amber)
                            MetricPill(title: "平均完成率", value: PomlistFormatters.percent(stats.averageCompletionRate), tint: PomlistTheme.rose)
                        }

                        StreakPanel(streak: stats.focusStreak)
                        TrendPanel(points: stats.trend)
                        CategoryPanel(contributions: stats.categoryContributions)
                        HourPanel(hours: stats.hourlyDistribution)
                    }
                    .pomlistScreenPadding()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct StreakPanel: View {
    var streak: Int

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "flame.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(PomlistTheme.amber)
                .frame(width: 54, height: 54)
                .background(PomlistTheme.amber.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 6) {
                Text("\(streak) 天")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(PomlistTheme.text)
                Text("连续专注")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(PomlistTheme.secondaryText)
            }
            Spacer()
        }
        .padding(18)
        .glassPanel(cornerRadius: 23, opacity: 0.78)
    }
}

private struct TrendPanel: View {
    var points: [DailyFocusPoint]

    var maxSeconds: Int {
        max(points.map(\.seconds).max() ?? 0, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("效率趋势")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(PomlistTheme.text)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(points) { point in
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [PomlistTheme.accent, PomlistTheme.blue.opacity(0.72)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: max(10, CGFloat(point.seconds) / CGFloat(maxSeconds) * 118))
                            .overlay(alignment: .top) {
                                if point.completionRate > 0 {
                                    Circle()
                                        .fill(PomlistTheme.amber)
                                        .frame(width: 7, height: 7)
                                        .offset(y: -4)
                                }
                            }
                            .animation(.spring(response: 0.45, dampingFraction: 0.84), value: point.seconds)
                        Text(PomlistFormatters.shortDay.string(from: point.date))
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(PomlistTheme.mutedText)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 156, alignment: .bottom)
        }
        .padding(18)
        .glassPanel(cornerRadius: 23, opacity: 0.78)
    }
}

private struct CategoryPanel: View {
    var contributions: [CategoryContribution]

    var maxSeconds: Int {
        max(contributions.map(\.seconds).max() ?? 0, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("分类贡献")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(PomlistTheme.text)
            if contributions.isEmpty {
                Text("暂无分类数据")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(PomlistTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(contributions.prefix(5)) { item in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text(item.category)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(PomlistTheme.text)
                            Spacer()
                            Text(PomlistFormatters.duration(item.seconds))
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(PomlistTheme.secondaryText)
                        }
                        GeometryReader { proxy in
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                                .overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(PomlistTheme.categoryColor(item.category))
                                        .frame(width: max(8, proxy.size.width * CGFloat(item.seconds) / CGFloat(maxSeconds)))
                                }
                        }
                        .frame(height: 9)
                    }
                }
            }
        }
        .padding(18)
        .glassPanel(cornerRadius: 23, opacity: 0.78)
    }
}

private struct HourPanel: View {
    var hours: [HourlyContribution]

    var activeHours: [HourlyContribution] {
        hours.filter { $0.seconds > 0 }
    }

    var maxSeconds: Int {
        max(activeHours.map(\.seconds).max() ?? 0, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("时段分布")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(PomlistTheme.text)
            if activeHours.isEmpty {
                Text("暂无时段数据")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(PomlistTheme.secondaryText)
            } else {
                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(hours) { item in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(item.seconds > 0 ? PomlistTheme.accent : Color.white.opacity(0.08))
                            .frame(height: max(6, CGFloat(item.seconds) / CGFloat(maxSeconds) * 70))
                    }
                }
                .frame(height: 82, alignment: .bottom)
                HStack {
                    Text("00")
                    Spacer()
                    Text("12")
                    Spacer()
                    Text("23")
                }
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundStyle(PomlistTheme.mutedText)
            }
        }
        .padding(18)
        .glassPanel(cornerRadius: 23, opacity: 0.78)
    }
}
