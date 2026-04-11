# Pomlist

当前仓库已经进一步清空，所有 Swift 项目代码与测试代码均已删除，不再保留任何项目实现骨架。

## 当前状态

- 已删除全部应用代码。
- 已删除全部测试代码。
- 已删除上一步保留的最小 SwiftUI 占位壳。
- 仅保留 README 与 IPA 打包相关文件，方便后续由别的 AI 重建。

## 当前保留内容

- `README.md`
  - 当前唯一说明文件，用于告诉下一位 AI 现在仓库的状态与接手方式。
- `project.yml`
  - 原有 XcodeGen 工程描述文件，作为 IPA 链路的一部分保留。
- `Pomlist/Info.plist`
  - 原有 iOS 配置文件，作为打包相关文件保留。
- `Pomlist/Resources/*`
  - 原有资源目录，作为打包相关文件保留。
- `.github/workflows/*`
  - GitHub Actions 的构建、无签名 IPA、签名 IPA 工作流。
- `docs/download/*`
  - GitHub Pages 下载页模板，供 IPA 发布页继续使用。

## 已清除内容

- 所有 Swift 业务代码。
- 所有 SwiftUI 页面与入口代码。
- 所有测试代码。
- 所有之前留下的占位实现。

## 给下一位 AI 的接手建议

建议按下面顺序重建：

1. 先改 `README.md`，把新的产品定义写清楚。
2. 再决定是否继续沿用 `project.yml`、`Info.plist`、资源目录和现有工作流。
3. 然后重新创建新的应用目录、源码目录和测试目录。
4. 如果要继续做 IPA 导出与下载页发布，可以直接沿用 `.github/workflows/` 与 `docs/download/`。

## 仍可沿用的常用命令

```bash
brew install xcodegen
xcodegen generate
xcodebuild test -project Pomlist.xcodeproj -scheme Pomlist -destination 'platform=iOS Simulator,OS=latest,name=iPhone 16'
xcodebuild archive -project Pomlist.xcodeproj -scheme Pomlist -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```

## 说明

现在仓库里已经没有任何项目实现代码，只剩说明文件和 IPA 相关链路文件。这样你交给别的 AI 时，它会在几乎空白的状态下重写，但仍能参考原来的打包与发布路径。
