# GitHub Actions 生成未签名 IPA

## 工作流

- 文件：`.github/workflows/ios-unsigned-ipa.yml`
- 触发：
  - 推送 `main` 且涉及 `ios/**`
  - 手动 `workflow_dispatch`

## 流程

1. `brew install xcodegen`
2. `cd ios && xcodegen generate`
3. `xcodebuild archive ... CODE_SIGNING_ALLOWED=NO`
4. 将 `.app` 打包为 `Pomlist-unsigned.ipa`
5. 上传 Artifact：`pomlist-ios-unsigned-ipa`

## 说明

该 IPA 为未签名包，仅用于你当前本地安装链路。CI 不负责证书签名。
