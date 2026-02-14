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

## Decisions（增量）

- **[2026-02-14] 主界面极简化**：移除左侧设置面板与边缘导航小胶囊，保留中心专注页 + 右侧任务页 + 下方统计页。
  - Why：聚焦单人使用场景，降低无效入口与干扰信息。
  - Impact：`components/mobile/app-canvas.tsx`、`app/today/page.tsx`、`app/globals.css`。
  - Verify：中心页仅通过手势进入右/下页，设置页入口不存在。

- **[2026-02-14] 文案与标题收敛**：主页面标题改为 `Pomlist`，任务页标题改为 `Task`，统计页标题改为 `Statistic`，移除多处冗余提示语。
  - Why：强调品牌识别与页面简洁。
  - Impact：`app/today/page.tsx`。
  - Verify：不存在“尚未开始/先添加任务/RIGHT/DOWN/全量视图说明”等冗余文案。

- **[2026-02-14] 任务创建字段收敛**：添加任务仅保留标题、分类、标签，移除优先级/科目/备注与搜索栏。
  - Why：降低输入成本，保留最关键结构化信息。
  - Impact：`components/mobile/task-picker-drawer.tsx`、`app/today/page.tsx`。
  - Verify：抽屉表单仅含标题/分类/标签三项，可正常创建并加入计划。

- **[2026-02-14] 分类与标签管理页落地**：在任务页新增管理层，支持新增/重命名/删除分类与标签，并批量同步到任务数据。
  - Why：满足任务元信息可维护性需求。
  - Impact：`app/today/page.tsx`、`components/mobile/task-picker-drawer.tsx`。
  - Verify：管理操作后任务列表与创建输入建议项同步变化。

- **[2026-02-14] 手机顶部白边修复**：统一 PWA 主题色与状态栏样式，补齐安全区与移动端边框处理。
  - Why：消除移动端顶部白边与回弹露白问题。
  - Impact：`app/layout.tsx`、`public/manifest.webmanifest`、`app/globals.css`。
  - Verify：移动端浏览器/PWA 打开 `today` 顶部无白边。

## Status / Next（增量）

- **[2026-02-14] 当前状态**：极简界面重构、任务元管理与白边修复已完成，并通过 `lint/test/typecheck/build`。
- **[2026-02-14] 下一步**：部署到 VPS 后做真机手势与管理层交互验收，重点确认移动端顶部安全区表现。

## Decisions（增量）

- **[2026-02-14] 移动端白屏修复**：修复小屏条件下画布高度链路，确保手机端 `today` 页可见。
  - Why：`max-width: 420px` 下 `mobile-phone-frame` 使用 `height: 100%`，父容器未提供明确高度，导致画布高度塌陷。
  - Impact：`app/globals.css` 中移动端媒体查询改为 `100dvh` 与安全区扣减高度。
  - Verify：`npm run lint && npm run typecheck && npm run test && npm run build` 通过，手机视口可见主画布。

- **[2026-02-14] 桌面边缘点击导航**：新增桌面端边缘点击切换（中心 -> 右任务 / 下统计，侧页返回中心），手机端保留滑动。
  - Why：桌面没有手势时缺少快捷切页入口。
  - Impact：`components/mobile/app-canvas.tsx` 新增桌面能力检测与边缘按钮；`app/globals.css` 新增边缘导航样式。
  - Verify：桌面宽屏可点击边缘切换，移动端继续通过滑动切换。

## Status / Next（增量）

- **[2026-02-14] 当前状态**：移动端可见性修复与桌面边缘导航已完成，本地 `lint/typecheck/test/build` 全通过。
- **[2026-02-14] 下一步**：在真实手机与桌面浏览器分别验收“滑动阈值手感 + 边缘点击命中范围”。

## Decisions（增量）

- **[2026-02-14] 边缘导航去视觉化**：移除桌面边缘导航的胶囊文案与移动端返回胶囊，改为纯空白热区点击。
  - Why：单人使用场景下不需要提示性 UI，保持画面纯净。
  - Impact：`components/mobile/app-canvas.tsx` 去除按钮文本节点与移动端返回按钮；`app/globals.css` 删除胶囊相关样式。
  - Verify：`npm run lint && npm run typecheck && npm run test && npm run build` 通过；线上 `pomlist` 已重建并重启。

## Status / Next（增量）

- **[2026-02-14] 当前状态**：桌面端仅保留无视觉边缘热区，手机端仅保留滑动切换；线上已生效。
- **[2026-02-14] 下一步**：如需进一步“无提示化”，可把热区宽度再缩窄到更隐蔽。

## Decisions（增量）

- **[2026-02-14] 管理弹层显示修复**：`Task` 页“管理”弹层从 `fixed` 改为 `absolute`，避免在画布平移后延迟显示。
  - Why：弹层位于带 `transform` 的画布内，`fixed` 会相对变换容器定位，导致右页点击后看不到，回中心页才出现。
  - Impact：`app/globals.css` 的 `.meta-manager-backdrop` 定位改为 `position: absolute`。
  - Verify：点击“管理”可在当前任务页立即显示；`npm run lint && npm run typecheck && npm run test && npm run build` 通过；VPS 已重建重启。

## Status / Next（增量）

- **[2026-02-14] 当前状态**：管理弹层即时显示问题已修复并上线。
- **[2026-02-14] 下一步**：若你希望更彻底，可将该弹层改为 `Portal` 到 `body`，彻底与画布布局解耦。

## Decisions（增量）

- **[2026-02-14] 任务卡片直编能力**：任务页点击具体任务后，支持直接编辑分类/标签/具体内容，并可删除任务。
  - Why：满足单人使用下“就地修改任务信息”的高频操作诉求。
  - Impact：`app/today/page.tsx` 新增任务编辑弹层与保存/删除逻辑；任务卡片改为可点击打开编辑。
  - Verify：点击任务后弹层立即打开，保存后列表即时更新，删除后任务从列表移除。

- **[2026-02-14] 新增字段“具体内容”**：任务创建与编辑统一接入“具体内容”，映射到 `notes` 存储。
  - Why：补齐任务描述信息，不额外引入新表结构。
  - Impact：`components/mobile/task-picker-drawer.tsx` 新建表单新增“具体内容”；`app/today/page.tsx` 创建/编辑调用 `notes`。
  - Verify：新建任务可写入具体内容，任务卡片显示内容摘要，编辑可更新。

## Status / Next（增量）

- **[2026-02-14] 当前状态**：任务“点击即编辑 + 分类标签删除 + 具体内容”已完成，并已在大陆 VPS 重建上线。
- **[2026-02-14] 下一步**：若需要可加“任务详情全文展开”和“内容关键字搜索”。

## Decisions（增量）

- **[2026-02-14] 部署保留数据目录**：data/ 视为生产数据目录，后续部署与清理默认保留，不参与删除。
  - Why：该目录存放本地 JSON 数据库文件，删除会导致任务与会话数据丢失。
  - Impact：远端运维流程中不再清理 data/；仓库通过 .gitignore 忽略 data/ 变更噪音。
  - Verify：git status --short 不再出现 data/，且应用重启后历史数据仍在。
