<div align="center">

# Pomlist

<p><strong>任务驱动番茄钟的 iOS 原生重构版：SwiftUI + Liquid Glass + 本地持久化</strong></p>

<p>
  Pomlist 已从原先的 Next.js Web 应用重构为 iPhone / iPad 原生 App。它把 4 位口令登录、任务库、单活跃任务钟、历史记录、复盘统计和设置能力收进一套更接近苹果系统应用的交互里，并优先采用 Liquid Glass 视觉语言。
</p>

<p>
  <img src="https://img.shields.io/badge/Swift-6-FA7343?style=flat&logo=swift&logoColor=white" alt="Swift 6" />
  <img src="https://img.shields.io/badge/SwiftUI-Native-0A84FF?style=flat&logo=apple&logoColor=white" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/iOS-18%2B-111827?style=flat&logo=ios&logoColor=white" alt="iOS 18+" />
  <img src="https://img.shields.io/badge/Liquid_Glass-iOS_26-7C3AED?style=flat" alt="Liquid Glass" />
  <img src="https://img.shields.io/badge/XcodeGen-Project-blue?style=flat" alt="XcodeGen" />
  <img src="https://img.shields.io/badge/GitHub_Actions-iOS_Build-2088FF?style=flat&logo=githubactions&logoColor=white" alt="GitHub Actions" />
</p>

</div>

## Overview

Pomlist 不是“时间一到就结束”的传统倒计时番茄钟，而是把一次专注定义成“围绕一组任务推进到什么程度”。你可以先整理任务，再挑选若干任务开启一轮专注；进行中随时勾选完成项，结束时记录完成数量、完成率、时长、分类贡献、时段分布与效率变化。

这次重构保留了原 Web 版的核心能力，但整体交互改成更像苹果原生应用：

- `TabView` 驱动的 Today / Task / History / Stats 四个主页面
- 原生 `NavigationStack`、`sheet`、`Form`、`swipeActions` 与列表
- Liquid Glass 风格卡片、按钮、指标胶囊与背景层次
- 本地 JSON 文件数据库，单设备即可运行

## Features

- 4 位口令登录：首次默认口令为 `0xbp`，支持在应用内修改与退出登录。
- 任务库：支持新增、编辑、完成/恢复、删除任务，并维护分类、标签与具体内容。
- 任务钟：从任务列表中多选任务开启专注，只允许单个 active session。
- 会话内增量加任务：专注进行中可继续向本轮会话追加任务。
- 会话内勾选：专注过程中可逐项勾选，进度与完成率即时更新。
- 历史记录：保留每次已结束任务钟的时间、时长、完成数量与任务快照。
- 数据统计：提供今日 / 7 天 / 30 天指标、连续专注天数、分类贡献、24 小时时段分布与效率视角。
- 原生观感：iOS 26 上使用官方 Liquid Glass API，较低系统版本自动回退到 `Material` 风格。

## Tech Stack

- 客户端：`Swift 6`、`SwiftUI`、`Observation / ObservableObject`
- 可视化：`Swift Charts`
- 持久化：本地 `JSON` 文件，存于 App `Application Support`
- 工程管理：`XcodeGen`
- CI 打包：`GitHub Actions` + `xcodebuild`

## Project Structure

```text
Pomlist/
├── App/                  App 入口、根视图、Tab 壳层
├── Core/
│   ├── Design/           Liquid Glass 视觉封装与主题色
│   └── Extensions/       日期与格式化扩展
├── Features/
│   ├── Auth/             口令登录
│   ├── Today/            今日专注主页
│   ├── Tasks/            任务库与元信息维护
│   ├── History/          已完成任务钟历史
│   ├── Stats/            统计与图表
│   └── Shared/           设置、任务编辑、任务选择等共享弹层
├── Models/               任务、会话、统计模型
├── Services/             本地存储与统计计算
└── Store/                全局状态与业务动作
.github/workflows/
└── ios-build.yml         GitHub Actions 构建与打包
project.yml               XcodeGen 工程描述
```

## Quick Start

1. 安装 XcodeGen。

```bash
brew install xcodegen
```

2. 在仓库根目录生成工程。

```bash
xcodegen generate
```

3. 用 Xcode 打开 `Pomlist.xcodeproj`，选择 `Pomlist` Scheme。

4. 直接运行到模拟器或真机。

5. 首次进入时使用默认口令 `0xbp` 登录。

## Build

本地命令：

```bash
xcodegen generate
xcodebuild -project Pomlist.xcodeproj -scheme Pomlist -destination 'platform=iOS Simulator,name=iPhone 16' test
xcodebuild -project Pomlist.xcodeproj -scheme Pomlist -configuration Release -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

GitHub Actions 会自动完成：

- 生成 Xcode 工程
- 运行单元测试
- 构建 Release 模拟器 `.app`
- 归档无签名 `.xcarchive`
- 上传构建产物到 Actions Artifacts

## Runtime Model

- 默认仅单用户本机使用。
- 登录态、本地任务和会话历史都写入应用沙盒的 JSON 文件。
- 不依赖 Supabase、Next.js API 或远程数据库。
- 如需后续扩展到 iCloud / CloudKit / 自建同步层，可以在 `Store` 和 `Services` 层继续演进。

## Packaging Note

当前仓库内的 GitHub Actions 采用“可直接跑通的无签名打包”方案：

- `Pomlist-simulator-app.zip`：可用于模拟器验收与 UI 回归
- `Pomlist-xcarchive.zip`：可作为后续签名分发的基础产物

如果你后面要产出正式 `.ipa`，只需在 workflow 中增加 Apple 证书、描述文件和 `xcodebuild -exportArchive` 步骤即可。

## Design Note

根据 Apple 官方文档，Liquid Glass 已在较新 SDK 中提供 `glassEffect(_:in:)`、`GlassEffectContainer` 等能力；本仓库在支持的系统上优先使用这些 API，在较低版本回退到 `ultraThinMaterial`，保证“苹果原生感”与兼容性同时成立。
