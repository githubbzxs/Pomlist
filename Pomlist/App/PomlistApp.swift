import SwiftUI

@main
struct PomlistApp: App {
    @StateObject private var store = PomlistStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .task {
                    store.loadIfNeeded()
                }
        }
    }
}
