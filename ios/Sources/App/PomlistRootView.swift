import SwiftData
import SwiftUI

struct PomlistRootView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var serviceHub = PLServiceHub()

    var body: some View {
        Group {
            if !serviceHub.isReady {
                ProgressView("正在初始化")
                    .task {
                        serviceHub.configure(with: modelContext)
                        await serviceHub.attemptBiometricUnlockIfEnabled()
                    }
            } else if !serviceHub.isUnlocked {
                UnlockView(
                    errorMessage: serviceHub.unlockError,
                    biometricEnabled: serviceHub.isBiometricAvailable,
                    onUnlock: { passcode in
                        serviceHub.unlock(passcode: passcode)
                    },
                    onBiometricUnlock: {
                        _ = try? await serviceHub.attemptBiometricUnlock()
                    }
                )
            } else {
                TodayCanvasView(serviceHub: serviceHub)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.88), value: serviceHub.isUnlocked)
    }
}

#Preview {
    PomlistRootView()
        .modelContainer(for: [PLTodo.self, PLFocusSession.self, PLSessionTaskRef.self, PLAuthConfig.self], inMemory: true)
}
