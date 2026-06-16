import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: PomlistStore

    var body: some View {
        NavigationStack {
            List {
                if store.endedSessions.isEmpty {
                    ContentUnavailableTaskView(
                        systemImage: "clock",
                        title: "暂无记录",
                        message: "结束一轮专注后会生成复盘快照。"
                    )
                } else {
                    ForEach(store.endedSessions) { session in
                        HistorySessionRow(session: session)
                    }
                }
            }
            .navigationTitle("历史")
        }
    }
}

private struct HistorySessionRow: View {
    var session: FocusSession

    var body: some View {
        DisclosureGroup {
            ForEach(session.tasks.sorted { $0.orderIndex < $1.orderIndex }) { snapshot in
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(snapshot.titleSnapshot)
                        Text(snapshot.categorySnapshot)
                            .font(.footnote)
                            .foregroundStyle(PomlistStyle.categoryColor(snapshot.categorySnapshot))
                    }
                } icon: {
                    Image(systemName: snapshot.isCompletedInSession ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(snapshot.isCompletedInSession ? Color.accentColor : Color.secondary)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(PomlistFormatters.dayTime.string(from: session.startedAt))
                Text("\(PomlistFormatters.duration(session.elapsedSeconds)) · \(session.completedTaskCount)/\(session.totalTaskCount) · \(PomlistFormatters.percent(session.completionRate))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
