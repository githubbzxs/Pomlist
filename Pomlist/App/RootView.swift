import SwiftUI

struct RootView: View {
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Pomlist")
                    .font(.system(size: 34, weight: .bold, design: .rounded))

                Text("项目主体代码已清空，这里只保留一个可编译的 iOS 占位壳。")
                    .font(.headline)

                Text("当前仓库保留了 XcodeGen 工程描述、GitHub Actions IPA 打包流程、基础资源目录和下载页模板，方便后续由别的 AI 在这个骨架上重写。")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 10) {
                    Label("保留 iOS / IPA 打包相关文件", systemImage: "shippingbox")
                    Label("保留最小 SwiftUI 入口", systemImage: "swift")
                    Label("保留最小测试目标", systemImage: "checkmark.seal")
                }
                .font(.subheadline)

                Spacer()

                Text("详细交接说明见仓库根目录 README.md")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(uiColor: .systemBackground))
        }
    }
}
