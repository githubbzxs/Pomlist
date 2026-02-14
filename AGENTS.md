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


## Decisions（增量）

- **[2026-02-14] 数据层切换**：移除 Supabase 依赖，改为本地 JSON 文件存储（默认 `data/pomlist-db.json`）。
  - Why：大陆服务器部署要求降低外部依赖，提升可控性。
  - Impact：`lib/supabase/shared.ts` 改为本地兼容实现，API 路由保持不变。

## Commands（增量）

- **[2026-02-14] 可选数据路径**：`POMLIST_DB_PATH=<path>`（默认 `data/pomlist-db.json`）

## Status / Next（增量）

- **[2026-02-14] 当前状态**：已完成无 Supabase 版本改造，准备验证并在大陆服务器重部署。
- **[2026-02-14] 下一步**：线上验证登录、任务、任务钟与复盘闭环。

## Decisions（增量）

- **[2026-02-14] 登录形态切换**：移除邮箱注册/登录，统一为四字符口令登录。
  - Why：降低交互复杂度，满足“登录页仅单输入框”的产品要求。
  - Impact：`/auth` 仅保留一个密码框；`/api/auth/sign-up` 下线；`/api/auth/sign-in` 改为 `passcode`。

## Commands（增量）

- **[2026-02-14] 登录口令变量**：`POMLIST_PASSCODE`（必须 4 个字符，未配置默认 `0xbp`）

## Status / Next（增量）

- **[2026-02-14] 当前状态**：单框动效登录页与口令鉴权已实现，待回归测试与部署验收。
- **[2026-02-14] 下一步**：线上验证错误态动效、自动提交与跳转链路。

## Decisions（增量）

- **[2026-02-14] 主题升级**：全站切换为暗色界面，并统一交互动效节奏。
  - Why：满足“暗色 + 丝滑”视觉要求，提升夜间可读性与质感。
  - Impact：`app/globals.css` 新增暗色变量与动效；`app/*`、`components/*` 主要页面与组件改为暗色配色。
  - Verify：`npm run lint && npm run typecheck && npm run test && npm run build` 全通过。

## Status / Next（增量）

- **[2026-02-14] 当前状态**：暗色界面与顺滑动效已完成并通过本地全量校验。
- **[2026-02-14] 下一步**：部署到大陆服务器并验证 `pomlist.0xpsyche.me` 的登录与主流程体验。

## Decisions（增量）

- **[2026-02-14] 动效节奏调整**：根据反馈将登录与页面动效整体降速。
  - Why：原动效节奏偏快，影响观感与可控感。
  - Impact：`app/globals.css` 的过渡时长、入场动画、登录输入框展开与抖动时长均已放慢；`app/auth/page.tsx` 同步错误态定时器。
  - Verify：本地 `npm run lint && npm run typecheck && npm run build` 通过。

## Decisions（增量）

- **[2026-02-14] 动效二次降速**：进一步放慢登录框展开与页面入场速度。
  - Why：第一次降速后体感仍偏快。
  - Impact：`app/globals.css` 新增 `--dur-expand`，并显著拉长 `auth-passcode-input` 展开、`staggered-reveal` 入场与背景漂移动效；`app/auth/page.tsx` 错误态计时同步为 780ms。
  - Verify：本地 `npm run lint && npm run typecheck && npm run build` 通过。

## Decisions（增量）

- **[2026-02-14] 点击缓冲动效**：登录输入框加入“按下-回弹-展开”弹性缓冲，并全站再慢一档。
  - Why：用户反馈“点击一瞬间切换太快”，需要更有缓冲感。
  - Impact：`app/globals.css` 增加 `passcode-press-buffer` 关键帧并上调全局时长变量；`app/auth/page.tsx` 错误态计时同步为 900ms。
  - Verify：本地 `npm run lint && npm run typecheck && npm run build` 通过。

## Decisions（增量）

- **[2026-02-14] 交互架构重构**：主应用改为“单画布四向面板”（中心番茄钟、左设置、右任务库、下统计）。
  - Why：统一移动端 App 心智，网页仅做手机画布放大。
  - Impact：`app/today/page.tsx`、`components/mobile/*`、`app/globals.css`、`components/app-shell.tsx` 全面改造。
  - Verify：手势与边缘入口可在四个面板间切换，中心页默认进入。

- **[2026-02-14] 任务模型升级**：Todo 新增 `category` 与 `tags`，并贯穿 API/本地存储/客户端类型。
  - Why：满足“基础分类 + 可选标签”与统计聚合需求。
  - Impact：`types/domain.ts`、`lib/client/types.ts`、`lib/domain-mappers.ts`、`lib/supabase/shared.ts`、`app/api/todos/*`。
  - Verify：创建/更新任务可写入分类与标签，列表与筛选正常。

- **[2026-02-14] 会话能力增强**：新增会话中增量加任务接口。
  - Why：支持在番茄钟进行中继续从任务库补充任务。
  - Impact：新增 `app/api/sessions/[id]/tasks/route.ts`，前端通过 `addTasksToSession` 调用。
  - Verify：专注进行中新增任务后，中心清单与 `n/x` 进度立即更新。

- **[2026-02-14] 设置页落地**：新增口令修改 API，并在左侧设置页接入“改口令 + 退出登录”。
  - Why：符合单用户 VPS 场景下的最小可用设置能力。
  - Impact：新增 `app/api/auth/passcode/route.ts`，`lib/supabase/shared.ts` 增加本地口令更新逻辑。
  - Verify：旧口令校验、新口令生效，退出后需重新登录。

- **[2026-02-14] 统计看板增强**：dashboard 返回周期、分类、时段、效率等多维数据。
  - Why：满足“时间维度 + 个数统计 + 更高视角”的分析目标。
  - Impact：`lib/analytics-service.ts`、`app/api/analytics/dashboard/route.ts`、`app/today/page.tsx`。
  - Verify：统计页可见今日/7天/30天、分类贡献、24小时分布、效率与周期对比。

## Commands（增量）

- **[2026-02-14] 全量校验**：`npm run lint && npm run test && npm run typecheck && npm run build`

## Status / Next（增量）

- **[2026-02-14] 当前状态**：四向移动画布重构已完成，新增接口与统计维度已接通并通过本地全量校验。
- **[2026-02-14] 下一步**：部署到 VPS 后做真机/PWA 手势体验验收（重点检查滑动阈值与统计刷新链路）。
