# 项目记忆（Pomlist）

## Facts

- **[2026-02-13] 产品定位**：Pomlist 已从 iOS 迁移为 Web 应用，核心仍是“任务驱动番茄钟 + To-Do + 复盘”。
- **[2026-02-13] 首发终端**：移动端优先并兼容桌面，支持 PWA。
- **[2026-02-13] 语言范围**：首版仅中文。
- **[2026-02-13] 账号模式**：邮箱+密码（注册/登录/退出），首版不含找回密码。

## Decisions

- **[2026-02-13] 仓库策略**：完全替换 iOS 代码为 Next.js Web 架构。
  - Why：避免 iOS 签名/真机调试门槛，优先保证本地开发与上线效率。
  - Impact：删除 `Pomlist/`、`PomlistTests/`、`project.yml` 与 IPA 流程，统一为 Web 工程。
- **[2026-02-13] 数据层方案**：Supabase + PostgreSQL + RLS。
  - Why：满足账号与云同步需求，减少自建后端复杂度。
  - Impact：新增 `supabase/migrations/0001_init.sql`，并通过 API 路由封装业务规则。
- **[2026-02-13] 任务钟规则**：单用户仅一个 active session，支持如 `8/10` 手动收钟。
  - Why：保持产品差异化核心。
  - Impact：`focus_sessions` 增加 partial unique index，`session_task_refs` 存储任务快照与勾选状态。
- **[2026-02-13] PWA 策略**：缓存静态壳，业务 API 不做离线缓存。
  - Why：避免离线脏数据覆盖线上状态。
  - Impact：`public/sw.js` 仅缓存基础资源与离线页。

## Commands

- **[2026-02-13] 本地开发**：`npm run dev`
- **[2026-02-13] 代码检查**：`npm run lint`
- **[2026-02-13] 类型检查**：`npm run typecheck`
- **[2026-02-13] 单元测试**：`npm run test`
- **[2026-02-13] 生产构建**：`npm run build`

## Status / Next

- **[2026-02-13] 当前状态**：Web 首版主流程已实现（auth、todo、focus、analytics、PWA、API、迁移、测试、CI）。
- **[2026-02-13] 下一步**：接入 Supabase 实例做真实联调，并部署到 `pomlist.0xpsyche.me`。

## Known Issues

- **[2026-02-13] 首版账号能力**：暂不支持找回密码和邮箱验证。
  - Verify：后续二期补充 `reset password` 邮件流程与页面。
- **[2026-02-13] 离线能力边界**：仅保证基础页面可打开，业务数据依赖网络。
  - Verify：断网访问 `/offline`，联网后恢复 API 请求。

