"use client";

import { FormEvent, useCallback, useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { DistributionChart } from "@/components/charts/distribution-chart";
import { TrendChart } from "@/components/charts/trend-chart";
import { FeedbackState } from "@/components/feedback-state";
import { AppCanvas, type CanvasPanel } from "@/components/mobile/app-canvas";
import { TaskPickerDrawer, type CreateTaskInput } from "@/components/mobile/task-picker-drawer";
import { useElapsedSeconds } from "@/hooks/use-elapsed-seconds";
import { ApiClientError } from "@/lib/client/api-client";
import {
  addTasksToSession,
  changePasscode,
  createTodo,
  endSession,
  getActiveSession,
  getDashboardMetrics,
  getDistributionData,
  getTrendData,
  listTodos,
  signOut,
  startSession,
  toggleSessionTask,
} from "@/lib/client/pomlist-api";
import type {
  ActiveSession,
  DashboardMetrics,
  DistributionBucket,
  EfficiencyMetrics,
  HourlyStatsItem,
  PeriodMetrics,
  TodoItem,
  TrendPoint,
} from "@/lib/client/types";

type LoadMode = "initial" | "refresh";

type DisplayTask = {
  id: string;
  title: string;
  completed: boolean;
  fromSession: boolean;
};

const EMPTY_DASHBOARD: DashboardMetrics = {
  date: "",
  sessionCount: 0,
  totalDurationSeconds: 0,
  completionRate: 0,
  streakDays: 0,
  completedTaskCount: 0,
};

const EMPTY_PERIOD: PeriodMetrics = {
  sessionCount: 0,
  totalDurationSeconds: 0,
  completedTaskCount: 0,
  completionRate: 0,
};

const EMPTY_EFFICIENCY: EfficiencyMetrics = {
  tasksPerHour: 0,
  avgCompletionRate: 0,
  avgSessionDurationSeconds: 0,
  periodDelta: {
    sessionCount: 0,
    totalDurationSeconds: 0,
    completionRate: 0,
  },
};

function formatClock(seconds: number): string {
  const safeSeconds = Math.max(0, Math.floor(seconds));
  const minute = Math.floor(safeSeconds / 60);
  const second = safeSeconds % 60;
  return `${String(minute).padStart(2, "0")}:${String(second).padStart(2, "0")}`;
}

function formatDuration(seconds: number): string {
  const minute = Math.max(0, Math.floor(seconds / 60));
  if (minute < 60) {
    return `${minute} 分钟`;
  }
  const hour = Math.floor(minute / 60);
  const remain = minute % 60;
  return `${hour} 小时 ${remain} 分钟`;
}

function errorToText(error: unknown): string {
  if (error instanceof ApiClientError) {
    return error.message;
  }
  return "请求失败，请稍后重试。";
}

function readCategory(todo: TodoItem): string {
  const raw = (todo as TodoItem & { category?: unknown }).category;
  if (typeof raw === "string" && raw.trim().length > 0) {
    return raw.trim();
  }
  if (todo.subject && todo.subject.trim().length > 0) {
    return todo.subject.trim();
  }
  return "未分类";
}

function readTags(todo: TodoItem): string[] {
  const raw = (todo as TodoItem & { tags?: unknown }).tags;
  if (!Array.isArray(raw)) {
    return [];
  }
  return raw.filter((item): item is string => typeof item === "string" && item.trim().length > 0);
}

function progressPercent(completed: number, total: number): number {
  if (total <= 0) {
    return 0;
  }
  return Math.round((completed / total) * 100);
}

export default function TodayPage() {
  const router = useRouter();

  const [panel, setPanel] = useState<CanvasPanel>("center");
  const [drawerOpen, setDrawerOpen] = useState(false);

  const [initialLoading, setInitialLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [starting, setStarting] = useState(false);
  const [ending, setEnding] = useState(false);
  const [creatingTask, setCreatingTask] = useState(false);
  const [addingToSession, setAddingToSession] = useState(false);

  const [error, setError] = useState<string | null>(null);

  const [dashboard, setDashboard] = useState<DashboardMetrics>(EMPTY_DASHBOARD);
  const [trend, setTrend] = useState<TrendPoint[]>([]);
  const [distribution, setDistribution] = useState<DistributionBucket[]>([]);
  const [todos, setTodos] = useState<TodoItem[]>([]);
  const [session, setSession] = useState<ActiveSession | null>(null);
  const [plannedIds, setPlannedIds] = useState<string[]>([]);
  const [draftChecks, setDraftChecks] = useState<Record<string, boolean>>({});

  const [libraryKeyword, setLibraryKeyword] = useState("");
  const [categoryFilter, setCategoryFilter] = useState("全部");

  const [passcodeForm, setPasscodeForm] = useState({
    oldPasscode: "",
    newPasscode: "",
  });
  const [changingPasscode, setChangingPasscode] = useState(false);
  const [signingOut, setSigningOut] = useState(false);
  const [settingsNotice, setSettingsNotice] = useState<string | null>(null);

  const [tickStartAt, setTickStartAt] = useState<Date | null>(null);
  const [tickSessionId, setTickSessionId] = useState<string | null>(null);
  const extraSeconds = useElapsedSeconds(tickStartAt);

  useEffect(() => {
    if (session?.state === "active") {
      if (tickSessionId !== session.id) {
        setTickSessionId(session.id);
        setTickStartAt(new Date());
      }
      return;
    }

    if (tickSessionId !== null) {
      setTickSessionId(null);
      setTickStartAt(null);
    }
  }, [session?.id, session?.state, tickSessionId]);

  const displaySeconds = useMemo(() => {
    if (!session) {
      return 0;
    }
    return session.state === "active" ? session.elapsedSeconds + extraSeconds : session.elapsedSeconds;
  }, [session, extraSeconds]);

  const todoById = useMemo(() => {
    const map = new Map<string, TodoItem>();
    for (const todo of todos) {
      map.set(todo.id, todo);
    }
    return map;
  }, [todos]);

  const pendingTodos = useMemo(() => todos.filter((todo) => todo.status === "pending"), [todos]);

  const plannedTodos = useMemo(() => {
    const result: TodoItem[] = [];
    for (const id of plannedIds) {
      const found = todoById.get(id);
      if (found && found.status === "pending") {
        result.push(found);
      }
    }
    return result;
  }, [plannedIds, todoById]);

  const centerTasks = useMemo<DisplayTask[]>(() => {
    if (session) {
      return session.tasks.map((task) => ({
        id: task.todoId,
        title: task.title,
        completed: task.completed,
        fromSession: true,
      }));
    }

    return plannedTodos.map((todo) => ({
      id: todo.id,
      title: todo.title,
      completed: Boolean(draftChecks[todo.id]),
      fromSession: false,
    }));
  }, [session, plannedTodos, draftChecks]);

  const completedCount = useMemo(() => centerTasks.filter((task) => task.completed).length, [centerTasks]);
  const totalCount = centerTasks.length;

  const categoryOptions = useMemo(() => {
    const values = new Set<string>();
    for (const todo of todos) {
      if (todo.status !== "archived") {
        values.add(readCategory(todo));
      }
    }
    return ["全部", ...Array.from(values)];
  }, [todos]);

  useEffect(() => {
    if (!categoryOptions.includes(categoryFilter)) {
      setCategoryFilter("全部");
    }
  }, [categoryFilter, categoryOptions]);

  const libraryTodos = useMemo(() => {
    const keyword = libraryKeyword.trim().toLowerCase();

    return todos
      .filter((todo) => todo.status !== "archived")
      .filter((todo) => {
        if (categoryFilter !== "全部" && readCategory(todo) !== categoryFilter) {
          return false;
        }

        if (keyword.length === 0) {
          return true;
        }

        const tags = readTags(todo).join(" ").toLowerCase();
        return `${todo.title} ${todo.subject ?? ""} ${readCategory(todo)} ${tags}`
          .toLowerCase()
          .includes(keyword);
      })
      .sort((a, b) => {
        if (a.status === b.status) {
          return b.priority - a.priority;
        }
        return a.status === "pending" ? -1 : 1;
      });
  }, [todos, libraryKeyword, categoryFilter]);

  const period = dashboard.period ?? {
    today: {
      sessionCount: dashboard.sessionCount,
      totalDurationSeconds: dashboard.totalDurationSeconds,
      completedTaskCount: dashboard.completedTaskCount,
      completionRate: dashboard.completionRate,
    },
    last7: EMPTY_PERIOD,
    last30: EMPTY_PERIOD,
  };

  const categoryStats = dashboard.categoryStats ?? [];
  const hourlyDistribution = dashboard.hourlyDistribution ?? [];
  const efficiency = dashboard.efficiency ?? EMPTY_EFFICIENCY;

  const loadData = useCallback(async (mode: LoadMode) => {
    if (mode === "initial") {
      setInitialLoading(true);
    } else {
      setRefreshing(true);
    }
    setError(null);

    const results = await Promise.allSettled([
      getDashboardMetrics(),
      getActiveSession(),
      listTodos(),
      getTrendData(7),
      getDistributionData(30),
    ]);

    const [dashboardResult, sessionResult, todoResult, trendResult, distributionResult] = results;

    const nextDashboard = dashboardResult.status === "fulfilled" ? dashboardResult.value : EMPTY_DASHBOARD;
    const nextSession = sessionResult.status === "fulfilled" ? sessionResult.value : null;
    const nextTodos = todoResult.status === "fulfilled" ? todoResult.value : [];
    const nextTrend = trendResult.status === "fulfilled" ? trendResult.value : [];
    const nextDistribution = distributionResult.status === "fulfilled" ? distributionResult.value : [];

    setDashboard(nextDashboard);
    setSession(nextSession);
    setTodos(nextTodos);
    setTrend(nextTrend);
    setDistribution(nextDistribution);

    const pendingIds = new Set(nextTodos.filter((todo) => todo.status === "pending").map((todo) => todo.id));

    setDraftChecks((prev) => {
      const next: Record<string, boolean> = {};
      for (const [id, checked] of Object.entries(prev)) {
        if (pendingIds.has(id)) {
          next[id] = checked;
        }
      }
      return next;
    });

    setPlannedIds((prev) => {
      if (nextSession) {
        return nextSession.tasks.map((task) => task.todoId);
      }
      return prev.filter((id) => pendingIds.has(id));
    });

    const firstRejected = results.find(
      (item): item is PromiseRejectedResult => item.status === "rejected",
    );

    if (firstRejected) {
      setError(errorToText(firstRejected.reason));
    }

    if (mode === "initial") {
      setInitialLoading(false);
    } else {
      setRefreshing(false);
    }
  }, []);

  useEffect(() => {
    void loadData("initial");
  }, [loadData]);

  async function handleTogglePlan(todoId: string) {
    if (session) {
      if (plannedIds.includes(todoId) || addingToSession) {
        return;
      }

      setAddingToSession(true);
      setError(null);
      try {
        const updated = await addTasksToSession(session.id, [todoId]);
        setSession(updated);
        setPlannedIds(updated.tasks.map((task) => task.todoId));
      } catch (toggleError) {
        setError(errorToText(toggleError));
      } finally {
        setAddingToSession(false);
      }
      return;
    }

    const exists = plannedIds.includes(todoId);
    if (exists) {
      setPlannedIds((prev) => prev.filter((id) => id !== todoId));
      setDraftChecks((prev) => {
        if (!(todoId in prev)) {
          return prev;
        }
        const next = { ...prev };
        delete next[todoId];
        return next;
      });
      return;
    }

    setPlannedIds((prev) => [...prev, todoId]);
  }

  async function handleToggleCenterTask(taskId: string, nextCompleted: boolean) {
    if (session) {
      setError(null);
      try {
        const updated = await toggleSessionTask(session.id, taskId, nextCompleted);
        setSession(updated);
        setPlannedIds(updated.tasks.map((task) => task.todoId));
      } catch (toggleError) {
        setError(errorToText(toggleError));
      }
      return;
    }

    setDraftChecks((prev) => ({ ...prev, [taskId]: nextCompleted }));
  }

  async function handleStartSession() {
    if (session || plannedTodos.length === 0 || starting) {
      return;
    }

    setStarting(true);
    setError(null);
    try {
      const created = await startSession(plannedTodos.map((todo) => todo.id));
      setSession(created);
      setPlannedIds(created.tasks.map((task) => task.todoId));
      setDraftChecks({});
      setPanel("center");
      setDrawerOpen(false);
    } catch (startError) {
      setError(errorToText(startError));
    } finally {
      setStarting(false);
    }
  }

  async function handleEndSession() {
    if (!session || ending) {
      return;
    }

    setEnding(true);
    setError(null);
    try {
      await endSession(session.id);
      await loadData("refresh");
      setPanel("down");
    } catch (endError) {
      setError(errorToText(endError));
    } finally {
      setEnding(false);
    }
  }

  async function handleCreateTask(input: CreateTaskInput) {
    if (creatingTask) {
      return;
    }

    setCreatingTask(true);
    setError(null);
    try {
      const created = await createTodo({
        title: input.title,
        subject: input.subject || null,
        notes: input.notes || null,
        category: input.category,
        tags: input.tags,
        priority: input.priority,
      });

      setTodos((prev) => [created, ...prev]);

      if (session) {
        const updated = await addTasksToSession(session.id, [created.id]);
        setSession(updated);
        setPlannedIds(updated.tasks.map((task) => task.todoId));
      } else {
        setPlannedIds((prev) => (prev.includes(created.id) ? prev : [...prev, created.id]));
      }
    } catch (createError) {
      setError(errorToText(createError));
    } finally {
      setCreatingTask(false);
    }
  }

  async function handleChangePasscode(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (changingPasscode) {
      return;
    }

    const oldPasscode = passcodeForm.oldPasscode.trim();
    const newPasscode = passcodeForm.newPasscode.trim();

    if (oldPasscode.length !== 4 || newPasscode.length !== 4) {
      setSettingsNotice("口令必须是 4 个字符。");
      return;
    }

    setChangingPasscode(true);
    setSettingsNotice(null);
    try {
      await changePasscode(oldPasscode, newPasscode);
      setPasscodeForm({ oldPasscode: "", newPasscode: "" });
      setSettingsNotice("口令已更新。下次登录请使用新口令。");
    } catch (passcodeError) {
      setSettingsNotice(errorToText(passcodeError));
    } finally {
      setChangingPasscode(false);
    }
  }

  async function handleSignOut() {
    if (signingOut) {
      return;
    }

    setSigningOut(true);
    try {
      await signOut();
      router.replace("/auth");
    } catch (signOutError) {
      setSettingsNotice(errorToText(signOutError));
      setSigningOut(false);
    }
  }

  if (initialLoading) {
    return (
      <FeedbackState
        variant="loading"
        title="加载移动画布中"
        description="正在同步任务、番茄钟和统计数据"
      />
    );
  }

  const centerPanel = (
    <div className="canvas-panel-content">
      <header className="canvas-panel-header">
        <p className="canvas-kicker">CENTER</p>
        <h1 className="page-title text-2xl font-bold text-main">番茄钟</h1>
        <p className="text-sm text-subtle">主页面：计时 + 勾选任务 + 实时进度。</p>
      </header>

      <section className="mobile-card timer-card">
        <p className="text-xs text-subtle">{session ? "专注进行中" : "尚未开始"}</p>
        <p className="timer-display page-title">{formatClock(displaySeconds)}</p>
        <div className="progress-track mt-2">
          <div className="progress-fill" style={{ width: `${progressPercent(completedCount, totalCount)}%` }} />
        </div>
        <p className="mt-2 text-xs text-subtle">
          {totalCount > 0 ? `进度 ${completedCount}/${totalCount}` : "先添加任务，再开始专注"}
        </p>
      </section>

      <section className="mobile-card task-board grow">
        <div className="mb-3 flex items-center justify-between">
          <h2 className="page-title text-lg font-bold text-main">任务清单</h2>
          <span className="progress-chip">{completedCount}/{totalCount}</span>
        </div>

        {centerTasks.length === 0 ? (
          <p className="task-empty">还没有任务，点击下方“添加任务”。</p>
        ) : (
          <div className="md-task-list">
            {centerTasks.map((task) => (
              <button
                key={task.id}
                type="button"
                className={`md-task-item ${task.completed ? "is-checked" : ""}`}
                onClick={() => void handleToggleCenterTask(task.id, !task.completed)}
                disabled={ending}
              >
                <span className={`md-task-checkbox ${task.completed ? "is-checked" : ""}`} />
                <span className="md-task-content">
                  <span className="md-task-text">{task.title}</span>
                  <span className="task-meta-muted">
                    {task.fromSession ? "已同步到本次任务钟" : "当前是计划草稿"}
                  </span>
                </span>
              </button>
            ))}
          </div>
        )}
      </section>

      <section className="center-controls">
        <button type="button" className="btn-muted h-11 px-4 text-sm" onClick={() => setDrawerOpen(true)}>
          添加任务
        </button>
        {session ? (
          <button
            type="button"
            className="btn-primary h-11 grow text-sm"
            onClick={() => void handleEndSession()}
            disabled={ending}
          >
            {ending ? "正在结束..." : "结束并记录"}
          </button>
        ) : (
          <button
            type="button"
            className="btn-primary h-11 grow text-sm"
            onClick={() => void handleStartSession()}
            disabled={plannedTodos.length === 0 || starting}
          >
            {starting ? "正在开始..." : `开始专注（${plannedTodos.length}）`}
          </button>
        )}
      </section>

      {error ? <p className="app-inline-error">{error}</p> : null}
    </div>
  );

  const rightPanel = (
    <div className="canvas-panel-content">
      <header className="canvas-panel-header">
        <p className="canvas-kicker">RIGHT</p>
        <h2 className="page-title text-2xl font-bold text-main">任务库</h2>
        <p className="text-sm text-subtle">简单罗列、基础分类、可选标签。</p>
      </header>

      <section className="mobile-card space-y-3">
        <div className="flex items-center gap-2">
          <input
            value={libraryKeyword}
            onChange={(event) => setLibraryKeyword(event.target.value)}
            className="input-base h-10"
            placeholder="搜索任务 / 分类 / 标签"
          />
          <button type="button" className="btn-muted h-10 px-3 text-xs" onClick={() => setDrawerOpen(true)}>
            新建
          </button>
        </div>

        <div className="category-chip-row">
          {categoryOptions.map((category) => (
            <button
              key={category}
              type="button"
              className={`category-chip ${categoryFilter === category ? "is-active" : ""}`}
              onClick={() => setCategoryFilter(category)}
            >
              {category}
            </button>
          ))}
        </div>
      </section>

      <section className="mobile-card grow">
        <div className="mb-2 flex items-center justify-between text-xs text-subtle">
          <span>可见任务 {libraryTodos.length}</span>
          <span>{session ? "会话中" : "计划中"} {plannedIds.length}</span>
        </div>

        {libraryTodos.length === 0 ? (
          <p className="task-empty">没有符合条件的任务。</p>
        ) : (
          <ul className="library-list">
            {libraryTodos.map((todo) => {
              const selected = plannedIds.includes(todo.id);
              const category = readCategory(todo);
              const tags = readTags(todo);

              return (
                <li key={todo.id} className="library-item">
                  <div className="min-w-0">
                    <p
                      className={`break-words text-sm ${
                        todo.status === "completed" ? "text-subtle line-through" : "text-main"
                      }`}
                    >
                      {todo.title}
                    </p>
                    <p className="mt-1 text-xs text-subtle">
                      优先级 {todo.priority}
                      {todo.subject ? ` · ${todo.subject}` : ""}
                    </p>
                    <div className="task-meta-row">
                      <span className="task-pill">{category}</span>
                      {tags.map((tag) => (
                        <span key={`${todo.id}-${tag}`} className="task-pill task-pill-tag">
                          #{tag}
                        </span>
                      ))}
                    </div>
                  </div>
                  <button
                    type="button"
                    className={selected ? "btn-primary h-9 px-3 text-xs" : "btn-muted h-9 px-3 text-xs"}
                    onClick={() => void handleTogglePlan(todo.id)}
                    disabled={todo.status !== "pending" || addingToSession || (session ? selected : false)}
                  >
                    {todo.status !== "pending"
                      ? "已完成"
                      : session
                        ? selected
                          ? "会话中"
                          : "加入"
                        : selected
                          ? "移出"
                          : "加入"}
                  </button>
                </li>
              );
            })}
          </ul>
        )}
      </section>
    </div>
  );

  const leftPanel = (
    <div className="canvas-panel-content">
      <header className="canvas-panel-header">
        <p className="canvas-kicker">LEFT</p>
        <h2 className="page-title text-2xl font-bold text-main">设置</h2>
        <p className="text-sm text-subtle">仅保留口令修改与退出登录。</p>
      </header>

      <form className="mobile-card space-y-3" onSubmit={(event) => void handleChangePasscode(event)}>
        <label className="setting-row">
          <span className="text-sm text-subtle">旧口令</span>
          <input
            type="password"
            maxLength={4}
            value={passcodeForm.oldPasscode}
            onChange={(event) =>
              setPasscodeForm((prev) => ({ ...prev, oldPasscode: event.target.value.slice(0, 4) }))
            }
            className="input-base h-10"
            placeholder="4 个字符"
            autoComplete="off"
          />
        </label>

        <label className="setting-row">
          <span className="text-sm text-subtle">新口令</span>
          <input
            type="password"
            maxLength={4}
            value={passcodeForm.newPasscode}
            onChange={(event) =>
              setPasscodeForm((prev) => ({ ...prev, newPasscode: event.target.value.slice(0, 4) }))
            }
            className="input-base h-10"
            placeholder="4 个字符"
            autoComplete="off"
          />
        </label>

        <button type="submit" className="btn-primary h-11 w-full text-sm" disabled={changingPasscode}>
          {changingPasscode ? "修改中..." : "修改口令"}
        </button>
      </form>

      <section className="mobile-card">
        <button
          type="button"
          className="btn-danger h-11 w-full text-sm"
          onClick={() => void handleSignOut()}
          disabled={signingOut}
        >
          {signingOut ? "退出中..." : "退出登录"}
        </button>
      </section>

      {settingsNotice ? <p className="app-inline-note">{settingsNotice}</p> : null}
    </div>
  );

  const maxCategorySeconds = Math.max(1, ...categoryStats.map((item) => item.totalDurationSeconds));
  const maxHourlySeconds = Math.max(1, ...hourlyDistribution.map((item) => item.totalDurationSeconds));

  const downPanel = (
    <div className="canvas-panel-content">
      <header className="canvas-panel-header">
        <div>
          <p className="canvas-kicker">DOWN</p>
          <h2 className="page-title text-2xl font-bold text-main">统计</h2>
          <p className="text-sm text-subtle">时间、个数、效率、分类、时段全量视图。</p>
        </div>
        <button
          type="button"
          className="btn-muted h-9 px-3 text-xs"
          onClick={() => void loadData("refresh")}
          disabled={refreshing}
        >
          {refreshing ? "刷新中..." : "刷新"}
        </button>
      </header>

      <section className="analytics-grid">
        <article className="mobile-card p-4">
          <p className="text-xs text-subtle">今日任务钟</p>
          <p className="page-title mt-2 text-2xl font-bold text-main">{period.today.sessionCount}</p>
        </article>
        <article className="mobile-card p-4">
          <p className="text-xs text-subtle">今日完成任务</p>
          <p className="page-title mt-2 text-2xl font-bold text-main">{period.today.completedTaskCount}</p>
        </article>
        <article className="mobile-card p-4">
          <p className="text-xs text-subtle">今日时长</p>
          <p className="page-title mt-2 text-lg font-bold text-main">{formatDuration(period.today.totalDurationSeconds)}</p>
        </article>
        <article className="mobile-card p-4">
          <p className="text-xs text-subtle">今日完成率 / 连续天数</p>
          <p className="page-title mt-2 text-lg font-bold text-main">
            {Math.round(period.today.completionRate)}% · {dashboard.streakDays} 天
          </p>
        </article>
      </section>

      <section className="mobile-card">
        <h3 className="page-title text-lg font-bold text-main">周期视角</h3>
        <div className="period-grid mt-3">
          <article className="panel-solid p-3">
            <p className="text-xs text-subtle">近 7 天</p>
            <p className="mt-2 text-sm text-main">任务钟 {period.last7.sessionCount}</p>
            <p className="text-sm text-main">完成率 {Math.round(period.last7.completionRate)}%</p>
            <p className="text-xs text-subtle">{formatDuration(period.last7.totalDurationSeconds)}</p>
          </article>
          <article className="panel-solid p-3">
            <p className="text-xs text-subtle">近 30 天</p>
            <p className="mt-2 text-sm text-main">任务钟 {period.last30.sessionCount}</p>
            <p className="text-sm text-main">完成率 {Math.round(period.last30.completionRate)}%</p>
            <p className="text-xs text-subtle">{formatDuration(period.last30.totalDurationSeconds)}</p>
          </article>
        </div>
      </section>

      <section className="mobile-card">
        <h3 className="page-title text-lg font-bold text-main">效率视角</h3>
        <div className="mt-3 grid grid-cols-3 gap-2 text-center">
          <div className="panel-solid p-3">
            <p className="text-[11px] text-subtle">每小时完成</p>
            <p className="mt-1 text-sm font-semibold text-main">{efficiency.tasksPerHour}</p>
          </div>
          <div className="panel-solid p-3">
            <p className="text-[11px] text-subtle">平均完成率</p>
            <p className="mt-1 text-sm font-semibold text-main">{Math.round(efficiency.avgCompletionRate)}%</p>
          </div>
          <div className="panel-solid p-3">
            <p className="text-[11px] text-subtle">平均单钟时长</p>
            <p className="mt-1 text-sm font-semibold text-main">{formatDuration(efficiency.avgSessionDurationSeconds)}</p>
          </div>
        </div>
        <p className="mt-3 text-xs text-subtle">
          与前一周期对比：
          任务钟 {efficiency.periodDelta.sessionCount >= 0 ? "+" : ""}{efficiency.periodDelta.sessionCount}，
          时长 {efficiency.periodDelta.totalDurationSeconds >= 0 ? "+" : ""}{formatDuration(Math.abs(efficiency.periodDelta.totalDurationSeconds))}，
          完成率 {efficiency.periodDelta.completionRate >= 0 ? "+" : ""}{efficiency.periodDelta.completionRate}%
        </p>
      </section>

      <section className="mobile-card">
        <h3 className="page-title text-lg font-bold text-main">分类贡献</h3>
        {categoryStats.length === 0 ? (
          <p className="task-empty">暂无分类统计数据。</p>
        ) : (
          <div className="mt-3 space-y-3">
            {categoryStats.map((item) => {
              const width = (item.totalDurationSeconds / maxCategorySeconds) * 100;
              return (
                <div key={item.category}>
                  <div className="mb-1 flex items-center justify-between text-xs">
                    <span className="text-main">{item.category}</span>
                    <span className="text-subtle">
                      {item.completedCount}/{item.taskCount} · {Math.round(item.completionRate)}%
                    </span>
                  </div>
                  <div className="h-2 rounded-full bg-[rgba(148,163,184,0.2)]">
                    <div
                      className="h-full rounded-full bg-gradient-to-r from-sky-400 to-cyan-300"
                      style={{ width: `${Math.max(6, width)}%` }}
                    />
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </section>

      <section className="mobile-card">
        <h3 className="page-title text-lg font-bold text-main">时段分布（UTC）</h3>
        {hourlyDistribution.length === 0 ? (
          <p className="task-empty">暂无时段数据。</p>
        ) : (
          <div className="mt-3 grid grid-cols-2 gap-2">
            {hourlyDistribution.map((item: HourlyStatsItem) => {
              const width = (item.totalDurationSeconds / maxHourlySeconds) * 100;
              return (
                <div key={item.hour} className="panel-solid p-2">
                  <div className="flex items-center justify-between text-[11px] text-subtle">
                    <span>{String(item.hour).padStart(2, "0")}:00</span>
                    <span>{item.sessionCount} 次</span>
                  </div>
                  <div className="mt-1 h-1.5 rounded-full bg-[rgba(148,163,184,0.2)]">
                    <div
                      className="h-full rounded-full bg-gradient-to-r from-orange-400 to-amber-300"
                      style={{ width: `${Math.max(4, width)}%` }}
                    />
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </section>

      <section className="mobile-card">
        <h3 className="page-title text-lg font-bold text-main">7 天趋势</h3>
        <p className="mt-1 text-xs text-subtle">按日统计总专注时长</p>
        <div className="mt-3">
          <TrendChart points={trend} />
        </div>
      </section>

      <section className="mobile-card">
        <h3 className="page-title text-lg font-bold text-main">30 天分布</h3>
        <p className="mt-1 text-xs text-subtle">按时长区间统计任务钟</p>
        <div className="mt-3">
          <DistributionChart buckets={distribution} />
        </div>
      </section>
    </div>
  );

  return (
    <div className="mobile-page">
      <section className="mobile-phone-frame">
        <AppCanvas panel={panel} onPanelChange={setPanel} center={centerPanel} left={leftPanel} right={rightPanel} down={downPanel} />
        <TaskPickerDrawer
          open={drawerOpen}
          todos={pendingTodos}
          selectedIds={plannedIds}
          creating={creatingTask}
          sessionActive={Boolean(session)}
          onClose={() => setDrawerOpen(false)}
          onToggleTodo={handleTogglePlan}
          onCreateTodo={handleCreateTask}
        />
      </section>
    </div>
  );
}

