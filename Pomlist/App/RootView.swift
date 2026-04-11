import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: PomlistStore

    var body: some View {
        ZStack {
            PomlistBackground()

            if store.isBootstrapping {
                ProgressView("正在载入 Pomlist")
                    .font(.headline)
                    .foregroundStyle(PomlistPalette.ink)
            } else if store.isAuthenticated {
                MainTabView()
            } else {
                AuthView()
            }
        }
        .tint(PomlistPalette.accent)
        .alert("提示", isPresented: Binding(
            get: { store.errorMessage != nil || store.infoMessage != nil },
            set: { newValue in
                if !newValue {
                    store.dismissMessage()
                }
            }
        )) {
            Button("知道了") {
                store.dismissMessage()
            }
        } message: {
            Text(store.errorMessage ?? store.infoMessage ?? "")
        }
    }
}
