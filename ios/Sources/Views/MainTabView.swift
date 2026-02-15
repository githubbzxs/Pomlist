import SwiftUI

struct MainTabView: View {
    @ObservedObject var serviceHub: PLServiceHub

    var body: some View {
        if let sessionService = serviceHub.sessionService,
           let todoService = serviceHub.todoService,
           let analyticsService = serviceHub.analyticsService
        {
            TabView {
                FocusView(sessionService: sessionService)
                    .tabItem {
                        Label("Focus", systemImage: "timer")
                    }

                TasksView(todoService: todoService)
                    .tabItem {
                        Label("Tasks", systemImage: "checklist")
                    }

                HistoryView(sessionService: sessionService)
                    .tabItem {
                        Label("History", systemImage: "clock.arrow.circlepath")
                    }

                StatsView(analyticsService: analyticsService)
                    .tabItem {
                        Label("Stats", systemImage: "chart.xyaxis.line")
                    }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("锁定") {
                        serviceHub.lock()
                    }
                }
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text("服务初始化失败")
                    .font(.headline)
                Text("请重新启动应用。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
        }
    }
}
