# Pomlist

当前仓库已经按“重写前清场”处理过，旧业务实现已移除，只保留给下一位 AI 继续接手所需的最小 iOS / IPA 打包骨架。

## 当前状态

- 已删除原有任务、统计、历史、存储等业务代码。
- 已删除当前业务测试，只保留一个最小测试占位。
- 已保留 iOS 工程最小入口，仓库不会变成完全空目录。
- 已保留 IPA 打包相关链路，方便后续继续生成工程、构建、归档、导出 IPA。

## 当前保留内容

- `project.yml`
  - XcodeGen 工程描述，下一位 AI 可以直接继续扩展 targets、sources、capabilities。
- `Pomlist/App/*`
  - 最小 `SwiftUI` 占位入口，只用于保证工程骨架存在。
- `Pomlist/Info.plist`
  - iOS 应用基础配置。
- `Pomlist/Resources/*`
  - 资源目录、AppIcon、预览资源骨架。
- `PomlistTests/*`
  - 最小测试目标占位，方便 CI 与工程结构继续沿用。
- `.github/workflows/*`
  - GitHub Actions 的构建、无签名 IPA、签名 IPA 工作流。
- `docs/download/*`
  - GitHub Pages 下载页模板，供 IPA 发布页继续使用。

## 已清除内容

- 所有原有业务模块与页面实现。
- 原有任务模型、统计逻辑、本地存储逻辑。
- 原有共享弹层、历史页、设置页、任务页等具体功能代码。

## 给下一位 AI 的接手建议

建议从下面几个入口开始重写：

1. 先改 `README.md`，把新的产品定义写清楚。
2. 再改 `project.yml`，决定是否继续沿用当前 target 结构。
3. 然后从 `Pomlist/App/RootView.swift` 开始重建首页和导航。
4. 如果要扩展打包或下载分发，继续沿用 `.github/workflows/` 与 `docs/download/`。

## 仍可沿用的常用命令

```bash
brew install xcodegen
xcodegen generate
xcodebuild test -project Pomlist.xcodeproj -scheme Pomlist -destination 'platform=iOS Simulator,OS=latest,name=iPhone 16'
xcodebuild archive -project Pomlist.xcodeproj -scheme Pomlist -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```

## 说明

这次不是单纯把所有文件删空，而是刻意保留了“可继续打包 IPA 的最小骨架”。这样你把仓库交给别的 AI 时，它既不会被旧业务代码污染，也不需要从零重建打包链路。
