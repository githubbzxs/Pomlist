import SwiftUI

struct HistoryView: View {
    let sessionService: PLSessionService

    @State private var sessions: [PLFocusSession] = []
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "暂无历史记录",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("完成一次专注后会在这里显示。")
                    )
                } else {
                    List {
                        ForEach(sessions) { session in
                            sessionRow(session)
                                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("History")
            .task {
                loadHistory()
            }
            .refreshable {
                loadHistory()
            }
            .alert("提示", isPresented: .constant(message != nil), presenting: message) { _ in
                Button("我知道了") { message = nil }
            } message: { text in
                Text(text)
            }
        }
    }

    private func sessionRow(_ session: PLFocusSession) -> some View {
        PLPanelCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(PLFormatters.dateTime.string(from: session.startedAt))
                        .font(.headline)
                    Spacer(minLength: 0)
                    Text(session.isCancelled ? "已取消" : "已完成")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((session.isCancelled ? Color.red : Color.green).opacity(0.18), in: Capsule())
                }

                HStack(spacing: 12) {
                    Text("计划 \(session.plannedMinutes) 分钟")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("用时 \(PLFormatters.durationText(seconds: session.elapsedSeconds))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if !session.taskRefs.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("任务快照")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        ForEach(session.taskRefs.sorted(by: { $0.createdAt < $1.createdAt })) { ref in
                            HStack(spacing: 8) {
                                Image(systemName: ref.wasDoneAtEnd ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(ref.wasDoneAtEnd ? .green : .secondary)
                                Text(ref.todoTitleSnapshot)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                if !ref.categorySnapshot.isEmpty {
                                    PLTagBadge(text: ref.categorySnapshot, tint: .indigo)
                                }
                            }
                            .font(.footnote)
                        }
                    }
                }
            }
        }
    }

    private func loadHistory() {
        do {
            sessions = try sessionService.fetchHistory(limit: 200)
        } catch {
            message = error.localizedDescription
        }
    }
}
