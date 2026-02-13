import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            TodayView()
                .tabItem {
                    Label("今日", systemImage: "sun.max")
                }
                .tag(RootTab.today)

            TodoListView()
                .tabItem {
                    Label("To-Do", systemImage: "list.bullet.rectangle")
                }
                .tag(RootTab.todo)

            FocusSessionView()
                .tabItem {
                    Label("专注中", systemImage: "target")
                }
                .tag(RootTab.focus)

            AnalyticsView()
                .tabItem {
                    Label("复盘", systemImage: "chart.xyaxis.line")
                }
                .tag(RootTab.analytics)
        }
        .alert(
            "提示",
            isPresented: Binding(
                get: { appState.sessionErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        appState.sessionErrorMessage = nil
                    }
                }
            )
        ) {
            Button("知道了", role: .cancel) {
                appState.sessionErrorMessage = nil
            }
        } message: {
            Text(appState.sessionErrorMessage ?? "")
        }
    }
}

