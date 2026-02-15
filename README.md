# Pomlist iOS

Pomlist 已完成从 Web 到 iOS 的重构，当前仓库主线是原生 iOS App。

- 技术栈：SwiftUI + SwiftData（iOS 18+）
- 鉴权：Face ID / Touch ID + 4 位口令兜底
- 数据迁移：支持导入 `PomlistMigrationV1`
- 构建：GitHub Actions 产出未签名 IPA

## 目录

- `ios/`：iOS 源码与 XcodeGen 配置
- `tools/migration/`：旧 JSON -> `PomlistMigrationV1` 导出脚本
- `docs/`：迁移与 CI 说明

## 本地开发（iOS）

```bash
brew install xcodegen
cd ios
xcodegen generate
open PomlistIOS.xcodeproj
```

## 导出迁移文件

```bash
node tools/migration/export-pomlist-migration-v1.mjs \
  --input data/pomlist-db.json
```

详细见：`docs/migration-export.md`

## GitHub Actions 未签名 IPA

工作流：`.github/workflows/ios-unsigned-ipa.yml`

详细见：`docs/ios-unsigned-ipa.md`
