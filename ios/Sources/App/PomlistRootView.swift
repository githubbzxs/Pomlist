import SwiftData
import SwiftUI

struct PomlistRootView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var serviceHub = PLServiceHub()

    var body: some View {
        Group {
            if !serviceHub.isReady {
                ProgressView("正在初始化数据")
                    .task {
                        serviceHub.configure(with: modelContext)
                    }
            } else if !serviceHub.isUnlocked {
                UnlockView(errorMessage: serviceHub.unlockError) { passcode in
                    serviceHub.unlock(passcode: passcode)
                }
            } else {
                MainTabView(serviceHub: serviceHub)
            }
        }
    }
}

#Preview {
    PomlistRootView()
        .modelContainer(for: [PLTodo.self, PLFocusSession.self, PLSessionTaskRef.self, PLAuthConfig.self], inMemory: true)
}
