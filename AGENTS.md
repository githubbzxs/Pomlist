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

## Decisions（增量）

- **[2026-02-15] 主题对齐调整**：全站背景改为纯黑，强调色统一改为蓝色。
  - Why：按最新设计参考图收敛视觉方向（黑底 + 蓝色高亮）。
  - Impact：`app/globals.css`、`app/layout.tsx`、`public/manifest.webmanifest`、`public/icons/*`、`components/charts/*`、`app/focus/page.tsx`、`app/todo/page.tsx`、`app/today/page.tsx`。
  - Verify：页面背景为黑色，主按钮/进度/图表/勾选强调为蓝色，移动端与 PWA 主题色一致。

## Commands（增量）

- **[2026-02-15] 全量校验**：`npm run lint && npm run test && npm run typecheck && npm run build`

## Status / Next（增量）

- **[2026-02-15] 当前状态**：黑底蓝强调主题已落地并通过本地全量校验，待推送并重部署。
- **[2026-02-15] 下一步**：完成大陆 VPS 重部署后，验收 `today` 与 `auth` 页的色彩一致性。

## Decisions（增量）

- **[2026-02-15] 本轮验证策略**：按最新需求仅做本地测试，暂不执行远程 VPS 部署。
  - Why：先验证“背景更黑 + 主页面单整块”改动，避免频繁部署返工。
  - Impact：本轮只执行本地校验命令，不触发远端发布流程。
  - Verify：`npm run lint && npm run test && npm run typecheck && npm run build` 全部通过。

## Status / Next（增量）

- **[2026-02-15] 当前状态**：背景加深与中心页单整块改造已完成，本地测试通过。
- **[2026-02-15] 下一步**：你确认视觉后，再决定是否进行 VPS 重部署。

## Decisions（增量）

- **[2026-02-15] 主页去框化**：`today` 中心页移除外层手机壳与主卡片的边框阴影，改为无框主视图。
  - Why：用户明确要求“主页不要有框”，并希望视觉更克制。
  - Impact：`app/today/page.tsx`、`app/globals.css`。
  - Verify：主页不再出现外框与主内容卡片边框，右侧/下方功能结构不变。

- **[2026-02-15] 主页视觉细化**：中心页任务列表改为轻量无框行样式，计时区与按钮区增强层次但不增加分块。
  - Why：在去框前提下保持可读性与操作反馈。
  - Impact：`app/today/page.tsx`、`app/globals.css`。
  - Verify：任务项仍可点击勾选，按钮可正常开启/结束专注，视觉风格更统一。

## Status / Next（增量）

- **[2026-02-15] 当前状态**：主页去框与视觉优化已完成，并通过本地 `lint/typecheck/build`。
- **[2026-02-15] 下一步**：若需要，我可以继续把右侧 Task 页和下方 Statistic 页同步成同一套“无框”风格。

## Decisions（增量）

- **[2026-02-15] 本地 SW 保护**：开发环境自动注销 Service Worker 并清理 `pomlist-static` 缓存，`sw.js` 在 localhost 下不拦截导航请求。
  - Why：避免本地 `localhost:3000/today` 被历史缓存误判为离线页。
  - Impact：`components/pwa-register.tsx`、`public/sw.js`。
  - Verify：本地刷新后不再出现“当前离线”回退；`npm run lint && npm run typecheck && npm run build` 通过。

## Status / Next（增量）

- **[2026-02-15] 当前状态**：本地离线页误触发问题已修复，开发环境不再被 SW 接管。
- **[2026-02-15] 下一步**：如需保留离线能力，仅在生产环境继续启用 SW。

## Decisions（增量）

- **[2026-02-15] 外层框恢复**：恢复 `today` 页外层手机大框，仅保留主页内部无框化。
  - Why：用户确认外层框是需要保留的视觉锚点。
  - Impact：`app/today/page.tsx`、`app/globals.css`。
  - Verify：`today` 页外层边框与阴影可见，内部主区仍为无框布局。

## Decisions（增量）

- **[2026-02-15] Glass 视觉系统重构**：全站统一为“深黑基底 + 拟物玻璃 + 克制蓝强调”。
  - Why：按最新设计目标彻底提升视觉一致性与质感。
  - Impact：`app/globals.css`、`app/layout.tsx`、`public/manifest.webmanifest`。
  - Verify：基础控件、卡片、输入、按钮、移动画布与弹层样式统一。

- **[2026-02-15] Today 三面板重塑**：在保留交互结构前提下，中心/任务/统计三面板切换到同一玻璃层级。
  - Why：保留既有流程并消除页面割裂感。
  - Impact：`app/today/page.tsx`、`components/mobile/task-picker-drawer.tsx`。
  - Verify：布局不变，视觉层次明显提升，任务抽屉与主面板风格一致。

- **[2026-02-15] 图表风格重绘**：趋势图和分布图统一为玻璃容器、低饱和蓝网格与渐变主线。
  - Why：避免图表与页面主视觉脱节。
  - Impact：`components/charts/trend-chart.tsx`、`components/charts/distribution-chart.tsx`、`app/analytics/page.tsx`。
  - Verify：空态、坐标、网格、主线和进度条均符合新风格。

