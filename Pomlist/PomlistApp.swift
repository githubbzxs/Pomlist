import SwiftData
import SwiftUI

@main
struct PomlistApp: App {
    @StateObject private var appState = AppState()

    private let container: ModelContainer = {
        let schema = Schema([
            TodoItem.self,
            FocusSession.self,
            SessionTaskRef.self
        ])
        let configuration = ModelConfiguration(cloudKitDatabase: .automatic)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("模型容器初始化失败：\(error.localizedDescription)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appState)
                .task {
                    do {
                        if let session = try SessionService.restoreActiveSession(context: container.mainContext) {
                            appState.activeSessionID = session.id
                            appState.selectedTab = .focus
                        }
                    } catch {
                        appState.sessionErrorMessage = error.localizedDescription
                    }
                }
        }
        .modelContainer(container)
    }
}
