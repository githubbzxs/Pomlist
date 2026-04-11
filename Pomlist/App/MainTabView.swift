import SwiftUI

struct MainTabView: View {
    @State private var settingsPresented = false

    var body: some View {
        TabView {
            TodayView(settingsPresented: $settingsPresented)
                .tabItem {
                    Label("Today", systemImage: "timer")
                }

            TasksView()
                .tabItem {
                    Label("Task", systemImage: "checklist")
                }

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }

            StatsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.xyaxis.line")
                }
        }
        .sheet(isPresented: $settingsPresented) {
            SettingsSheet()
        }
    }
}
