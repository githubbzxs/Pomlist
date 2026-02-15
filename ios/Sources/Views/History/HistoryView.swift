import SwiftUI

struct HistoryView: View {
    @ObservedObject var serviceHub: PLServiceHub

    @State private var sessions: [PLFocusSession] = []
    @State private var message: String?

    var body: some View {
        NavigationStack {
            List {
                if sessions.isEmpty {
                    Text("暂无历史记录")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sessions, id: \.id) { session in
                        NavigationLink {
                            SessionDetailView(session: session)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(PLFormatters.shortDateTime(session.endedAt))
                                    Spacer()
                                    Text("\(session.completedTaskCount)/\(session.totalTaskCount)")
                                        .fontWeight(.semibold)
                                }
                                .font(.subheadline)

                                Text("用时 \(PLFormatters.minuteText(seconds: session.elapsedSeconds)) · 完成率 \(PLFormatters.rateText(session.completionRate))")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("历史")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("刷新") { reload() }
                }
            }
            .onAppear(perform: reload)
            .alert("提示", isPresented: .constant(message != nil), presenting: message) { _ in
                Button("知道了") { message = nil }
            } message: { text in
                Text(text)
            }
        }
    }

    private func reload() {
        do {
            sessions = try serviceHub.sessionService?.history(limit: 120) ?? []
        } catch {
            message = error.localizedDescription
        }
    }
}

private struct SessionDetailView: View {
    let session: PLFocusSession

    var body: some View {
        List {
            Section("会话信息") {
                row("开始", PLFormatters.shortDateTime(session.startedAt))
                row("结束", PLFormatters.shortDateTime(session.endedAt))
                row("用时", PLFormatters.minuteText(seconds: session.elapsedSeconds))
                row("完成率", PLFormatters.rateText(session.completionRate))
            }

            Section("任务快照") {
                ForEach(session.taskRefs.sorted(by: { $0.orderIndex < $1.orderIndex }), id: \.id) { ref in
                    HStack {
                        Image(systemName: ref.isCompletedInSession ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(ref.isCompletedInSession ? .green : .secondary)
                        Text(ref.titleSnapshot)
                    }
                }
            }
        }
        .navigationTitle("会话详情")
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
