# GitHub Actions 未签名 IPA 构建

本文档说明如何在 GitHub Actions 的 macOS Runner 上构建未签名 IPA，并上传为 artifact。

## Workflow 文件

- 路径：`.github/workflows/ios-unsigned-ipa.yml`
- 名称：`iOS Unsigned IPA`

## 触发方式

- 手动触发：`workflow_dispatch`
- 自动触发：`push` 到 `main` 且命中路径
  - `ios/**`
  - `.github/workflows/ios-unsigned-ipa.yml`

## 手动触发参数

- `workspace_path`：可选，指定 `.xcworkspace`（优先）
- `project_path`：可选，指定 `.xcodeproj`
- `scheme`：可选，不填则自动取第一个 Scheme
- `configuration`：可选，`Release` 或 `Debug`（默认 `Release`）

## 构建流程

1. 自动探测 workspace/project 与 scheme（支持手动覆盖）
2. 执行 `xcodebuild`，关闭签名：
   - `CODE_SIGNING_ALLOWED=NO`
   - `CODE_SIGNING_REQUIRED=NO`
   - `CODE_SIGN_IDENTITY=""`
3. 产出 `Release-iphoneos`（或指定配置）的 `.app`
4. 组装 `Payload/*.app` 并打包为 `.ipa`
5. 上传 artifact：`unsigned-ipa-<scheme>`

## 下载产物

在对应 workflow run 的 `Artifacts` 中下载：

- 文件名：`<scheme>-unsigned.ipa`

## 注意事项

- 该 IPA 未签名，只用于迁移验证、包结构检查和内部流程联调
- 不能直接用于 App Store 分发
- 若仓库存在多个工程，建议手动传入 `workspace_path/project_path/scheme`，避免误选