- **[2026-02-15] 核心页面视觉统一**：`auth/focus/todo` 与壳层页面文案编码统一修复。
  - Why：解决旧页面视觉和文案编码不一致问题。
  - Impact：`app/auth/page.tsx`、`app/focus/page.tsx`、`app/todo/page.tsx`、`app/page.tsx`、`components/app-shell.tsx`、`app/offline/page.tsx`。
  - Verify：页面文案正常显示，主视觉语言一致。

## Commands（增量）

- **[2026-02-15] 全量校验**：`npm run lint && npm run test && npm run typecheck && npm run build`

## Status / Next（增量）

- **[2026-02-15] 当前状态**：UI 彻底重构已在本地完成并通过全量校验（未做远端部署）。
- **[2026-02-15] 下一步**：根据你的主观审美反馈，继续微调玻璃强度、字重和图表密度。

## Decisions（增量）

- **[2026-02-15] 浅色苹果风改造**：全站改为浅色基底，移除重渐变背景，统一蓝色强调与轻阴影。
  - Why：按最新反馈回归苹果风视觉，避免暗色+重渐变带来的“土气感”。
  - Impact：`app/globals.css`、`app/layout.tsx`、`public/manifest.webmanifest`、`public/icons/*`、`app/today/page.tsx`、`app/focus/page.tsx`、`app/todo/page.tsx`、`components/charts/*`、`components/feedback-state.tsx`。
  - Verify：`npm run lint`、`npm run test`、`npm run typecheck`、`npm run build` 全通过。

## Commands（增量）

- **[2026-02-15] 全量校验**：`npm run lint`、`npm run test`、`npm run typecheck`、`npm run build`

## Status / Next（增量）

- **[2026-02-15] 当前状态**：浅色苹果风已完成并通过本地全量校验。
- **[2026-02-15] 下一步**：测试 VPS 重部署因当前机器无可用 SSH 凭据失败，待补充可用登录方式后重试部署验收。

## Decisions（增量）

- **[2026-02-15] 部署修正**：按最新指令撤销香港部署，切回大陆机器作为 Pomlist 运行环境。
  - Why：用户确认“大陆部署，香港删除”。
  - Impact：香港机 `103.52.152.92` 删除 `pomlist-hk` 进程与 Nginx 站点；大陆机 `106.15.59.92` 更新并重启 `pomlist`。
  - Verify：大陆机 `C:\www\pomlist` 已更新到 `ba87e35`，`pm2 ls` 显示 `pomlist` online，`curl -I http://127.0.0.1:3005/today` 返回 `200`。

## Status / Next（增量）

- **[2026-02-15] 当前状态**：香港侧 Pomlist 已清理；大陆侧 Pomlist 已恢复并在线。
- **[2026-02-15] 下一步**：如需公网 HTTPS 健康检查，补做一次外部网络侧连通性验收。

## Decisions（增量）

- **[2026-02-15] 深黑主题二次确认**：主界面主体色统一为深黑（`#050506`），同步到页面主题色与 PWA 配置。
  - Why：按最新需求强化深黑基底视觉一致性。
  - Impact：`app/globals.css`、`app/layout.tsx`、`public/manifest.webmanifest`。
  - Verify：页面主体背景为深黑，浏览器与 PWA 主题色一致。

- **[2026-02-15] 计时展示时机调整**：专注进行中不显示时间，结束后才显示本次用时；结束后停留中心页以便立即可见。
  - Why：按最新交互要求减少进行中时间干扰，强调结束反馈。
  - Impact：`app/today/page.tsx`。
  - Verify：点击开始后计时数字隐藏；点击结束后中心页显示“上次结束用时”。

## Status / Next（增量）

- **[2026-02-15] 当前状态**：深黑主题与“结束后显示用时”已完成，并通过本地 `lint/typecheck/build`。
- **[2026-02-15] 下一步**：在大陆 VPS 验收线上交互是否与本地一致（进行中隐藏、结束后立即显示）。

## Decisions（增量）

- **[2026-02-15] 大陆机部署恢复流程固化**：当 Windows 上 `npm ci` 触发 `EPERM unlink next-swc` 时，先移除 PM2 进程再重装依赖与重建。
  - Why：`next-swc.win32-x64-msvc.node` 被占用会导致依赖安装失败，进而使 `pomlist` 无法启动。
  - Impact：大陆机 `C:\www\pomlist` 的运维流程改为 `pm2 delete pomlist -> rmdir node_modules/.next -> npm ci -> npm run build -> pm2 start`。
  - Verify：`pm2 ls` 显示 `pomlist` online，`curl -I http://127.0.0.1:3005/today` 返回 `HTTP/1.1 200 OK`。

## Status / Next（增量）

- **[2026-02-15] 当前状态**：大陆 VPS 已更新到 `3f19d70`，深黑主题与“进行中隐藏时间、结束后显示用时”已在线生效。
- **[2026-02-15] 下一步**：如需，我可以补做一次公网域名 `pomlist.0xpsyche.me` 的 HTTPS 回源验收。

## Decisions（增量）

