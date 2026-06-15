import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: PomlistStore

    var body: some View {
        ZStack {
            PomlistTheme.background.ignoresSafeArea()
            if store.isUnlocked {
                MainTabView()
                    .transition(.asymmetric(insertion: .scale(scale: 0.98).combined(with: .opacity), removal: .opacity))
            } else {
                LoginView()
                    .transition(.asymmetric(insertion: .opacity, removal: .scale(scale: 1.02).combined(with: .opacity)))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.86), value: store.isUnlocked)
    }
}
