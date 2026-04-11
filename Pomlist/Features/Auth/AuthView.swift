import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var store: PomlistStore
    @State private var passcode = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 80)

                GlassCluster(spacing: 18) {
                    GlassPill(title: "Liquid Glass", systemImage: "sparkles", tint: PomlistPalette.accent)

                    SectionTitle(
                        eyebrow: "Pomlist",
                        title: "像苹果原生应用一样开始今天。",
                        subtitle: "输入 4 位口令进入任务、任务钟、历史与统计。默认口令是 0xbp。"
                    )

                    GlassCard {
                        VStack(spacing: 18) {
                            SecureField("4 位口令", text: $passcode)
                                .keyboardType(.asciiCapable)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.system(size: 30, weight: .semibold, design: .rounded))
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 6)

                            Button("进入 Pomlist") {
                                store.signIn(passcode: passcode)
                                passcode = ""
                            }
                            .buttonStyle(PrimaryGlassButtonStyle())
                        }
                    }

                    GlassCard(tint: Color.white.opacity(0.18), cornerRadius: 26) {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Today：开始 / 结束 / 追加任务钟", systemImage: "timer")
                            Label("Task：管理任务、分类、标签与具体内容", systemImage: "checklist")
                            Label("History / Stats：历史记录与复盘分析", systemImage: "chart.line.text.clipboard")
                        }
                        .font(.subheadline)
                        .foregroundStyle(PomlistPalette.secondaryInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 40)
            }
        }
        .scrollIndicators(.hidden)
    }
}
