# Pomlist Web

Pomlist 是一个任务驱动番茄钟应用，核心不是倒计时结束，而是按任务完成度结束一次专注会话。

- 示例：一个任务钟内有 10 个任务，完成 8 个后手动结束，记录为 `8/10`。
- 同时保留软计时，用于复盘统计，但不强制决定结束时间。

## 核心功能

- 账号体系：邮箱 + 密码（注册 / 登录 / 退出）
- To-Do：新增、编辑、完成/恢复、删除、优先级与截止时间
- 任务钟：从待办多选启动，进行中勾选任务，手动结束并记录完成比
- 复盘：今日指标、近 7 天趋势、近 30 天时长分布、连续专注天数
- PWA：支持添加到桌面，离线可打开基础页面

## 技术栈

- Next.js 16 + TypeScript + App Router
- Supabase（PostgreSQL + Auth + RLS）
- Tailwind CSS 4
- Vitest（单元测试）

## 本地开发

1. 安装依赖：
   ```bash
   npm install
   ```
2. 配置环境变量（`.env.local`）：
   ```bash
   NEXT_PUBLIC_SUPABASE_URL=...
   NEXT_PUBLIC_SUPABASE_ANON_KEY=...
   # 仅在需要服务端管理能力时使用
   SUPABASE_SERVICE_ROLE_KEY=...
   ```
3. 启动开发服务：
   ```bash
   npm run dev
   ```

## 数据库迁移

迁移文件位于：`supabase/migrations/0001_init.sql`

包含：
- `todos`
- `focus_sessions`
- `session_task_refs`
- 单用户唯一 active session 约束
- RLS 策略（仅可访问自己的数据）

## 脚本命令

- 代码检查：
  ```bash
  npm run lint
  ```
- 类型检查：
  ```bash
  npm run typecheck
  ```
- 单元测试：
  ```bash
  npm run test
  ```
- 生产构建：
  ```bash
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

- 推荐：Vercel + Supabase
- 目标域名：`pomlist.0xpsyche.me`
- CI：`.github/workflows/web-ci.yml`（lint + typecheck + test + build）

