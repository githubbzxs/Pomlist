import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: PomlistStore

    @Binding var settingsPresented: Bool

    @State private var pickerPresented = false
    @State private var addMorePresented = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    SectionTitle(
                        eyebrow: "Today",
                        title: "用任务完成度，而不是固定时长，定义本轮专注。",
                        subtitle: activeSubtitle
                    )

                    summaryCard

                    if let activeSession = store.activeSession {
                        activeSessionCard(activeSession)
                    } else {
                        idleStateCard
                    }

                    activeTaskList
                }
                .padding(20)
            }
            .navigationTitle("Pomlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        settingsPresented = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $pickerPresented) {
                TaskPickerSheet(
                    title: "开始任务钟",
                    submitTitle: "开始",
                    excludedTodoIDs: []
                ) { ids in
                    store.startSession(todoIDs: ids)
                }
            }
            .sheet(isPresented: $addMorePresented) {
                TaskPickerSheet(
                    title: "追加任务",
                    submitTitle: "加入",
                    excludedTodoIDs: Set(store.activeSession?.tasks.map(\.todoID) ?? [])
                ) { ids in
                    store.addTasksToActiveSession(todoIDs: ids)
                }
            }
        }
    }

    private var activeSubtitle: String {
        if let activeSession = store.activeSession {
            return "当前正在专注，随时勾选完成项，也可以继续追加任务。"
        }
        if let lastEndedDurationSeconds = store.lastEndedDurationSeconds {
            return "上一轮专注用时 \(lastEndedDurationSeconds.pomlistDurationText())，可以继续开始新一轮。"
        }
        return "没有进行中的任务钟时，你可以先从 Task 页准备任务，再从这里开始。"
    }

    private var summaryCard: some View {
        GlassCard {
            GlassCluster(spacing: 12) {
                HStack(spacing: 12) {
                    MetricCell(
                        title: "今日任务钟",
                        value: "\(store.dashboard.today.sessionCount)",
                        tint: PomlistPalette.accent
                    )
                    MetricCell(
                        title: "今日完成数",
                        value: "\(store.dashboard.today.completedTaskCount)",
                        tint: PomlistPalette.success
                    )
                }

                HStack(spacing: 12) {
                    MetricCell(
                        title: "今日用时",
                        value: store.dashboard.today.totalDurationSeconds.pomlistDurationText(),
                        tint: PomlistPalette.warning
                    )
                    MetricCell(
                        title: "连续天数",
                        value: "\(store.dashboard.streakDays) 天",
                        tint: PomlistPalette.accentSoft
                    )
                }
            }
        }
    }

    private func activeSessionCard(_ activeSession: FocusSession) -> some View {
        GlassCard(tint: PomlistPalette.accent.opacity(0.12)) {
            VStack(alignment: .leading, spacing: 16) {
                GlassPill(
                    title: "\(activeSession.completedTaskCount)/\(max(activeSession.totalTaskCount, 1)) 已完成",
                    systemImage: "bolt.fill",
                    tint: PomlistPalette.accent
                )

                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(activeSession.elapsedSeconds(at: timeline.date).pomlistClockText())
                            .font(.system(size: 46, weight: .bold, design: .rounded))
                            .foregroundStyle(PomlistPalette.ink)

                        ProgressView(value: activeSession.completionRate)
                            .tint(PomlistPalette.accent)

                        Text("你可以继续勾选、补充任务，结束时会自动记录完成率与时长。")
                            .font(.subheadline)
                            .foregroundStyle(PomlistPalette.secondaryInk)
                    }
                }

                HStack(spacing: 12) {
                    Button("追加任务") {
                        addMorePresented = true
                    }
                    .buttonStyle(.bordered)

                    Button("结束本轮") {
                        store.endActiveSession()
                    }
                    .buttonStyle(PrimaryGlassButtonStyle())
                }
            }
        }
    }

    private var idleStateCard: some View {
        GlassCard(tint: Color.white.opacity(0.16)) {
            VStack(alignment: .leading, spacing: 16) {
                Text("当前没有 active session。")
                    .font(.headline)
                    .foregroundStyle(PomlistPalette.ink)

                Text("原 Web 版的任务钟逻辑已经迁移到原生 App：从任务中多选开始，过程中逐项勾选，结束后写入历史与统计。")
                    .font(.subheadline)
                    .foregroundStyle(PomlistPalette.secondaryInk)

                Button("选择任务并开始") {
                    pickerPresented = true
                }
                .buttonStyle(PrimaryGlassButtonStyle())
            }
        }
    }

    private var activeTaskList: some View {
        Group {
            if let activeSession = store.activeSession {
                GlassCard(tint: Color.white.opacity(0.18)) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("本轮任务")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(PomlistPalette.ink)

                        ForEach(activeSession.tasks.sorted(by: { $0.orderIndex < $1.orderIndex })) { task in
                            Button {
                                store.toggleSessionTask(sessionID: activeSession.id, taskID: task.id)
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: task.isCompletedInSession ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(task.isCompletedInSession ? PomlistPalette.success : PomlistPalette.secondaryInk)
                                        .font(.title3)

                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(task.titleSnapshot)
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(PomlistPalette.ink)
                                            .strikethrough(task.isCompletedInSession, color: PomlistPalette.secondaryInk)

                                        TaskTagList(category: task.categorySnapshot, tags: task.tagSnapshot)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                EmptyStateCard(
                    systemImage: "sparkles.rectangle.stack",
                    title: "准备开始下一轮",
                    message: "点击上方按钮选择任务即可开始。原本 Web 版的主流程已经收进这张原生 Today 页。"
                )
            }
        }
    }
}
