import SwiftData
import SwiftUI

struct FocusSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState

    @State private var activeSession: FocusSession?
    @State private var latestEndedSession: FocusSession?
    @State private var now: Date = .now
    @State private var showEndConfirm = false
    @State private var localError: String?

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            Group {
                if let session = activeSession {
                    sessionContent(session: session)
                } else {
                    emptyContent
                }
            }
            .navigationTitle("专注中")
            .onAppear {
                reloadSession()
            }
            .onChange(of: appState.activeSessionID) { _, _ in
                reloadSession()
            }
            .onReceive(timer) { currentDate in
                now = currentDate
            }
            .confirmationDialog(
                "结束任务钟",
                isPresented: $showEndConfirm,
                titleVisibility: .visible
            ) {
                Button("结束并记录", role: .destructive) {
                    endCurrentSession()
                }
                Button("取消", role: .cancel) {}
            } message: {
                if let session = activeSession {
                    Text("当前完成 \(session.completedTaskCount)/\(session.totalTaskCount)，确认结束后将写入复盘。")
                }
            }
            .alert(
                "操作失败",
                isPresented: Binding(
                    get: { localError != nil },
                    set: { isPresented in
                        if !isPresented {
                            localError = nil
                        }
                    }
                )
            ) {
                Button("知道了", role: .cancel) {
                    localError = nil
                }
            } message: {
                Text(localError ?? "")
            }
        }
    }

    @ViewBuilder
    private func sessionContent(session: FocusSession) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Text("\(session.completedTaskCount) / \(session.totalTaskCount)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                    Text("已用时 \(TimeTextFormatter.mmss(displayElapsed(session: session)))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 12) {
                    Text("本钟任务")
                        .font(.headline)
                    ForEach(sortedRefs(for: session), id: \.id) { ref in
                        Button {
                            toggle(ref: ref, in: session)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: ref.isCompletedInSession ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(ref.isCompletedInSession ? .green : .secondary)
                                Text(ref.titleSnapshot)
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                Button {
                    showEndConfirm = true
                } label: {
                    Text("结束并记录")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private var emptyContent: some View {
        VStack(spacing: 14) {
            Image(systemName: "target")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)

            Text("当前没有进行中的任务钟")
                .font(.headline)

            if let latestEndedSession {
                Text("上次记录：\(latestEndedSession.completedTaskCount)/\(latestEndedSession.totalTaskCount)，\(TimeTextFormatter.hourMinute(latestEndedSession.elapsedSeconds))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button("去 To-Do 开始") {
                appState.selectedTab = .todo
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
    }

    private func reloadSession() {
        do {
            if let id = appState.activeSessionID {
                activeSession = try SessionService.fetchSession(id: id, context: modelContext)
            } else {
                activeSession = try SessionService.activeSession(context: modelContext)
                appState.activeSessionID = activeSession?.id
            }
            latestEndedSession = try SessionService.fetchLatestEndedSession(context: modelContext)
        } catch {
            localError = error.localizedDescription
        }
    }

    private func sortedRefs(for session: FocusSession) -> [SessionTaskRef] {
        session.taskRefs.sorted { $0.orderIndex < $1.orderIndex }
    }

    private func displayElapsed(session: FocusSession) -> Int {
        guard session.state == .active else { return session.elapsedSeconds }
        return max(session.elapsedSeconds, Int(now.timeIntervalSince(session.startedAt)))
    }

    private func toggle(ref: SessionTaskRef, in session: FocusSession) {
        do {
            try SessionService.toggleTask(
                sessionId: session.id,
                todoId: ref.todoId,
                isCompleted: !ref.isCompletedInSession,
                context: modelContext
            )
            reloadSession()
        } catch {
            localError = error.localizedDescription
        }
    }

    private func endCurrentSession() {
        guard let session = activeSession else { return }
        do {
            _ = try SessionService.endSession(sessionId: session.id, context: modelContext)
            appState.activeSessionID = nil
            reloadSession()
        } catch {
            localError = error.localizedDescription
        }
    }
}
