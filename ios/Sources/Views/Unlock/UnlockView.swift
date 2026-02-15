import SwiftUI

struct UnlockView: View {
    let errorMessage: String?
    let biometricEnabled: Bool
    let onUnlock: (String) -> Void
    let onBiometricUnlock: () async -> Void

    @State private var passcode = ""

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 20)

            Text("Pomlist")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("输入四位口令解锁")
                .foregroundStyle(.secondary)

            SecureField("口令", text: $passcode)
                .textContentType(.password)
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit(submit)
                .padding(12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button("解锁", action: submit)
                .buttonStyle(.borderedProminent)
                .disabled(passcode.count != 4)

            if biometricEnabled {
                Button("使用 Face ID / Touch ID") {
                    Task {
                        await onBiometricUnlock()
                    }
                }
                .buttonStyle(.bordered)
            }

            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(20)
    }

    private func submit() {
        guard passcode.count == 4 else { return }
        onUnlock(passcode)
    }
}
