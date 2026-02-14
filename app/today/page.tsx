"use client";

import { FormEvent, useCallback, useEffect, useMemo, useState } from "react";
import { DistributionChart } from "@/components/charts/distribution-chart";
import { TrendChart } from "@/components/charts/trend-chart";
import { FeedbackState } from "@/components/feedback-state";
import { AppCanvas, type CanvasPanel } from "@/components/mobile/app-canvas";
import { TaskPickerDrawer, type CreateTaskInput } from "@/components/mobile/task-picker-drawer";
import { useElapsedSeconds } from "@/hooks/use-elapsed-seconds";
import { ApiClientError } from "@/lib/client/api-client";
import {
  addTasksToSession,
  createTodo,
  endSession,
  getActiveSession,
  getDashboardMetrics,
  getDistributionData,
  getTrendData,
  listTodos,
  startSession,
  toggleSessionTask,
  updateTodo,
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
type MetaTab = "category" | "tag";

type DisplayTask = {
  id: string;
  title: string;
  completed: boolean;
  fromSession: boolean;
};

const DEFAULT_CATEGORY = "未分类";
const CATEGORY_REGISTRY_KEY = "pomlist.meta.categories";
const TAG_REGISTRY_KEY = "pomlist.meta.tags";

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
  return DEFAULT_CATEGORY;
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

function mergeUniqueValues(input: string[]): string[] {
  const seen = new Set<string>();
  const result: string[] = [];
  for (const item of input) {
    const value = item.trim();
    if (!value || seen.has(value)) {
      continue;
    }
    seen.add(value);
    result.push(value);
  }
  return result;
}

function parseStoredMeta(raw: string | null): string[] {
  if (!raw) {
    return [];
  }
  try {
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) {
      return [];
    }
    return mergeUniqueValues(parsed.filter((item): item is string => typeof item === "string"));
  } catch {
    return [];
  }
}

