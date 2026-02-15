import SwiftData
import SwiftUI

@main
struct PomlistApp: App {
    private let container: ModelContainer = {
        let schema = Schema([
            PLTodo.self,
            PLFocusSession.self,
            PLSessionTaskRef.self,
            PLAuthConfig.self
        ])
        let configuration = ModelConfiguration("PomlistModel")

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("SwiftData 初始化失败: \(error.localizedDescription)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            PomlistRootView()
        }
        .modelContainer(container)
    }
}
