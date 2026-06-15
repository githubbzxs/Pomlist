import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: PomlistStore

    var body: some View {
        NavigationStack {
            ZStack {
                PomlistTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        ScreenHeader(title: "历史", subtitle: "\(store.endedSessions.count) 次已结束专注", systemImage: "clock.arrow.circlepath")

                        if store.endedSessions.isEmpty {
                            EmptyStateView(systemImage: "clock", title: "暂无记录", message: "结束一轮专注后会生成复盘快照。")
                        } else {
                            LazyVStack(spacing: 14) {
                                ForEach(store.endedSessions) { session in
                                    HistorySessionCard(session: session)
                                }
                            }
                        }
                    }
                    .pomlistScreenPadding()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct HistorySessionCard: View {
    var session: FocusSession
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    expanded.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(PomlistFormatters.dayTime.string(from: session.startedAt))
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(PomlistTheme.text)
                        Text("\(PomlistFormatters.duration(session.elapsedSeconds)) · \(session.completedTaskCount)/\(session.totalTaskCount) · \(PomlistFormatters.percent(session.completionRate))")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(PomlistTheme.secondaryText)
                    }
                    Spacer()
                    CompletionRing(progress: session.completionRate, size: 52, lineWidth: 7)
                }
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(spacing: 10) {
                    ForEach(session.tasks.sorted { $0.orderIndex < $1.orderIndex }) { snapshot in
                        HStack(spacing: 10) {
                            Image(systemName: snapshot.isCompletedInSession ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(snapshot.isCompletedInSession ? PomlistTheme.accent : PomlistTheme.secondaryText)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(snapshot.titleSnapshot)
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                    .foregroundStyle(PomlistTheme.text)
                                Text(snapshot.categorySnapshot)
                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                    .foregroundStyle(PomlistTheme.categoryColor(snapshot.categorySnapshot))
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(17)
        .glassPanel(cornerRadius: 23, opacity: 0.78)
    }
}

struct CompletionRing: View {
    var progress: Double
    var size: CGFloat
    var lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(PomlistTheme.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: progress)
            Text(PomlistFormatters.percent(progress))
                .font(.system(size: max(10, size * 0.22), weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(PomlistTheme.text)
        }
        .frame(width: size, height: size)
    }
}
