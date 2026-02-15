import SwiftUI

struct FocusView: View {
    @ObservedObject var serviceHub: PLServiceHub

    @State private var todos: [PLTodo] = []
    @State private var activeSession: PLFocusSession?
    @State private var selectedTodoIDs = Set<String>()
    @State private var elapsedSeconds = 0
    @State private var ticker: Timer?
    @State private var message: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    PLPanelCard(title: "当前专注") {
                        if let activeSession {
                            activeSessionView(activeSession)
                        } else {
                            idleView
                        }
                    }

                    PLPanelCard(title: "待选任务") {
                        if pendingTodos.isEmpty {
                            Text("暂无待办任务，请先在任务页创建。")
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(pendingTodos, id: \.id) { todo in
                                    selectableRow(todo)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("专注")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("刷新") {
                        reload()
                    }
                }
            }
            .onAppear(perform: reload)
            .onDisappear(perform: stopTicker)
            .alert("提示", isPresented: .constant(message != nil), presenting: message) { _ in
                Button("知道了") { message = nil }
            } message: { text in
                Text(text)
            }
        }
    }

    private var pendingTodos: [PLTodo] {
        todos.filter { $0.status == "pending" }
    }

    private var idleView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("未开始")
                .foregroundStyle(.secondary)

            Text("已选任务：\(selectedTodoIDs.count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("开始专注") {
                startSession()
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedTodoIDs.isEmpty)
        }
    }

    private func activeSessionView(_ session: PLFocusSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(PLFormatters.durationText(seconds: elapsedSeconds))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())

            Text("完成率 \(PLFormatters.rateText(session.completionRate))（\(session.completedTaskCount)/\(session.totalTaskCount)）")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !session.taskRefs.isEmpty {
                VStack(spacing: 8) {
                    ForEach(session.taskRefs.sorted(by: { $0.orderIndex < $1.orderIndex }), id: \.id) { ref in
                        Button {
                            toggle(ref)
                        } label: {
                            HStack {
                                Image(systemName: ref.isCompletedInSession ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(ref.isCompletedInSession ? .green : .secondary)
                                Text(ref.titleSnapshot)
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 10) {
                Button("结束") {
                    endSession(session)
                }
                .buttonStyle(.borderedProminent)

                Button("取消", role: .destructive) {
                    cancelSession(session)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func selectableRow(_ todo: PLTodo) -> some View {
        Button {
            if selectedTodoIDs.contains(todo.id) {
                selectedTodoIDs.remove(todo.id)
            } else {
                selectedTodoIDs.insert(todo.id)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: selectedTodoIDs.contains(todo.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedTodoIDs.contains(todo.id) ? .blue : .secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(todo.title)
                    HStack(spacing: 6) {
                        PLTagBadge(text: todo.category, tint: .indigo)
                        ForEach(todo.tags, id: \.self) { tag in
                            PLTagBadge(text: tag, tint: .teal)
                        }
                    }
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func reload() {
        do {
            todos = try serviceHub.todoService?.fetchTodos(status: nil) ?? []
            activeSession = try serviceHub.sessionService?.loadActiveSession()
            if let activeSession {
                elapsedSeconds = max(activeSession.elapsedSeconds, Int(Date().timeIntervalSince(activeSession.startedAt)))
                startTicker()
            } else {
                elapsedSeconds = 0
                stopTicker()
            }
        } catch {
            message = error.localizedDescription
        }
    }

    private func startSession() {
        do {
            let picked = pendingTodos.filter { selectedTodoIDs.contains($0.id) }
            activeSession = try serviceHub.sessionService?.startSession(with: picked)
            selectedTodoIDs.removeAll()
            elapsedSeconds = 0
            startTicker()
            reload()
        } catch {
            message = error.localizedDescription
        }
    }

    private func toggle(_ ref: PLSessionTaskRef) {
        do {
            try serviceHub.sessionService?.toggleTask(ref, completed: nil)
            reload()
        } catch {
            message = error.localizedDescription
        }
    }

    private func endSession(_ session: PLFocusSession) {
        do {
            try serviceHub.sessionService?.endSession(session, elapsedSeconds: elapsedSeconds)
            stopTicker()
            reload()
        } catch {
            message = error.localizedDescription
        }
    }

    private func cancelSession(_ session: PLFocusSession) {
        do {
            try serviceHub.sessionService?.cancelSession(session)
            stopTicker()
            reload()
        } catch {
            message = error.localizedDescription
        }
    }

    private func startTicker() {
        stopTicker()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            guard let session = activeSession else { return }
            elapsedSeconds = max(session.elapsedSeconds, Int(Date().timeIntervalSince(session.startedAt)))
        }
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }
}
