import SwiftUI

struct UnlockView: View {
    @State private var passcode: String = ""
    let errorMessage: String?
    let onUnlock: (String) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)

            VStack(spacing: 10) {
                Text("Pomlist")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("输入四位口令解锁")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            SecureField("四位口令", text: $passcode)
                .font(.system(size: 30, weight: .semibold, design: .monospaced))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.never)
                .keyboardType(.asciiCapable)
                .textContentType(.oneTimeCode)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemBackground))
                )
                .onChange(of: passcode) { _, newValue in
                    if newValue.count > 4 {
                        passcode = String(newValue.prefix(4))
                    }
                }

            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Button {
                let code = passcode
                passcode = ""
                onUnlock(code)
            } label: {
                Text("解锁")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(passcode.count != 4)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .background(Color(uiColor: .systemBackground))
    }
}

#Preview {
    UnlockView(errorMessage: "口令错误，请重试。") { _ in }
}
