import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var store: PomlistStore

    var body: some View {
        TabView(selection: $store.selectedTab) {
            TodayView()
                .tabItem {
                    Label(AppTab.today.title, systemImage: AppTab.today.systemImage)
                }
                .tag(AppTab.today)

            TasksView()
                .tabItem {
                    Label(AppTab.tasks.title, systemImage: AppTab.tasks.systemImage)
                }
                .tag(AppTab.tasks)

            HistoryView()
                .tabItem {
                    Label(AppTab.history.title, systemImage: AppTab.history.systemImage)
                }
                .tag(AppTab.history)

            StatsView()
                .tabItem {
                    Label(AppTab.stats.title, systemImage: AppTab.stats.systemImage)
                }
                .tag(AppTab.stats)

            SettingsView()
                .tabItem {
                    Label(AppTab.settings.title, systemImage: AppTab.settings.systemImage)
                }
                .tag(AppTab.settings)
        }
        .tint(PomlistTheme.accent)
    }
}
