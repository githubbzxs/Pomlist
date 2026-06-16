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
            List {
                if let session = store.activeSession {
                    ActiveSessionSection(session: session, now: now) {
                        showAppendPicker = true
                    } endAction: {
                        store.endActiveSession()
                    }
                } else {
                    Section {
                        Button {
                            showStartPicker = true
                        } label: {
                            Label("开始专注", systemImage: "play.fill")
                        }
                        Button {
                            showTaskEditor = true
                        } label: {
                            Label("新增任务", systemImage: "plus")
                        }
                    } header: {
                        Text("专注")
                    }
                }

                TodayProgressSection(tasks: store.todayTasks, sessions: store.endedSessions)

                Section {
                    if store.todayTasks.isEmpty {
                        ContentUnavailableTaskView(
                            systemImage: "checklist",
                            title: "还没有任务",
                            message: "先新增一个可推进事项。"
                        )
                    } else {
                        ForEach(store.todayTasks.prefix(8)) { task in
                            CompactTaskRow(task: task)
                        }
                    }
                } header: {
                    Text("今日任务")
                }
            }
            .navigationTitle("今日")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showTaskEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("新增任务")
                }
            }
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

private struct ActiveSessionSection: View {
    @EnvironmentObject private var store: PomlistStore
    var session: FocusSession
    var now: Date
    var appendAction: () -> Void
    var endAction: () -> Void

    var elapsed: Int {
        session.elapsedSecondsNow(referenceDate: now)
    }

    var body: some View {
        Section {
            Gauge(value: session.completionRate) {
                Text("完成率")
            } currentValueLabel: {
                Text(PomlistFormatters.percent(session.completionRate))
            }

            HStack {
                Label(PomlistFormatters.clock(elapsed), systemImage: "timer")
                    .monospacedDigit()
                Spacer()
                Text("\(session.completedTaskCount)/\(session.totalTaskCount) 完成")
                    .foregroundStyle(.secondary)
            }

            ForEach(session.tasks.sorted { $0.orderIndex < $1.orderIndex }) { snapshot in
                Button {
                    store.toggleSessionTask(snapshot.id)
                } label: {
                    SessionTaskRow(snapshot: snapshot)
                }
                .buttonStyle(.plain)
            }

            Button {
                appendAction()
            } label: {
                Label("追加任务", systemImage: "plus")
            }

            Button(role: .destructive) {
                endAction()
            } label: {
                Label("结束", systemImage: "stop.fill")
            }
        } header: {
            Text("本轮专注")
        }
    }
}

private struct SessionTaskRow: View {
    var snapshot: SessionTaskSnapshot

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.titleSnapshot)
                    .strikethrough(snapshot.isCompletedInSession)
                Text(snapshot.categorySnapshot)
                    .font(.footnote)
                    .foregroundStyle(PomlistStyle.categoryColor(snapshot.categorySnapshot))
            }
        } icon: {
            Image(systemName: snapshot.isCompletedInSession ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(snapshot.isCompletedInSession ? Color.accentColor : Color.secondary)
        }
    }
}

private struct TodayProgressSection: View {
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

        Section {
            LabeledContent("专注", value: "\(todaySessions.count)")
            LabeledContent("时长", value: PomlistFormatters.duration(totalSeconds))
            LabeledContent("任务", value: "\(completedToday)/\(tasks.count)")
            LabeledContent("完成率", value: PomlistFormatters.percent(completion))
        } header: {
            Text("今日进度")
        }
    }
}

struct CompactTaskRow: View {
    @EnvironmentObject private var store: PomlistStore
    var task: PomTask

    var body: some View {
        Button {
            store.setTaskStatus(task.id, status: task.status == .completed ? .todo : .completed)
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .strikethrough(task.status == .completed)
                    HStack(spacing: 8) {
                        Text(task.category)
                            .foregroundStyle(PomlistStyle.categoryColor(task.category))
                        ForEach(task.tags.prefix(2), id: \.self) { tag in
                            Text("#\(tag)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.footnote)
                }
            } icon: {
                Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.status == .completed ? Color.accentColor : Color.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}