- **[2026-02-15] 主页中心面板去细线**：移除 `today` 中心主区细线边框与伪元素描边。
  - Why：按最新视觉反馈，主区不需要框线干扰。
  - Impact：`app/globals.css`。
  - Verify：中心主区不再出现外框细线。

- **[2026-02-15] 任务按钮对比度修复**：提升“添加任务”区域按钮与禁用态文字可读性。
  - Why：修复浅灰按钮与文字对比度不足问题。
  - Impact：`app/globals.css`。
  - Verify：按钮在可用/禁用状态下文字均清晰可读。

- **[2026-02-15] 统计区精简**：移除 `today` 统计页“时段分布（UTC）”独立区块与“7 天趋势”图。
  - Why：按最新信息层级要求收敛统计视图。
  - Impact：`app/today/page.tsx`、`app/analytics/page.tsx`。
  - Verify：统计页不再出现“时段分布（UTC）”与“7 天趋势”。

- **[2026-02-15] 分布口径改造**：将“30 天分布”改为“时间分布”，按小时分布展示。
  - Why：按新口径聚焦一天内时段分布而非时长分桶。
  - Impact：`app/today/page.tsx`、`app/analytics/page.tsx`、`components/charts/distribution-chart.tsx`、`lib/client/types.ts`。
  - Verify：标题为“时间分布”，横条标签为 `00:00` 等小时段。

- **[2026-02-15] 标签配色多样化**：标签默认配色改为多色系，并按标签名自动分配稳定色值。
  - Why：解决标签默认同色系导致识别度不足问题。
  - Impact：`app/today/page.tsx`、`components/mobile/task-picker-drawer.tsx`。
  - Verify：不同标签自动呈现不同色系，旧默认单蓝标签会被分散映射。

## Status / Next（增量）

- **[2026-02-15] 当前状态**：6 条视觉与统计改动已完成，并通过本地 `lint/test/typecheck/build`。
- **[2026-02-15] 下一步**：大陆 VPS 重部署并验收 `today` 页面按钮可读性与统计区块显示。

## Decisions（增量）

- **[2026-02-15] 大陆机重部署完成（本轮6项UI调整）**：按 `pm2 delete -> rmdir node_modules/.next -> npm ci -> npm run build -> pm2 start` 流程完成重建。
  - Why：落实本轮 1~6 条视觉与统计需求并确保线上一致。
  - Impact：大陆机 `C:\www\pomlist`，进程 `pomlist`（PM2 id 9）。
  - Verify：`pm2 ls` 显示 `pomlist` online；`curl -I http://127.0.0.1:3005/today` 返回 `HTTP/1.1 200 OK`。

## Status / Next（增量）

- **[2026-02-15] 当前状态**：`main` 已推送至 `c0dcf45`，大陆 VPS 已部署并回源正常。
- **[2026-02-15] 下一步**：如需我可继续把 `today` 的“周期视角”文案从“近 7 天与 30 天”同步改成与当前展示完全一致。

## Decisions（增量）

- **[2026-02-15] Today 上滑页改为历史记录**：上滑页从统计视图改为“完成钟历史”，并新增历史接口。
  - Why：对齐“上页显示历史记录”的新交互需求。
  - Impact：`app/today/page.tsx`、`app/api/sessions/history/route.ts`、`lib/client/pomlist-api.ts`、`lib/client/types.ts`、`components/mobile/app-canvas.tsx`。
  - Verify：`npm run lint && npm run test && npm run typecheck && npm run build` 通过；`/api/sessions/history` 返回已完成会话列表。

- **[2026-02-15] 主页文案收敛**：移除“启动专注后隐藏时间，结束后显示用时 / 尚未添加任务 / 当前没有任务，先添加再开始。”
  - Why：按最新视觉文案要求减少干扰信息。
  - Impact：`app/today/page.tsx`。
  - Verify：主页不再出现上述三段文字，开始/结束逻辑保持不变。

## Status / Next（增量）

- **[2026-02-15] 当前状态**：两项需求已在本地完成并通过全量校验，等待大陆 VPS 重部署。
- **[2026-02-15] 下一步**：按既定流程在大陆 VPS 执行重建并验收历史页展示。

## Decisions（增量）

- **[2026-02-15] 大陆机重部署完成（历史页改造）**：按 `pm2 delete -> rmdir node_modules/.next -> npm ci -> npm run build -> pm2 start` 流程完成发布。
  - Why：本轮改动已涉及 `today` 主流程与新增接口，需按约定在测试 VPS 验收。
  - Impact：大陆机 `C:\www\pomlist`，进程 `pomlist`（PM2 id 10）。
  - Verify：`git rev-parse --short HEAD` 为 `47f0587`；`pm2 ls` 显示 `pomlist` online；`curl -I http://127.0.0.1:3005/today` 返回 `HTTP/1.1 200 OK`。

## Status / Next（增量）

- **[2026-02-15] 当前状态**：主页文案精简 + 上滑历史记录页已上线大陆测试机并回源正常。
- **[2026-02-15] 下一步**：如需，我可以继续按你的参考图微调历史记录页卡片样式（密度、时间格式、字段顺序）。
