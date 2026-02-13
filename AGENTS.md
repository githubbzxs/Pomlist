# 项目记忆（Pomlist）

## Facts

- **[2026-02-13] 产品定位**：Pomlist 是一个 iOS 学生场景效率应用，核心是“任务驱动番茄钟”，不是倒计时驱动。
- **[2026-02-13] 首发范围**：仅 iPhone 竖屏，首版不做 Apple Watch、不做推送提醒、不做自建账号体系。

## Decisions

- **[2026-02-13] 任务钟结束规则**：支持选择性完成，允许如 `8/10` 手动收钟。
  - Why：更贴合真实学习过程，避免“必须全做完才能记录”带来的挫败。
  - Impact：`FocusSession` 需要记录 `completedTaskCount`、`totalTaskCount`、`elapsedSeconds`。
- **[2026-02-13] 时间机制**：采用软计时，只做记录与复盘，不参与结束判定。
  - Why：保持产品差异化核心，同时保留效率分析价值。
  - Impact：专注页展示已用时，统计页使用时长聚合。
- **[2026-02-13] 数据同步策略**：SwiftData + CloudKit 自动同步。
  - Why：保持原生体验，避免自建后端复杂度。
  - Impact：模型配置必须启用 CloudKit，冲突以时间戳与结束态优先。

## Commands

- **[2026-02-13] 生成工程**：使用 `xcodegen generate`。
- **[2026-02-13] 运行测试**：使用 `xcodebuild test -scheme Pomlist -destination "platform=iOS Simulator,name=iPhone 15"`。

## Status / Next

- **[2026-02-13] 当前状态**：首版功能已落地（To-Do、任务钟、手动收钟、复盘统计、测试骨架）。
- **[2026-02-13] 下一步**：在 macOS 环境执行 `xcodegen` 与 `xcodebuild test`，完成真机/模拟器回归并补齐 AppIcon 图像资源。

## Known Issues

- **[2026-02-13] 当前环境限制**：Windows 终端无法直接执行 Xcode/iOS 模拟器验证。
  - Verify：需在 macOS + Xcode 环境运行 `xcodegen` 与 `xcodebuild test` 进行最终校验。
