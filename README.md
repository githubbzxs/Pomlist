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
  <img src="https://img.shields.io/badge/GitHub_Pages-IPA_Download-0A84FF?style=flat&logo=githubpages&logoColor=white" alt="GitHub Pages IPA Download" />
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
docs/
└── download/             IPA 下载页源码
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

无签名 IPA：

- 推送到 `main` 后会自动触发 `.github/workflows/ios-unsigned-ipa.yml`
- 该工作流会生成 `Pomlist.ipa` 并发布到 GitHub Pages 下载页
- 注意：这是未签名 IPA，不能直接安装到 iPhone / iPad

签名导出 IPA：

- 手动触发 `.github/workflows/ios-ipa-release.yml`
- 成功后会生成签名 IPA、OTA `manifest.plist`、`latest.json`
- 如果开启 `publish_pages`，还会自动发布到 GitHub Pages 下载页

## Runtime Model

- 默认仅单用户本机使用。
- 登录态、本地任务和会话历史都写入应用沙盒的 JSON 文件。
- 不依赖 Supabase、Next.js API 或远程数据库。
- 如需后续扩展到 iCloud / CloudKit / 自建同步层，可以在 `Store` 和 `Services` 层继续演进。

## Packaging Note

当前仓库内的 GitHub Actions 默认采用“无签名 IPA 导出 + 页面发布”方案：

- `Pomlist-simulator-app.zip`：可用于模拟器验收与 UI 回归
- `Pomlist-xcarchive.zip`：可作为后续签名分发的基础产物
- `Pomlist.ipa`：未签名 IPA，可用于留档、二次签名或研究

如果你后面要产出“可直接安装到真机”的正式 `.ipa`，仍然需要 Apple 证书和描述文件。

如果你暂时没有证书，现在只需要等 `iOS Unsigned IPA` 工作流成功一次，就会得到固定下载链接：

- 下载页：`https://githubbzxs.github.io/Pomlist/download/`
- IPA：`https://githubbzxs.github.io/Pomlist/download/Pomlist.ipa`

如果你以后要启用签名版 IPA，再在 GitHub 仓库中配置：

- `Secrets`
  - `IOS_BUILD_CERTIFICATE_BASE64`
  - `IOS_P12_PASSWORD`
  - `IOS_MOBILEPROVISION_BASE64`
  - `IOS_KEYCHAIN_PASSWORD`
- `Variables`
  - `IOS_TEAM_ID`
  - `IOS_BUNDLE_ID`（可选，默认 `me.0xpsyche.Pomlist`）
  - `IOS_EXPORT_METHOD`（可选，默认 `ad-hoc`）
  - `IOS_CODE_SIGN_IDENTITY`（可选，默认 `Apple Distribution`）

同时请在仓库 `Settings -> Pages` 中把发布源切到 `GitHub Actions`。

首次成功运行 `iOS Signed IPA` 工作流后，签名版会覆盖同一路径，并额外提供：

- 下载页：`https://githubbzxs.github.io/Pomlist/download/`
- IPA：`https://githubbzxs.github.io/Pomlist/download/Pomlist.ipa`
- Manifest：`https://githubbzxs.github.io/Pomlist/download/manifest.plist`

## Design Note

根据 Apple 官方文档，Liquid Glass 已在较新 SDK 中提供 `glassEffect(_:in:)`、`GlassEffectContainer` 等能力；本仓库在支持的系统上优先使用这些 API，在较低版本回退到 `ultraThinMaterial`，保证“苹果原生感”与兼容性同时成立。
