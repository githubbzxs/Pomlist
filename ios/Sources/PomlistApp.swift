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

        do {
            return try ModelContainer(for: schema)
        } catch {
            fatalError("SwiftData initialization failed: \(error.localizedDescription)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            PomlistRootView()
                .modelContainer(container)
        }
    }
}
