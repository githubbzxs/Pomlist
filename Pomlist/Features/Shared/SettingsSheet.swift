import SwiftUI

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PomlistStore

    @State private var oldPasscode = ""
    @State private var newPasscode = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("安全") {
                    SecureField("旧口令", text: $oldPasscode)
                        .keyboardType(.asciiCapable)

                    SecureField("新口令（4 位）", text: $newPasscode)
                        .keyboardType(.asciiCapable)

                    Button("更新口令") {
                        store.changePasscode(oldPasscode: oldPasscode, newPasscode: newPasscode)
                        oldPasscode = ""
                        newPasscode = ""
                    }
                    .buttonStyle(.borderedProminent)
                }

                Section("账号") {
                    Button("退出登录", role: .destructive) {
                        store.signOut()
                        dismiss()
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
