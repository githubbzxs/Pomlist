import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: PomlistStore
    @State private var currentPasscode = ""
    @State private var newPasscode = ""
    @State private var message: String?
    @State private var showResetAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                PomlistTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        ScreenHeader(title: "设置", subtitle: "口令与本地数据", systemImage: "gearshape")

                        VStack(alignment: .leading, spacing: 14) {
                            Text("修改口令")
                                .font(.system(.title3, design: .rounded, weight: .bold))
                                .foregroundStyle(PomlistTheme.text)
                            SecureField("当前口令", text: $currentPasscode)
                                .keyboardType(.numberPad)
                                .textContentType(.oneTimeCode)
                                .modifier(SettingsFieldStyle())
                                .onChange(of: currentPasscode) { _, value in
                                    currentPasscode = String(value.filter(\.isNumber).prefix(4))
                                }
                            SecureField("新口令", text: $newPasscode)
                                .keyboardType(.numberPad)
                                .textContentType(.oneTimeCode)
                                .modifier(SettingsFieldStyle())
                                .onChange(of: newPasscode) { _, value in
                                    newPasscode = String(value.filter(\.isNumber).prefix(4))
                                }
                            Button("保存更改") {
                                changePasscode()
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(currentPasscode.count != 4 || newPasscode.count != 4)
                            .opacity(currentPasscode.count == 4 && newPasscode.count == 4 ? 1 : 0.48)
                            if let message {
                                Text(message)
                                    .font(.system(.footnote, design: .rounded, weight: .medium))
                                    .foregroundStyle(message.contains("已") ? PomlistTheme.accent : PomlistTheme.rose)
                            }
                        }
                        .padding(18)
                        .glassPanel(cornerRadius: 23, opacity: 0.78)

                        VStack(spacing: 12) {
                            Button {
                                store.lock()
                            } label: {
                                HStack {
                                    Image(systemName: "lock.fill")
                                    Text("退出登录")
                                }
                            }
                            .buttonStyle(SecondaryButtonStyle())

                            Button {
                                showResetAlert = true
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("恢复演示数据")
                                }
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                    }
                    .pomlistScreenPadding()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .alert("恢复演示数据", isPresented: $showResetAlert) {
            Button("取消", role: .cancel) {}
            Button("恢复", role: .destructive) {
                store.resetDemoData()
            }
        } message: {
            Text("当前本地数据会被替换。")
        }
    }

    private func changePasscode() {
        if store.changePasscode(current: currentPasscode, newPasscode: newPasscode) {
            currentPasscode = ""
            newPasscode = ""
            message = "口令已更新"
        } else {
            message = store.lastError
        }
    }
}

private struct SettingsFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .foregroundStyle(PomlistTheme.text)
            .padding(14)
            .background(PomlistTheme.panelStrong, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(PomlistTheme.stroke, lineWidth: 1)
            }
    }
}
