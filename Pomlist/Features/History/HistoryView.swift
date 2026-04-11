import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: PomlistStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    SectionTitle(
                        eyebrow: "History",
                        title: "每一次结束的任务钟，都会在这里留下快照。",
                        subtitle: "时间、时长、任务与完成率都来自本地 JSON 持久化。"
                    )

                    if store.sessionHistory.isEmpty {
                        EmptyStateCard(
                            systemImage: "clock.badge.questionmark",
                            title: "还没有历史记录",
                            message: "完成至少一轮专注后，这里就会出现本次任务钟的快照。"
                        )
                    } else {
                        ForEach(store.sessionHistory) { session in
                            GlassCard(tint: Color.white.opacity(0.16)) {
                                VStack(alignment: .leading, spacing: 14) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text((session.endedAt ?? session.startedAt).pomlistMonthDayText())
                                                .font(.title3.weight(.semibold))
                                                .foregroundStyle(PomlistPalette.ink)
                                            Text((session.endedAt ?? session.startedAt).pomlistFullStampText())
                                                .font(.subheadline)
                                                .foregroundStyle(PomlistPalette.secondaryInk)
                                        }
                                        Spacer(minLength: 0)
                                        GlassPill(
                                            title: "\(session.completedTaskCount)/\(max(session.totalTaskCount, 1))",
                                            systemImage: "checkmark.seal",
                                            tint: PomlistPalette.success
                                        )
                                    }

                                    HStack(spacing: 12) {
                                        MetricCell(title: "用时", value: session.elapsedSeconds.pomlistDurationText(), tint: PomlistPalette.warning)
                                        MetricCell(title: "完成率", value: "\(Int(session.completionRate * 100))%", tint: PomlistPalette.accent)
                                    }

                                    VStack(alignment: .leading, spacing: 10) {
                                        ForEach(session.tasks.sorted(by: { $0.orderIndex < $1.orderIndex })) { task in
                                            HStack(spacing: 12) {
                                                Image(systemName: task.isCompletedInSession ? "checkmark.circle.fill" : "circle")
                                                    .foregroundStyle(task.isCompletedInSession ? PomlistPalette.success : PomlistPalette.secondaryInk)
                                                Text(task.titleSnapshot)
                                                    .foregroundStyle(PomlistPalette.ink)
                                                Spacer(minLength: 0)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
