import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: PomlistStore
    @State private var showStartPicker = false
    @State private var showAppendPicker = false
    @State private var showTaskEditor = false
    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                PomlistTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        ScreenHeader(
                            title: "今日",
                            subtitle: store.activeSession == nil ? "选择任务后开始一轮专注" : "本轮专注正在推进",
                            systemImage: "timer"
                        )

                        if let session = store.activeSession {
                            ActiveSessionPanel(session: session, now: now) {
                                showAppendPicker = true
                            } endAction: {
                                store.endActiveSession()
                            }
                        } else {
                            StartFocusPanel {
                                showStartPicker = true
                            } newTaskAction: {
                                showTaskEditor = true
                            }
                        }

                        TodayProgressPanel(tasks: store.todayTasks, sessions: store.endedSessions)

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("今日任务")
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                                    .foregroundStyle(PomlistTheme.text)
                                Spacer()
                                Button {
                                    showTaskEditor = true
                                } label: {
                                    Image(systemName: "plus")
                                }
                                .buttonStyle(SecondaryButtonStyle())
                            }

                            if store.todayTasks.isEmpty {
                                EmptyStateView(systemImage: "checklist", title: "还没有任务", message: "先新增一个可推进事项。")
                            } else {
                                LazyVStack(spacing: 12) {
                                    ForEach(store.todayTasks.prefix(8)) { task in
                                        CompactTaskRow(task: task)
                                    }
                                }
                            }
                        }
                    }
                    .pomlistScreenPadding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
        .onReceive(timer) { value in
            now = value
        }
        .sheet(isPresented: $showStartPicker) {
            TaskSelectionView(mode: .start)
                .environmentObject(store)
        }
        .sheet(isPresented: $showAppendPicker) {
            TaskSelectionView(mode: .append)
                .environmentObject(store)
        }
        .sheet(isPresented: $showTaskEditor) {
            TaskEditorView()
                .environmentObject(store)
        }
    }
}

private struct StartFocusPanel: View {
    var startAction: () -> Void
    var newTaskAction: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("准备进入专注")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(PomlistTheme.text)
                    Text("先选任务，再启动本轮。")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(PomlistTheme.secondaryText)
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 48, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(PomlistTheme.accent)
            }

            HStack(spacing: 12) {
                Button {
                    startAction()
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("开始专注")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())

                Button {
                    newTaskAction()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityLabel("新增任务")
            }
        }
        .padding(22)
        .glassPanel(cornerRadius: 30, opacity: 0.8)
    }
}

private struct ActiveSessionPanel: View {
    @EnvironmentObject private var store: PomlistStore
    var session: FocusSession
    var now: Date
    var appendAction: () -> Void
    var endAction: () -> Void

    @State private var pulse = false

    var elapsed: Int {
        session.elapsedSecondsNow(referenceDate: now)
    }

    var body: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .stroke(PomlistTheme.accent.opacity(0.11), lineWidth: 18)
                    .frame(width: 214, height: 214)
                    .scaleEffect(pulse ? 1.06 : 0.98)
                    .opacity(pulse ? 0.58 : 0.95)
                Circle()
                    .trim(from: 0, to: max(0.04, session.completionRate))
                    .stroke(
                        AngularGradient(colors: [PomlistTheme.accent, PomlistTheme.blue, PomlistTheme.accent], center: .center),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .frame(width: 214, height: 214)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.55, dampingFraction: 0.86), value: session.completionRate)
                VStack(spacing: 8) {
                    Text(PomlistFormatters.clock(elapsed))
                        .font(.system(size: 43, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(PomlistTheme.text)
                    Text("\(session.completedTaskCount)/\(session.totalTaskCount) 完成")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(PomlistTheme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }

            LazyVStack(spacing: 10) {
                ForEach(session.tasks.sorted { $0.orderIndex < $1.orderIndex }) { snapshot in
                    SessionTaskRow(snapshot: snapshot) {
                        store.toggleSessionTask(snapshot.id)
                    }
                }
            }

            HStack(spacing: 12) {
                Button {
                    appendAction()
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text("追加任务")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())

                Button {
                    endAction()
                } label: {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("结束")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(22)
        .glassPanel(cornerRadius: 32, opacity: 0.82)
    }
}

private struct SessionTaskRow: View {
    var snapshot: SessionTaskSnapshot
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: snapshot.isCompletedInSession ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(snapshot.isCompletedInSession ? PomlistTheme.accent : PomlistTheme.secondaryText)
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 5) {
                    Text(snapshot.titleSnapshot)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(snapshot.isCompletedInSession ? PomlistTheme.secondaryText : PomlistTheme.text)
                        .strikethrough(snapshot.isCompletedInSession, color: PomlistTheme.secondaryText)
                    Text(snapshot.categorySnapshot)
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(PomlistTheme.categoryColor(snapshot.categorySnapshot))
                }
                Spacer()
            }
            .padding(14)
            .background(snapshot.isCompletedInSession ? PomlistTheme.accent.opacity(0.08) : Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct TodayProgressPanel: View {
    var tasks: [PomTask]
    var sessions: [FocusSession]

    var todaySessions: [FocusSession] {
        sessions.filter { Calendar.current.isDateInToday($0.startedAt) }
    }

    var completedToday: Int {
        tasks.filter { $0.status == .completed }.count
    }

    var body: some View {
        let totalSeconds = todaySessions.reduce(0) { $0 + $1.elapsedSeconds }
        let completion = tasks.isEmpty ? 0 : Double(completedToday) / Double(tasks.count)
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                MetricPill(title: "专注", value: "\(todaySessions.count)", tint: PomlistTheme.accent)
                MetricPill(title: "时长", value: PomlistFormatters.duration(totalSeconds), tint: PomlistTheme.blue)
            }
            HStack(spacing: 12) {
                MetricPill(title: "任务", value: "\(completedToday)/\(tasks.count)", tint: PomlistTheme.amber)
                MetricPill(title: "完成率", value: PomlistFormatters.percent(completion), tint: PomlistTheme.rose)
            }
        }
    }
}

struct CompactTaskRow: View {
    @EnvironmentObject private var store: PomlistStore
    var task: PomTask

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                    store.setTaskStatus(task.id, status: task.status == .completed ? .todo : .completed)
                }
            } label: {
                Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(task.status == .completed ? PomlistTheme.accent : PomlistTheme.secondaryText)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(task.status == .completed ? PomlistTheme.secondaryText : PomlistTheme.text)
                    .strikethrough(task.status == .completed, color: PomlistTheme.secondaryText)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text(task.category)
                        .foregroundStyle(PomlistTheme.categoryColor(task.category))
                    ForEach(task.tags.prefix(2), id: \.self) { tag in
                        Text("#\(tag)")
                            .foregroundStyle(PomlistTheme.secondaryText)
                    }
                }
                .font(.system(.caption, design: .rounded, weight: .medium))
            }
            Spacer(minLength: 0)
        }
        .padding(15)
        .background(PomlistTheme.panel, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(PomlistTheme.stroke, lineWidth: 1)
        }
    }
}
