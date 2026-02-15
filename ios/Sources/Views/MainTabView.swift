import SwiftUI

struct MainTabView: View {
    @ObservedObject var serviceHub: PLServiceHub

    var body: some View {
        TabView {
            FocusView(serviceHub: serviceHub)
                .tabItem {
                    Label("专注", systemImage: "timer")
                }

            TasksView(serviceHub: serviceHub)
                .tabItem {
                    Label("任务", systemImage: "checklist")
                }

            HistoryView(serviceHub: serviceHub)
                .tabItem {
                    Label("历史", systemImage: "clock.arrow.circlepath")
                }

            StatsView(serviceHub: serviceHub)
                .tabItem {
                    Label("统计", systemImage: "chart.bar")
                }
        }
        .tint(.blue)
    }
}
