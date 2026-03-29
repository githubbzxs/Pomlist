<div align="center">

# Pomlist

<p><strong>任务驱动的专注清单应用：用任务完成度，而不是固定时长，定义一次番茄钟</strong></p>

<p>
  Pomlist 把待办清单、专注会话、复盘统计和 PWA 体验放进同一个单用户工作流。你可以从待办中挑选任务开启一次任务钟，在过程中随时勾选完成项，最后按实际完成比结束会话，而不是被倒计时强行打断。
</p>

<p>
  <img src="https://img.shields.io/badge/Next.js-16-111827?style=flat&logo=nextdotjs&logoColor=white" alt="Next.js 16" />
  <img src="https://img.shields.io/badge/React-19-149ECA?style=flat&logo=react&logoColor=white" alt="React 19" />
  <img src="https://img.shields.io/badge/TypeScript-5-3178C6?style=flat&logo=typescript&logoColor=white" alt="TypeScript 5" />
  <img src="https://img.shields.io/badge/Tailwind_CSS-4-06B6D4?style=flat&logo=tailwindcss&logoColor=white" alt="Tailwind CSS 4" />
  <img src="https://img.shields.io/badge/PWA-Ready-059669?style=flat" alt="PWA Ready" />
  <img src="https://img.shields.io/badge/Vitest-Tested-6D28D9?style=flat" alt="Vitest" />
</p>

</div>

## 概览

Pomlist 不是传统意义上“25 分钟倒计时结束就算完成”的番茄钟，而是把一次专注定义为“围绕一组任务推进到什么程度”。

你可以先建立待办，再从待办中多选任务启动专注会话；专注过程中边做边勾选；结束时系统记录本次任务钟的完成数量、完成率、时长和统计趋势。这种模型更适合真实工作流里的碎片任务、跨任务切换和结果导向复盘。

当前版本默认采用本地文件数据库运行，不依赖外部数据库服务，同时保留了一层兼容 `Supabase` 风格的客户端抽象，方便后续平滑切换存储实现。

## 核心功能

- 4 位口令登录：使用单输入框自动提交口令，注册入口默认关闭，适合个人设备或小范围自托管使用。
- 待办管理：支持新增、编辑、完成/恢复、删除任务，并维护优先级、截止时间、科目、备注与标签信息。
- 任务钟启动：从待办中多选任务开始一次专注会话，避免为了凑时长而开钟。
- 会话内勾选：进行中的任务钟可以持续勾选已完成项，并实时更新完成率与进度。
- 手动结束记录：结束时记录 `已完成任务数 / 总任务数` 与本次专注时长，用结果衡量本钟质量。
- 数据复盘：提供今日指标、时段分布、连续专注天数和最近周期统计。
- PWA 支持：可安装到桌面或移动端主屏，离线状态下也能打开基础界面。

## 技术栈

- 前端：`Next.js 16`、`React 19`、`TypeScript`、`App Router`
- 样式与体验：`Tailwind CSS 4`、移动端优先布局、PWA 清单与 Service Worker
- 数据与鉴权：本地 JSON 文件数据库，带 `Supabase` 风格的认证与 REST 抽象层
- 测试与质量：`ESLint`、`TypeScript`、`Vitest`、GitHub Actions CI

## 项目结构

```text
app/
├── api/                  认证、待办、任务钟、统计接口
├── auth/                 口令登录页
├── today/                今日总览与任务入口
├── todo/                 待办列表与任务创建
├── focus/                进行中的任务钟页面
├── analytics/            复盘统计页面
└── offline/              离线兜底页面
components/
├── charts/               统计图表组件
└── mobile/               移动端交互组件
lib/
├── client/               前端 API 调用与会话管理
├── supabase/             本地数据与认证适配层
├── analytics-service.ts  统计计算逻辑
└── validation.ts         输入校验与任务字段规范化
public/
├── icons/                PWA 图标
└── manifest.webmanifest  PWA 配置
tests/
├── analytics-service.test.ts
└── validation.test.ts
```

## 快速开始

1. 安装依赖，建议使用 `Node.js 22`。

```bash
npm install
```

2. 配置环境变量，可直接使用默认值，也可以按需覆盖。

```bash
# 本地数据文件路径，默认 data/pomlist-db.json
POMLIST_DB_PATH=data/pomlist-db.json

# 登录口令，必须为 4 个字符，默认 0xbp
POMLIST_PASSCODE=0xbp
```

3. 启动开发环境。

```bash
npm run dev
```

4. 访问 `http://localhost:3000`，输入 4 位口令进入应用。

## 脚本命令

```bash
npm run dev
npm run lint
npm run typecheck
npm run test
npm run build
npm run start
```

## API 概览

- `POST /api/auth/sign-in`：口令登录
- `POST /api/auth/sign-out`：退出登录
- `PATCH /api/auth/passcode`：修改口令
- `GET /api/todos` / `POST /api/todos`：获取与创建待办
- `PATCH /api/todos/:id` / `DELETE /api/todos/:id`：更新与删除待办
- `POST /api/sessions/start`：从所选任务开启任务钟
- `GET /api/sessions/active`：读取当前进行中的任务钟
- `PATCH /api/sessions/:id/toggle-task`：切换任务钟中的任务完成状态
- `POST /api/sessions/:id/end`：结束任务钟并写入结果
- `GET /api/analytics/dashboard`：读取总览统计
- `GET /api/analytics/trend?days=7`：读取趋势数据
- `GET /api/analytics/distribution?days=30`：读取时段分布

统一响应结构：

- 成功：`{ success: true, data: ... }`
- 失败：`{ success: false, error: { code, message, details? } }`

## 运行模型

Pomlist 当前更偏向单用户、自托管、个人设备优先的运行方式：

- 认证模型基于 4 位口令与本地 access token
- 默认用户数据保存在本地 JSON 文件中
- 注册入口关闭，避免公开实例变成开放注册系统
- 适合作为个人任务面板、学习专注面板或轻量家庭内部使用工具

## 注意事项

- `POMLIST_PASSCODE` 必须始终保持为 4 个字符，否则服务会在启动时直接报错。
- 本地数据文件会保存任务、会话和登录态信息，部署时请做好目录权限与备份策略。
- 如果你准备把它改造成多用户或公网版本，建议先替换认证与存储实现，再开放外网访问。
