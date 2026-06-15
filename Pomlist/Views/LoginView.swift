import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var store: PomlistStore
    @State private var passcode = ""
    @State private var shake = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer(minLength: 30)
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(PomlistTheme.accent.opacity(0.14))
                        .frame(width: 118, height: 118)
                        .blur(radius: 4)
                    Image(systemName: "timer.circle.fill")
                        .font(.system(size: 72, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(PomlistTheme.accent)
                }
                VStack(spacing: 10) {
                    Text("Pomlist")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(PomlistTheme.text)
                    Text("任务驱动的专注工作台")
                        .font(.system(.headline, design: .rounded, weight: .medium))
                        .foregroundStyle(PomlistTheme.secondaryText)
                }
            }

            VStack(spacing: 20) {
                HStack(spacing: 14) {
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(index < passcode.count ? PomlistTheme.accent : Color.white.opacity(0.12))
                            .frame(width: 16, height: 16)
                            .overlay {
                                Circle()
                                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
                            }
                            .scaleEffect(index < passcode.count ? 1.12 : 1)
                            .animation(.spring(response: 0.26, dampingFraction: 0.62), value: passcode.count)
                    }
                }
                .offset(x: shake ? -8 : 0)
                .animation(.linear(duration: 0.06).repeatCount(5, autoreverses: true), value: shake)

                SecureField("4 位口令", text: $passcode)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(PomlistTheme.text)
                    .focused($focused)
                    .padding(.vertical, 14)
                    .background(PomlistTheme.panelStrong, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(focused ? PomlistTheme.accent.opacity(0.55) : PomlistTheme.stroke, lineWidth: 1)
                    }
                    .onChange(of: passcode) { _, newValue in
                        passcode = String(newValue.filter(\.isNumber).prefix(4))
                        if passcode.count == 4 {
                            submit()
                        }
                    }

                if let error = store.lastError {
                    Text(error)
                        .font(.system(.footnote, design: .rounded, weight: .medium))
                        .foregroundStyle(PomlistTheme.rose)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Button("解锁") {
                    submit()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(passcode.count != 4)
                .opacity(passcode.count == 4 ? 1 : 0.48)
            }
            .padding(24)
            .glassPanel(cornerRadius: 30, opacity: 0.72)

            Text("初始口令 0000")
                .font(.system(.footnote, design: .rounded, weight: .medium))
                .foregroundStyle(PomlistTheme.mutedText)

            Spacer(minLength: 20)
        }
        .padding(24)
        .onAppear {
            focused = true
        }
    }

    private func submit() {
        guard passcode.count == 4 else { return }
        if store.unlock(passcode: passcode) {
            passcode = ""
        } else {
            passcode = ""
            shake.toggle()
        }
    }
}
