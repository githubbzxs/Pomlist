import SwiftUI

struct UnlockView: View {
    let errorMessage: String?
    let biometricEnabled: Bool
    let onUnlock: (String) -> Void
    let onBiometricUnlock: () async -> Void

    @State private var passcode = ""

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.03, blue: 0.05),
                    Color(red: 0.04, green: 0.06, blue: 0.1),
                    Color(red: 0.03, green: 0.04, blue: 0.08),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer(minLength: 20)

                Text("Pomlist")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("输入四位口令解锁")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                SecureField("口令", text: $passcode)
                    .textContentType(.password)
                    .keyboardType(.asciiCapable)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit(submit)
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.24), lineWidth: 1)
                    }

                Button("解锁", action: submit)
                    .buttonStyle(PLPrimaryGlassButtonStyle())
                    .disabled(passcode.count != 4)

                if biometricEnabled {
                    Button("使用 Face ID / Touch ID") {
                        Task {
                            await onBiometricUnlock()
                        }
                    }
                    .buttonStyle(PLSecondaryGlassButtonStyle())
                }

                if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red.opacity(0.9))
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding(20)
            .frame(maxWidth: 420)
            .plLiquidGlassCard(cornerRadius: 28, borderOpacity: 0.28, highlightOpacity: 0.2, shadowOpacity: 0.32)
            .padding(.horizontal, 20)
        }
    }

    private func submit() {
        guard passcode.count == 4 else { return }
        onUnlock(passcode)
    }
}
