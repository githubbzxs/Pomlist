# Pomlist Web

Pomlist 是一个任务驱动番茄钟应用，核心不是倒计时结束，而是按任务完成度结束一次专注会话。

- 示例：一次任务钟内有 10 个任务，完成 8 个后手动结束，记录为 `8/10`。
- 同时保留软计时，用于复盘统计，但不强制决定结束时机。

## 核心功能

- 账号体系：邮箱 + 密码（注册 / 登录 / 退出）
- To-Do：新增、编辑、完成/恢复、删除、优先级与截止时间
- 任务钟：从待办多选启动，进行中勾选任务，手动结束并记录完成比
- 复盘：今日指标、近 7 天趋势、近 30 天时长分布、连续专注天数
- PWA：支持添加到桌面，离线可打开基础页面

## 技术栈

- Next.js 16 + TypeScript + App Router
- 本地文件数据库（JSON）
- Tailwind CSS 4
- Vitest（单元测试）

## 本地开发

1. 安装依赖：

```bash
npm install
```

2. （可选）配置环境变量：

```bash
# 自定义本地数据库文件路径（默认 data/pomlist-db.json）
POMLIST_DB_PATH=data/pomlist-db.json
```

3. 启动开发服务：

```bash
npm run dev
```

## 数据存储

- 默认数据文件：`data/pomlist-db.json`
- 包含数据表等价结构：
  - `users`
  - `tokens`
  - `todos`
  - `focus_sessions`
  - `session_task_refs`

## 脚本命令

```bash
npm run lint
npm run typecheck
npm run test
npm run build
```

## API 概览

- `POST /api/auth/sign-up`
- `POST /api/auth/sign-in`
- `POST /api/auth/sign-out`
- `GET /api/todos`
- `POST /api/todos`
- `PATCH /api/todos/:id`
- `DELETE /api/todos/:id`
- `POST /api/sessions/start`
- `GET /api/sessions/active`
- `PATCH /api/sessions/:id/toggle-task`
- `POST /api/sessions/:id/end`
- `GET /api/analytics/dashboard`
- `GET /api/analytics/trend?days=7`
- `GET /api/analytics/distribution?days=30`

统一响应结构：

- 成功：`{ success: true, data: ... }`
- 失败：`{ success: false, error: { code, message, details? } }`

## 部署

- 目标域名：`pomlist.0xpsyche.me`
- 建议反代：Caddy / Nginx
- 应用进程：PM2（`npm run start`）
