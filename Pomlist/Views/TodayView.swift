import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState

    @Query(sort: [SortDescriptor(\TodoItem.createdAt, order: .forward)])
    private var todos: [TodoItem]

    @Query(
        filter: #Predicate<FocusSession> { session in
            session.stateValue == "ended"
        },
        sort: [SortDescriptor(\FocusSession.endedAt, order: .reverse)]
    )
    private var endedSessions: [FocusSession]

    @State private var localError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("今天已完成 \(todayCompletedTaskCount) 项任务")
                            .font(.headline)
                        Text("今日任务钟 \(todaySessionCount) 个")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("今日待办")
                            .font(.headline)
                        if todayTodos.isEmpty {
                            Text("今天还没有待办任务。")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(Array(todayTodos.prefix(6)), id: \.id) { todo in
                                TodoRowView(todo: todo, isSelectedForSession: false)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))

                    Button {
                        quickStartSession()
                    } label: {
                        Text(quickStartButtonTitle)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(quickStartCandidates.isEmpty || appState.activeSessionID != nil)
                }
                .padding(16)
            }
            .navigationTitle("今日")
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

    private var pendingTodos: [TodoItem] {
        todos.filter { $0.status == .pending }
    }

    private var todayTodos: [TodoItem] {
        let calendar = Calendar.current
        let dueToday = pendingTodos.filter { todo in
            guard let dueAt = todo.dueAt else { return false }
            return calendar.isDateInToday(dueAt)
        }
        if !dueToday.isEmpty {
            return dueToday
        }
        return pendingTodos
    }

    private var quickStartCandidates: [TodoItem] {
        Array(todayTodos.prefix(3))
    }

    private var quickStartButtonTitle: String {
        if quickStartCandidates.isEmpty {
            return "暂无可开始任务"
        }
        return "一键开始任务钟（\(quickStartCandidates.count) 项）"
    }

    private var todaySessionCount: Int {
        endedSessions.filter { session in
            guard let endedAt = session.endedAt else { return false }
            return Calendar.current.isDateInToday(endedAt)
        }.count
    }

    private var todayCompletedTaskCount: Int {
        endedSessions
            .filter { session in
                guard let endedAt = session.endedAt else { return false }
                return Calendar.current.isDateInToday(endedAt)
            }
            .reduce(0) { $0 + $1.completedTaskCount }
    }

    private func quickStartSession() {
        do {
            let ids = quickStartCandidates.map(\.id)
            let session = try SessionService.startSession(todoIDs: ids, context: modelContext)
            appState.activeSessionID = session.id
            appState.selectedTab = .focus
        } catch {
            localError = error.localizedDescription
        }
    }
}
