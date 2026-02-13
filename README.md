# Pomlist

Pomlist 是一个 iOS 学习效率应用，把 To-Do List 与“任务驱动番茄钟”融合到同一套流程中：

- 一个钟不再由倒计时结束，而是由任务完成进度结束。
- 例如创建一个包含 10 个任务的钟，完成 8 个后手动结束，记录为 `8/10`。
- 应用会保留软计时数据，用于复盘，不强制计时结束。

## 核心特性

- 统一 To-Do 任务池：新增、编辑、完成、恢复。
- 任务钟：从 To-Do 勾选任务后开启，专注中逐项完成。
- 手动收钟：支持未满完成结束，保留完成比与时长。
- 数据回写：完成任务自动标记完成，未完成任务保留待办。
- 完整复盘：今日指标、7 天趋势、时长分布、连续专注天数。
- 本地存储 + iCloud 同步（CloudKit）。

## 技术栈

- SwiftUI
- SwiftData
- CloudKit（通过 SwiftData CloudKit 配置）
- Charts
- XCTest

## 本地运行

1. 安装 Xcode 与 XcodeGen。
2. 在仓库根目录生成工程：
   ```bash
   xcodegen generate
   ```
3. 打开 `Pomlist.xcodeproj`，选择 iPhone 模拟器运行。
4. 执行测试：
   ```bash
   xcodebuild test -scheme Pomlist -destination "platform=iOS Simulator,name=iPhone 15"
   ```

## 产品规则（首版）

- 仅支持 iPhone 竖屏。
- 同一时刻只能有一个进行中的任务钟。
- 任务钟仅支持手动结束并记录。
- 不做通知提醒，用户手动开启使用。
- 统计默认按本地时区自然日聚合。