export default function TodayPage() {
  const [panel, setPanel] = useState<CanvasPanel>("center");
  const [drawerOpen, setDrawerOpen] = useState(false);

  const [initialLoading, setInitialLoading] = useState(true);
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

  const [categoryRegistry, setCategoryRegistry] = useState<string[]>([]);
  const [tagRegistry, setTagRegistry] = useState<string[]>([]);

  const [metaManagerOpen, setMetaManagerOpen] = useState(false);
  const [metaTab, setMetaTab] = useState<MetaTab>("category");
  const [metaSaving, setMetaSaving] = useState(false);
  const [metaNotice, setMetaNotice] = useState<string | null>(null);
  const [newCategoryName, setNewCategoryName] = useState("");
  const [newTagName, setNewTagName] = useState("");
  const [editingCategory, setEditingCategory] = useState<string | null>(null);
  const [editingCategoryName, setEditingCategoryName] = useState("");
  const [editingTag, setEditingTag] = useState<string | null>(null);
  const [editingTagName, setEditingTagName] = useState("");

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

  useEffect(() => {
    if (typeof window === "undefined") {
      return;
    }
    setCategoryRegistry(parseStoredMeta(window.localStorage.getItem(CATEGORY_REGISTRY_KEY)));
    setTagRegistry(parseStoredMeta(window.localStorage.getItem(TAG_REGISTRY_KEY)));
  }, []);

  useEffect(() => {
    if (typeof window === "undefined") {
      return;
    }
    window.localStorage.setItem(CATEGORY_REGISTRY_KEY, JSON.stringify(categoryRegistry));
  }, [categoryRegistry]);

  useEffect(() => {
    if (typeof window === "undefined") {
      return;
    }
    window.localStorage.setItem(TAG_REGISTRY_KEY, JSON.stringify(tagRegistry));
  }, [tagRegistry]);

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
    const values = new Set<string>([DEFAULT_CATEGORY]);
    for (const todo of todos) {
      if (todo.status !== "archived") {
        values.add(readCategory(todo));
      }
    }
    for (const category of categoryRegistry) {
      values.add(category);
    }
    return Array.from(values).sort((a, b) => a.localeCompare(b, "zh-CN"));
  }, [todos, categoryRegistry]);

  const tagOptions = useMemo(() => {
    const values = new Set<string>();
    for (const todo of todos) {
      if (todo.status === "archived") {
        continue;
      }
      for (const tag of readTags(todo)) {
        values.add(tag);
      }
    }
    for (const tag of tagRegistry) {
      values.add(tag);
    }
    return Array.from(values).sort((a, b) => a.localeCompare(b, "zh-CN"));
  }, [todos, tagRegistry]);

  const libraryTodos = useMemo(() => {
    return todos
      .filter((todo) => todo.status !== "archived")
      .sort((a, b) => {
        if (a.status === b.status) {
          return 0;
        }
        return a.status === "pending" ? -1 : 1;
      });
  }, [todos]);

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
    }
  }, []);

  useEffect(() => {
    void loadData("initial");
  }, [loadData]);

  const runMetaMutation = useCallback(
    async (mutation: () => Promise<void>): Promise<boolean> => {
      if (metaSaving) {
        return false;
      }

      setMetaSaving(true);
      setMetaNotice(null);
      try {
        await mutation();
        await loadData("refresh");
        return true;
      } catch (mutationError) {
        setMetaNotice(errorToText(mutationError));
        return false;
      } finally {
        setMetaSaving(false);
      }
    },
    [loadData, metaSaving],
  );

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
        category: input.category,
        tags: input.tags,
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

  function handleAddCategory(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const value = newCategoryName.trim();
    if (!value) {
      return;
    }
    if (categoryOptions.includes(value)) {
      setMetaNotice("分类已存在。");
      return;
    }
    setCategoryRegistry((prev) => mergeUniqueValues([...prev, value]));
    setNewCategoryName("");
    setMetaNotice("已新增分类。");
  }

  function handleAddTag(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const value = newTagName.trim();
    if (!value) {
      return;
    }
    if (tagOptions.includes(value)) {
      setMetaNotice("标签已存在。");
      return;
    }
    setTagRegistry((prev) => mergeUniqueValues([...prev, value]));
    setNewTagName("");
    setMetaNotice("已新增标签。");
  }

  async function handleRenameCategory(source: string, target: string) {
    const nextName = target.trim();
    if (!nextName) {
      setMetaNotice("分类不能为空。");
      return;
    }
    if (nextName === source) {
      setEditingCategory(null);
      setEditingCategoryName("");
      return;
    }

    const ok = await runMetaMutation(async () => {
      const affected = todos.filter((todo) => readCategory(todo) === source);
      if (affected.length > 0) {
        await Promise.all(affected.map((todo) => updateTodo(todo.id, { category: nextName })));
      }
      setCategoryRegistry((prev) => mergeUniqueValues([...prev.filter((item) => item !== source), nextName]));
    });

    if (ok) {
      setEditingCategory(null);
      setEditingCategoryName("");
      setMetaNotice(`已将分类“${source}”改为“${nextName}”。`);
    }
  }

  async function handleDeleteCategory(category: string) {
    if (category === DEFAULT_CATEGORY) {
      setMetaNotice("默认分类不能删除。");
      return;
    }

    const ok = await runMetaMutation(async () => {
      const affected = todos.filter((todo) => readCategory(todo) === category);
      if (affected.length > 0) {
        await Promise.all(affected.map((todo) => updateTodo(todo.id, { category: DEFAULT_CATEGORY })));
      }
      setCategoryRegistry((prev) => prev.filter((item) => item !== category));
    });

    if (ok) {
      if (editingCategory === category) {
        setEditingCategory(null);
        setEditingCategoryName("");
      }
      setMetaNotice(`已删除分类“${category}”。`);
    }
  }

  async function handleRenameTag(source: string, target: string) {
    const nextName = target.trim();
    if (!nextName) {
      setMetaNotice("标签不能为空。");
      return;
    }
    if (nextName === source) {
      setEditingTag(null);
      setEditingTagName("");
      return;
    }

    const ok = await runMetaMutation(async () => {
      const affected = todos.filter((todo) => readTags(todo).includes(source));
      if (affected.length > 0) {
        await Promise.all(
          affected.map(async (todo) => {
            const nextTags = mergeUniqueValues(
              readTags(todo).map((tag) => (tag === source ? nextName : tag)),
            );
            await updateTodo(todo.id, { tags: nextTags });
          }),
        );
      }
      setTagRegistry((prev) => mergeUniqueValues([...prev.filter((item) => item !== source), nextName]));
    });

    if (ok) {
      setEditingTag(null);
      setEditingTagName("");
      setMetaNotice(`已将标签“${source}”改为“${nextName}”。`);
    }
  }

  async function handleDeleteTag(tag: string) {
    const ok = await runMetaMutation(async () => {
      const affected = todos.filter((todo) => readTags(todo).includes(tag));
      if (affected.length > 0) {
        await Promise.all(
          affected.map(async (todo) => {
            const nextTags = readTags(todo).filter((item) => item !== tag);
            await updateTodo(todo.id, { tags: nextTags });
          }),
        );
      }
      setTagRegistry((prev) => prev.filter((item) => item !== tag));
    });

    if (ok) {
      if (editingTag === tag) {
        setEditingTag(null);
        setEditingTagName("");
      }
      setMetaNotice(`已删除标签“${tag}”。`);
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
        <h1 className="page-title text-2xl font-bold text-main">Pomlist</h1>
      </header>

      <section className="mobile-card timer-card">
        <p className="timer-display page-title">{formatClock(displaySeconds)}</p>
        <div className="progress-track mt-2">
          <div className="progress-fill" style={{ width: `${progressPercent(completedCount, totalCount)}%` }} />
        </div>
        {totalCount > 0 ? (
          <p className="mt-2 text-xs text-subtle">
            {completedCount}/{totalCount}
          </p>
        ) : null}
      </section>

      <section className="mobile-card task-board grow">
        <div className="mb-3 flex items-center justify-between">
          <h2 className="page-title text-lg font-bold text-main">任务</h2>
          <span className="progress-chip">
            {completedCount}/{totalCount}
          </span>
        </div>

        {centerTasks.length === 0 ? null : (
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
        <h2 className="page-title text-2xl font-bold text-main">Task</h2>
        <div className="flex items-center gap-2">
          <button
            type="button"
            className="btn-muted h-9 px-3 text-xs"
            onClick={() => {
              setMetaManagerOpen(true);
              setMetaTab("category");
              setMetaNotice(null);
            }}
          >
            管理
          </button>
          <button type="button" className="btn-primary h-9 px-3 text-xs" onClick={() => setDrawerOpen(true)}>
            新建
          </button>
        </div>
      </header>

      <section className="mobile-card grow">
        <div className="mb-2 flex items-center justify-between text-xs text-subtle">
          <span>可见任务 {libraryTodos.length}</span>
          <span>
            {session ? "会话中" : "计划中"} {plannedIds.length}
          </span>
        </div>

        {libraryTodos.length === 0 ? null : (
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
                    <div className="task-meta-row mt-2">
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
      {metaManagerOpen ? (
        <div
          className="meta-manager-backdrop"
          onClick={() => {
            if (!metaSaving) {
              setMetaManagerOpen(false);
            }
          }}
          aria-hidden={!metaManagerOpen}
        >
          <aside className="meta-manager-sheet" onClick={(event) => event.stopPropagation()}>
            <header className="meta-manager-header">
              <h3 className="page-title text-lg font-bold text-main">管理分类与标签</h3>
              <button
                type="button"
                className="btn-muted h-8 px-3 text-xs"
                onClick={() => setMetaManagerOpen(false)}
                disabled={metaSaving}
              >
                关闭
              </button>
            </header>

            <div className="meta-manager-tabs">
              <button
                type="button"
                className={`meta-manager-tab ${metaTab === "category" ? "is-active" : ""}`}
                onClick={() => {
                  setMetaTab("category");
                  setMetaNotice(null);
                }}
                disabled={metaSaving}
              >
                分类
              </button>
              <button
                type="button"
                className={`meta-manager-tab ${metaTab === "tag" ? "is-active" : ""}`}
                onClick={() => {
                  setMetaTab("tag");
                  setMetaNotice(null);
                }}
                disabled={metaSaving}
              >
                标签
              </button>
            </div>

            {metaTab === "category" ? (
              <div className="meta-manager-body">
                <form className="meta-manager-create" onSubmit={handleAddCategory}>
                  <input
                    value={newCategoryName}
                    onChange={(event) => setNewCategoryName(event.target.value)}
                    className="input-base h-10"
                    placeholder="新增分类"
                    disabled={metaSaving}
                  />
                  <button type="submit" className="btn-primary h-10 px-3 text-xs" disabled={metaSaving}>
                    新增
                  </button>
                </form>

                <div className="meta-manager-list">
                  {categoryOptions.map((category) => (
                    <article key={category} className="meta-manager-row">
                      {editingCategory === category ? (
                        <div className="meta-manager-row-editor">
                          <input
                            value={editingCategoryName}
                            onChange={(event) => setEditingCategoryName(event.target.value)}
                            className="input-base h-9"
                            disabled={metaSaving}
                          />
                          <button
                            type="button"
                            className="btn-primary h-9 px-3 text-xs"
                            onClick={() => void handleRenameCategory(category, editingCategoryName)}
                            disabled={metaSaving}
                          >
                            保存
                          </button>
                          <button
                            type="button"
                            className="btn-muted h-9 px-3 text-xs"
                            onClick={() => {
                              setEditingCategory(null);
                              setEditingCategoryName("");
                            }}
                            disabled={metaSaving}
                          >
                            取消
                          </button>
                        </div>
                      ) : (
                        <div className="meta-manager-row-main">
                          <span className="meta-manager-name">{category}</span>
                          <div className="meta-manager-row-actions">
                            <button
                              type="button"
                              className="btn-muted h-8 px-3 text-xs"
                              onClick={() => {
                                setEditingCategory(category);
                                setEditingCategoryName(category);
                                setMetaNotice(null);
                              }}
                              disabled={metaSaving}
                            >
                              重命名
                            </button>
                            <button
                              type="button"
                              className="btn-danger h-8 px-3 text-xs"
                              onClick={() => void handleDeleteCategory(category)}
                              disabled={metaSaving || category === DEFAULT_CATEGORY}
                            >
                              删除
                            </button>
                          </div>
                        </div>
                      )}
                    </article>
                  ))}
                </div>
              </div>
            ) : (
              <div className="meta-manager-body">
                <form className="meta-manager-create" onSubmit={handleAddTag}>
                  <input
                    value={newTagName}
                    onChange={(event) => setNewTagName(event.target.value)}
                    className="input-base h-10"
                    placeholder="新增标签"
                    disabled={metaSaving}
                  />
                  <button type="submit" className="btn-primary h-10 px-3 text-xs" disabled={metaSaving}>
                    新增
                  </button>
                </form>

                <div className="meta-manager-list">
                  {tagOptions.map((tag) => (
                    <article key={tag} className="meta-manager-row">
                      {editingTag === tag ? (
                        <div className="meta-manager-row-editor">
                          <input
                            value={editingTagName}
                            onChange={(event) => setEditingTagName(event.target.value)}
                            className="input-base h-9"
                            disabled={metaSaving}
                          />
                          <button
                            type="button"
                            className="btn-primary h-9 px-3 text-xs"
                            onClick={() => void handleRenameTag(tag, editingTagName)}
                            disabled={metaSaving}
                          >
                            保存
                          </button>
                          <button
                            type="button"
                            className="btn-muted h-9 px-3 text-xs"
                            onClick={() => {
                              setEditingTag(null);
                              setEditingTagName("");
                            }}
                            disabled={metaSaving}
                          >
                            取消
                          </button>
                        </div>
                      ) : (
                        <div className="meta-manager-row-main">
                          <span className="meta-manager-name">#{tag}</span>
                          <div className="meta-manager-row-actions">
                            <button
                              type="button"
                              className="btn-muted h-8 px-3 text-xs"
                              onClick={() => {
                                setEditingTag(tag);
                                setEditingTagName(tag);
                                setMetaNotice(null);
                              }}
                              disabled={metaSaving}
                            >
                              重命名
                            </button>
                            <button
                              type="button"
                              className="btn-danger h-8 px-3 text-xs"
                              onClick={() => void handleDeleteTag(tag)}
                              disabled={metaSaving}
                            >
                              删除
                            </button>
                          </div>
                        </div>
                      )}
                    </article>
                  ))}
                </div>
              </div>
            )}

            {metaNotice ? <p className="app-inline-note">{metaNotice}</p> : null}
          </aside>
        </div>
      ) : null}
    </div>
  );

  const maxCategorySeconds = Math.max(1, ...categoryStats.map((item) => item.totalDurationSeconds));
  const maxHourlySeconds = Math.max(1, ...hourlyDistribution.map((item) => item.totalDurationSeconds));

  const downPanel = (
    <div className="canvas-panel-content">
      <header className="canvas-panel-header">
        <h2 className="page-title text-2xl font-bold text-main">Statistic</h2>
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
          与前一周期对比：任务钟 {efficiency.periodDelta.sessionCount >= 0 ? "+" : ""}
          {efficiency.periodDelta.sessionCount}，时长 {efficiency.periodDelta.totalDurationSeconds >= 0 ? "+" : ""}
          {formatDuration(Math.abs(efficiency.periodDelta.totalDurationSeconds))}，完成率{" "}
          {efficiency.periodDelta.completionRate >= 0 ? "+" : ""}
          {efficiency.periodDelta.completionRate}%
        </p>
      </section>

      <section className="mobile-card">
        <h3 className="page-title text-lg font-bold text-main">分类贡献</h3>
        {categoryStats.length === 0 ? null : (
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
        {hourlyDistribution.length === 0 ? null : (
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
        <div className="mt-3">
          <TrendChart points={trend} />
        </div>
      </section>

      <section className="mobile-card">
        <h3 className="page-title text-lg font-bold text-main">30 天分布</h3>
        <div className="mt-3">
          <DistributionChart buckets={distribution} />
        </div>
      </section>
    </div>
  );

  return (
    <div className="mobile-page">
      <section className="mobile-phone-frame">
        <AppCanvas panel={panel} onPanelChange={setPanel} center={centerPanel} right={rightPanel} down={downPanel} />
        <TaskPickerDrawer
          open={drawerOpen}
          todos={pendingTodos}
          selectedIds={plannedIds}
          categoryOptions={categoryOptions}
          tagOptions={tagOptions}
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
