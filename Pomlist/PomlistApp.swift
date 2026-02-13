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
        // 首版默认仅使用本地存储，避免真机自签阶段受 CloudKit 能力限制。
        let configuration = ModelConfiguration()
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
