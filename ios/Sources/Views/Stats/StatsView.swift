import SwiftUI

struct StatsView: View {
    let analyticsService: PLAnalyticsService

    @State private var selectedDays: Int = 7
    @State private var snapshot: PLAnalyticsSnapshot = .empty(days: 7)
    @State private var message: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Picker("统计范围", selection: $selectedDays) {
                        Text("7 天").tag(7)
                        Text("30 天").tag(30)
                        Text("90 天").tag(90)
                    }
                    .pickerStyle(.segmented)

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ], spacing: 10) {
                        PLMetricCard(
                            title: "完成会话",
                            value: "\(snapshot.totalSessions)",
                            note: "近 \(snapshot.days) 天"
                        )
                        PLMetricCard(
                            title: "总专注时长",
                            value: PLFormatters.minuteText(seconds: snapshot.totalFocusSeconds),
                            note: "累计"
                        )
                        PLMetricCard(
                            title: "平均每次",
                            value: PLFormatters.minuteText(seconds: snapshot.averageFocusSeconds),
                            note: "按会话计算"
                        )
                        PLMetricCard(
                            title: "完成任务",
                            value: "\(snapshot.completedTaskRefs)",
                            note: "会话内快照"
                        )
                    }

                    PLPanelCard(title: "分类贡献") {
                        if snapshot.categoryBreakdown.isEmpty {
                            Text("暂无分类数据。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(snapshot.categoryBreakdown.prefix(6)) { item in
                                    barRow(
                                        title: item.name,
                                        value: item.count,
                                        maxValue: snapshot.categoryBreakdown.first?.count ?? 1,
                                        tint: .indigo
                                    )
                                }
                            }
                        }
                    }

                    PLPanelCard(title: "时间分布（按小时）") {
                        let maxValue = snapshot.hourlyDistribution.map(\.count).max() ?? 1
                        VStack(spacing: 8) {
                            ForEach(snapshot.hourlyDistribution) { item in
                                if item.count > 0 {
                                    barRow(
                                        title: String(format: "%02d:00", item.hour),
                                        value: item.count,
                                        maxValue: maxValue,
                                        tint: .teal
                                    )
                                }
                            }
                            if maxValue == 0 {
                                Text("暂无时段分布数据。")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    PLPanelCard(title: "每日趋势") {
                        if snapshot.dailyTrend.isEmpty {
                            Text("暂无趋势数据。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            let maxValue = snapshot.dailyTrend.map(\.focusSeconds).max() ?? 1
                            VStack(spacing: 8) {
                                ForEach(snapshot.dailyTrend) { day in
                                    barRow(
                                        title: day.label,
                                        value: day.focusSeconds / 60,
                                        maxValue: max(1, maxValue / 60),
                                        tint: .blue
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("Stats")
            .task {
                reloadSnapshot()
            }
            .onChange(of: selectedDays) { _, _ in
                reloadSnapshot()
            }
            .alert("提示", isPresented: .constant(message != nil), presenting: message) { _ in
                Button("我知道了") { message = nil }
            } message: { text in
                Text(text)
            }
        }
    }

    private func barRow(title: String, value: Int, maxValue: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text("\(value)")
                    .font(.caption)
                    .monospacedDigit()
            }
            GeometryReader { proxy in
                let widthRatio = CGFloat(value) / CGFloat(max(1, maxValue))
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(uiColor: .tertiarySystemFill))
                    Capsule()
                        .fill(tint.opacity(0.85))
                        .frame(width: max(8, proxy.size.width * widthRatio))
                }
            }
            .frame(height: 8)
        }
    }

    private func reloadSnapshot() {
        do {
            snapshot = try analyticsService.buildSnapshot(days: selectedDays)
            message = nil
        } catch {
            message = error.localizedDescription
        }
    }
}
