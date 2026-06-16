# Pomlist

Pomlist 是一个任务驱动的原生 SwiftUI 番茄钟与个人执行管理工具。它把一次专注定义为围绕一组明确任务推进到可复盘状态，而不是只等待倒计时结束。

首版聚焦本地优先体验：任务库、专注会话、任务快照、历史复盘与统计视图已经形成可运行闭环。打开 App 后直接进入主界面，数据保存在本机。

## 功能

- 本地任务库：新增、编辑、删除、完成、恢复、归档。
- 分类与标签复用维护，任务编辑时可快速选用。
- 专注会话：从任务库选择一个或多个任务开始。
- 同一时间只允许一个进行中的专注会话。
- 会话中可追加任务、逐项勾选完成、结束并生成快照。
- 历史视图按时间倒序展示会话时长、任务数、完成数、完成率与任务快照。
- 统计视图展示今日、近 7 天、近 30 天的专注次数、总时长、完成任务数、平均完成率、连续专注天数、分类贡献、时段分布和效率趋势。
- 使用系统导航、列表、表单、分段选择、仪表盘、空状态和 Apple Charts，界面遵循 iOS / iPadOS 原生组件行为。

## 技术栈

- SwiftUI
- Charts
- Foundation JSON 本地持久化
- iOS / iPadOS 17.0+

## 项目结构

```text
Pomlist
├── Pomlist.xcodeproj
├── Pomlist
│   ├── PomlistApp.swift
│   ├── Models
│   │   └── PomlistModels.swift
│   ├── Services
│   │   └── PomlistStore.swift
│   ├── Views
│   │   ├── TodayView.swift
│   │   ├── TasksView.swift
│   │   ├── HistoryView.swift
│   │   ├── StatsView.swift
│   │   ├── SettingsView.swift
│   │   └── PomlistSupport.swift
│   └── Resources
│       └── Assets.xcassets
└── README.md
```

`FocusSession` 会保存 `SessionTaskSnapshot`，历史记录不依赖后续任务编辑或删除。

## 快速开始

1. 使用 Xcode 打开工程：

```bash
open Pomlist.xcodeproj
```

2. 选择 `Pomlist` scheme。
3. 选择 iPhone 或 iPad Simulator。
4. 点击 Run。

命令行构建：

```bash
xcodebuild -project Pomlist.xcodeproj -scheme Pomlist -destination 'generic/platform=iOS Simulator' build
```

逻辑烟测：

```bash
swift Tests/PomlistLogicTests.swift
```

## 本地数据

数据保存在 App Sandbox 的 Application Support 目录：

```text
Application Support/Pomlist/pomlist-data.json
```

当前版本不包含云同步。恢复演示数据会覆盖本地任务、会话、分类和标签。

## 设计方向

界面采用 Apple 原生前端组件，优先使用系统导航、列表、表单、工具栏、仪表盘、空状态与图表。交互文案保持克制，让状态、图标、控件标签和系统行为承担主要表达。
