import SwiftData
import SwiftUI

struct FocusView: View {
    let sessionService: PLSessionService

    @Query(
        sort: [
            SortDescriptor(\PLTodo.isDone),
            SortDescriptor(\PLTodo.updatedAt, order: .reverse)
        ]
    )
    private var todos: [PLTodo]

    @State private var selectedTodoIDs: Set<UUID> = []
    @State private var plannedMinutes: Int = 25
    @State private var activeSession: PLFocusSession?
    @State private var elapsedSeconds: Int = 0
    @State private var lastFinishedDuration: Int?
    @State private var message: String?
    @State private var ticker: Timer?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    PLPanelCard(title: "当前专注") {
                        if let activeSession {
                            activeSessionContent(activeSession)
                        } else {
                            idleSessionContent
                        }
                    }

                    if let lastFinishedDuration {
                        PLPanelCard(title: "上次完成") {
                            Text(PLFormatters.minuteText(seconds: lastFinishedDuration))
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    }

                    PLPanelCard(title: "待选任务") {
                        if selectableTodos.isEmpty {
                            Text("暂无可选任务，请先到 Tasks 页面添加。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(selectableTodos) { todo in
                                    todoSelectionRow(todo)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("Focus")
            .onAppear {
                reloadActiveSession()
            }
            .onDisappear {
                stopTicker()
            }
            .alert("提示", isPresented: .constant(message != nil), presenting: message) { _ in
                Button("我知道了") { message = nil }
            } message: { text in
                Text(text)
            }
        }
    }

    private var selectableTodos: [PLTodo] {
        todos.filter { !$0.isDone }
    }

    @ViewBuilder
    private var idleSessionContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Stepper(value: $plannedMinutes, in: 5 ... 180, step: 5) {
                Text("计划时长：\(plannedMinutes) 分钟")
                    .font(.body)
            }

            Text("已选任务：\(selectedTodoIDs.count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("开始专注") {
                startSession()
            }
            .buttonStyle(.borderedProminent)
            .disabled(activeSession != nil)
        }
    }

    @ViewBuilder
    private func activeSessionContent(_ session: PLFocusSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(PLFormatters.durationText(seconds: elapsedSeconds))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()

            Text("计划 \(session.plannedMinutes) 分钟")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !session.taskRefs.isEmpty {
                Text("会话任务")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(session.taskRefs.sorted(by: { $0.createdAt < $1.createdAt })) { ref in
                        HStack(spacing: 8) {
                            Image(systemName: ref.wasDoneAtEnd ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(ref.wasDoneAtEnd ? .green : .secondary)
                            Text(ref.todoTitleSnapshot)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if !ref.categorySnapshot.isEmpty {
                                PLTagBadge(text: ref.categorySnapshot, tint: .blue)
                            }
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                Button("结束") {
                    finishSession(session)
                }
                .buttonStyle(.borderedProminent)

                Button("取消", role: .destructive) {
                    cancelSession(session)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func todoSelectionRow(_ todo: PLTodo) -> some View {
        Button {
            if selectedTodoIDs.contains(todo.id) {
                selectedTodoIDs.remove(todo.id)
            } else {
                selectedTodoIDs.insert(todo.id)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: selectedTodoIDs.contains(todo.id) ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selectedTodoIDs.contains(todo.id) ? .blue : .secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(todo.title)
                        .font(.body)
                        .foregroundStyle(.primary)
                    if !todo.category.isEmpty || !todo.tags.isEmpty {
                        HStack(spacing: 6) {
                            if !todo.category.isEmpty {
                                PLTagBadge(text: todo.category, tint: .indigo)
                            }
                            ForEach(todo.tags, id: \.self) { tag in
                                PLTagBadge(text: tag, tint: .teal)
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func reloadActiveSession() {
        do {
            activeSession = try sessionService.loadActiveSession()
            if let session = activeSession {
                elapsedSeconds = max(0, Int(Date().timeIntervalSince(session.startedAt)))
                startTicker()
            } else {
                stopTicker()
                elapsedSeconds = 0
            }
        } catch {
            message = error.localizedDescription
        }
    }

    private func startSession() {
        do {
            let selected = todos.filter { selectedTodoIDs.contains($0.id) }
            activeSession = try sessionService.startSession(with: selected, plannedMinutes: plannedMinutes)
            elapsedSeconds = 0
            startTicker()
        } catch {
            message = error.localizedDescription
        }
    }

    private func finishSession(_ session: PLFocusSession) {
        do {
            try sessionService.finishSession(session, elapsedSeconds: elapsedSeconds)
            lastFinishedDuration = elapsedSeconds
            activeSession = nil
            elapsedSeconds = 0
            stopTicker()
            selectedTodoIDs.removeAll()
        } catch {
            message = error.localizedDescription
        }
    }

    private func cancelSession(_ session: PLFocusSession) {
        do {
            try sessionService.cancelSession(session)
            activeSession = nil
            elapsedSeconds = 0
            stopTicker()
        } catch {
            message = error.localizedDescription
        }
    }

    private func startTicker() {
        stopTicker()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            guard let session = activeSession else { return }
            elapsedSeconds = max(0, Int(Date().timeIntervalSince(session.startedAt)))
        }
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }
}
