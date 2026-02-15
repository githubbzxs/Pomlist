# Pomlist iOS

`ios/` 目录是 Pomlist 的原生 iOS 工程源码（SwiftUI + SwiftData，最低 iOS 17）。

## 本地开发

1. 安装 XcodeGen：

```bash
brew install xcodegen
```

2. 生成 Xcode 工程：

```bash
cd ios
xcodegen generate
```

3. 打开工程：

```bash
open PomlistIOS.xcodeproj
```

## 功能结构

- `Unlock`：生物识别优先，口令兜底（默认口令 `0xbp`）。
- `Focus`：任务驱动专注，手动结束并记录 `n/x`。
- `Tasks`：任务新增、编辑、完成/恢复、删除。
- `History`：完成会话历史明细。
- `Stats`：今日/7天/30天与类别、时段分布。

## 迁移导入

App 支持导入 `PomlistMigrationV1` JSON。
导出脚本和流程见仓库根目录文档：

- `docs/migration-export.md`
- `tools/migration/export-pomlist-migration-v1.mjs`

## CI 构建

GitHub Actions 工作流：

- `.github/workflows/ios-unsigned-ipa.yml`

该流程会在 macOS runner 上生成未签名 IPA Artifact，供本地安装链路使用。
