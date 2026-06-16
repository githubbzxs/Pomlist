import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: PomlistStore
    @State private var showResetAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section("本地数据") {
                    LabeledContent("任务", value: "\(store.data.tasks.count)")
                    LabeledContent("专注记录", value: "\(store.endedSessions.count)")

                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        Label("恢复演示数据", systemImage: "arrow.counterclockwise")
                    }
                }

                Section("应用") {
                    LabeledContent("名称", value: "Pomlist")
                    LabeledContent("数据位置", value: "本机")
                }
            }
            .navigationTitle("设置")
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
}
