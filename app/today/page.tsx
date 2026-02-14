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
  deleteTodo,
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

type DisplayTask = {
  id: string;
  title: string;
  completed: boolean;
};

const DEFAULT_CATEGORY = "未分类";
const DEFAULT_PRIMARY_TAG = "未标签";
const TAG_REGISTRY_KEY = "pomlist.meta.tags";
const TAG_COLOR_REGISTRY_KEY = "pomlist.meta.tag-colors";
const COMMON_TAG_COLORS = ["#1d4ed8", "#2563eb", "#3b82f6", "#60a5fa", "#0ea5e9", "#06b6d4", "#38bdf8", "#6366f1"];
const DEFAULT_TAG_COLOR = COMMON_TAG_COLORS[0];

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

function readLegacyCategory(todo: TodoItem): string | null {
  const raw = (todo as TodoItem & { category?: unknown }).category;
  if (typeof raw !== "string") {
    return null;
  }
  const value = raw.trim();
  if (!value || value === DEFAULT_CATEGORY) {
    return null;
  }
  return value;
}

function normalizeTagLevels(input: string[]): string[] {
  return mergeUniqueValues(input).slice(0, 2);
}

function readTagLevels(todo: TodoItem): string[] {
  const raw = (todo as TodoItem & { tags?: unknown }).tags;
  if (Array.isArray(raw)) {
    const tags = normalizeTagLevels(raw.filter((item): item is string => typeof item === "string"));
    if (tags.length > 0) {
      return tags;
    }
  }

  const fallback = readLegacyCategory(todo);
  return fallback ? [fallback] : [];
}

function readContent(todo: TodoItem): string {
  const raw = (todo as TodoItem & { notes?: unknown }).notes;
  return typeof raw === "string" ? raw : "";
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

function normalizeHexColor(input: unknown): string | null {
  if (typeof input !== "string") {
    return null;
  }
  const value = input.trim();
  if (!/^#[0-9a-fA-F]{6}$/.test(value)) {
    return null;
  }
  return value.toLowerCase();
}

function parseStoredColorMap(raw: string | null): Record<string, string> {
  if (!raw) {
    return {};
  }
  try {
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      return {};
    }
    const result: Record<string, string> = {};
    for (const [key, value] of Object.entries(parsed)) {
      const name = key.trim();
      const color = normalizeHexColor(value);
      if (!name || !color) {
        continue;
      }
      result[name] = color;
    }
    return result;
  } catch {
    return {};
  }
}

function hexToRgba(hex: string, alpha: number): string {
  const normalized = normalizeHexColor(hex) ?? DEFAULT_TAG_COLOR;
  const r = Number.parseInt(normalized.slice(1, 3), 16);
  const g = Number.parseInt(normalized.slice(3, 5), 16);
  const b = Number.parseInt(normalized.slice(5, 7), 16);
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

function tagPillStyle(color: string) {
  return {
    color,
    borderColor: hexToRgba(color, 0.55),
    background: hexToRgba(color, 0.2),
  };
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

  const [tagRegistry, setTagRegistry] = useState<string[]>([]);
  const [tagColorMap, setTagColorMap] = useState<Record<string, string>>({});

  const [metaManagerOpen, setMetaManagerOpen] = useState(false);
  const [metaSaving, setMetaSaving] = useState(false);
  const [metaNotice, setMetaNotice] = useState<string | null>(null);
  const [newTagName, setNewTagName] = useState("");
  const [newTagColor, setNewTagColor] = useState(DEFAULT_TAG_COLOR);
  const [editingTag, setEditingTag] = useState<string | null>(null);
  const [editingTagName, setEditingTagName] = useState("");
  const [taskEditorOpen, setTaskEditorOpen] = useState(false);
  const [taskEditorTodoId, setTaskEditorTodoId] = useState<string | null>(null);
  const [taskEditorTodoTitle, setTaskEditorTodoTitle] = useState("");
  const [taskEditorPrimaryTag, setTaskEditorPrimaryTag] = useState("");
  const [taskEditorSecondaryTag, setTaskEditorSecondaryTag] = useState("");
  const [taskEditorContent, setTaskEditorContent] = useState("");
  const [taskEditorSaving, setTaskEditorSaving] = useState(false);
  const [taskEditorDeleting, setTaskEditorDeleting] = useState(false);
  const [taskEditorNotice, setTaskEditorNotice] = useState<string | null>(null);

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
    setTagRegistry(parseStoredMeta(window.localStorage.getItem(TAG_REGISTRY_KEY)));
    setTagColorMap(parseStoredColorMap(window.localStorage.getItem(TAG_COLOR_REGISTRY_KEY)));
  }, []);

  useEffect(() => {
    if (typeof window === "undefined") {
      return;
    }
    window.localStorage.setItem(TAG_REGISTRY_KEY, JSON.stringify(tagRegistry));
  }, [tagRegistry]);

  useEffect(() => {
    if (typeof window === "undefined") {
      return;
    }
    window.localStorage.setItem(TAG_COLOR_REGISTRY_KEY, JSON.stringify(tagColorMap));
  }, [tagColorMap]);

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
      }));
    }

    return plannedTodos.map((todo) => ({
      id: todo.id,
      title: todo.title,
      completed: Boolean(draftChecks[todo.id]),
    }));
  }, [session, plannedTodos, draftChecks]);

  const completedCount = useMemo(() => centerTasks.filter((task) => task.completed).length, [centerTasks]);
  const totalCount = centerTasks.length;

  const tagOptions = useMemo(() => {
    const values = new Set<string>();
    for (const todo of todos) {
      if (todo.status === "archived") {
        continue;
      }
      for (const tag of readTagLevels(todo)) {
        values.add(tag);
      }
    }
    for (const tag of tagRegistry) {
      values.add(tag);
    }
    return Array.from(values).sort((a, b) => a.localeCompare(b, "zh-CN"));
  }, [todos, tagRegistry]);

  const taskEditorPrimarySuggestions = useMemo(
    () => tagOptions.filter((item) => item !== taskEditorSecondaryTag).slice(0, 8),
    [tagOptions, taskEditorSecondaryTag],
  );

  const taskEditorSecondarySuggestions = useMemo(
    () => tagOptions.filter((item) => item !== taskEditorPrimaryTag).slice(0, 8),
    [tagOptions, taskEditorPrimaryTag],
  );

  const getTagColor = useCallback(
    (tag: string) => normalizeHexColor(tagColorMap[tag]) ?? DEFAULT_TAG_COLOR,
    [tagColorMap],
  );

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
      const nextTags = normalizeTagLevels(input.tags);
      const created = await createTodo({
        title: input.title,
        category: nextTags[0] ?? DEFAULT_CATEGORY,
        tags: nextTags,
        notes: input.content || null,
      });

      setTodos((prev) => [created, ...prev]);
      setTagRegistry((prev) => mergeUniqueValues([...prev, ...nextTags]));
      if (nextTags[0]) {
        setTagColorMap((prev) => {
          if (normalizeHexColor(prev[nextTags[0]!])) {
            return prev;
          }
          return { ...prev, [nextTags[0]!]: DEFAULT_TAG_COLOR };
        });
      }

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

  function openTaskEditor(todo: TodoItem) {
    const levels = readTagLevels(todo);
    setTaskEditorTodoId(todo.id);
    setTaskEditorTodoTitle(todo.title);
    setTaskEditorPrimaryTag(levels[0] ?? "");
    setTaskEditorSecondaryTag(levels[1] ?? "");
    setTaskEditorContent(readContent(todo));
    setTaskEditorNotice(null);
    setTaskEditorOpen(true);
  }

  function closeTaskEditor() {
    if (taskEditorSaving || taskEditorDeleting) {
      return;
    }
    setTaskEditorOpen(false);
  }

  async function handleSaveTaskEditor() {
    if (!taskEditorTodoId || taskEditorSaving || taskEditorDeleting) {
      return;
    }

    const nextTags = normalizeTagLevels([taskEditorPrimaryTag, taskEditorSecondaryTag]);
    const nextContent = taskEditorContent.trim();

    setTaskEditorSaving(true);
    setTaskEditorNotice(null);
    setError(null);
    try {
      const updated = await updateTodo(taskEditorTodoId, {
        category: nextTags[0] ?? DEFAULT_CATEGORY,
        tags: nextTags,
        notes: nextContent || null,
      });
      setTodos((prev) => prev.map((todo) => (todo.id === updated.id ? updated : todo)));
      setTagRegistry((prev) => mergeUniqueValues([...prev, ...nextTags]));
      if (nextTags[0]) {
        setTagColorMap((prev) => {
          if (normalizeHexColor(prev[nextTags[0]!])) {
            return prev;
          }
          return { ...prev, [nextTags[0]!]: DEFAULT_TAG_COLOR };
        });
      }
      setTaskEditorPrimaryTag(nextTags[0] ?? "");
      setTaskEditorSecondaryTag(nextTags[1] ?? "");
      setTaskEditorNotice("已保存任务信息。");
    } catch (saveError) {
      setTaskEditorNotice(errorToText(saveError));
    } finally {
      setTaskEditorSaving(false);
    }
  }

  async function handleDeleteTaskFromEditor() {
    if (!taskEditorTodoId || taskEditorSaving || taskEditorDeleting) {
      return;
    }

    setTaskEditorDeleting(true);
    setTaskEditorNotice(null);
    setError(null);
    try {
      await deleteTodo(taskEditorTodoId);
      setTaskEditorOpen(false);
      await loadData("refresh");
    } catch (deleteError) {
      setTaskEditorNotice(errorToText(deleteError));
    } finally {
      setTaskEditorDeleting(false);
    }
  }

  function handleUpdateTagColor(tag: string, color: string) {
    const normalized = normalizeHexColor(color);
    if (!normalized) {
      return;
    }
    setTagColorMap((prev) => ({ ...prev, [tag]: normalized }));
  }

  function handleAddTag(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const value = newTagName.trim();
    const color = normalizeHexColor(newTagColor) ?? DEFAULT_TAG_COLOR;
    if (!value) {
      return;
    }
    if (tagOptions.includes(value)) {
      setMetaNotice("标签已存在。");
      return;
    }
    setTagRegistry((prev) => mergeUniqueValues([...prev, value]));
    setTagColorMap((prev) => ({ ...prev, [value]: color }));
    setNewTagName("");
    setMetaNotice("已新增标签。");
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
    if (tagOptions.includes(nextName)) {
      setMetaNotice("标签已存在。");
      return;
    }

    const ok = await runMetaMutation(async () => {
      const affected = todos.filter((todo) => readTagLevels(todo).includes(source));
      if (affected.length > 0) {
        await Promise.all(
          affected.map(async (todo) => {
            const nextTags = normalizeTagLevels(readTagLevels(todo).map((tag) => (tag === source ? nextName : tag)));
            await updateTodo(todo.id, {
              category: nextTags[0] ?? DEFAULT_CATEGORY,
              tags: nextTags,
            });
          }),
        );
      }
      setTagRegistry((prev) => mergeUniqueValues([...prev.filter((item) => item !== source), nextName]));
      setTagColorMap((prev) => {
        const next = { ...prev };
        const sourceColor = normalizeHexColor(next[source]);
        delete next[source];
        next[nextName] = sourceColor ?? DEFAULT_TAG_COLOR;
        return next;
      });
    });

    if (ok) {
      setEditingTag(null);
      setEditingTagName("");
      setMetaNotice(`已将标签“${source}”改为“${nextName}”。`);
    }
  }

  async function handleDeleteTag(tag: string) {
    const ok = await runMetaMutation(async () => {
      const affected = todos.filter((todo) => readTagLevels(todo).includes(tag));
      if (affected.length > 0) {
        await Promise.all(
          affected.map(async (todo) => {
            const nextTags = normalizeTagLevels(readTagLevels(todo).filter((item) => item !== tag));
            await updateTodo(todo.id, {
              category: nextTags[0] ?? DEFAULT_CATEGORY,
              tags: nextTags,
            });
          }),
        );
      }
      setTagRegistry((prev) => prev.filter((item) => item !== tag));
      setTagColorMap((prev) => {
        const next = { ...prev };
        delete next[tag];
        return next;
      });
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
              const tags = readTagLevels(todo);
              const primaryTag = tags[0];
              const secondaryTag = tags[1];
              const primaryColor = primaryTag ? getTagColor(primaryTag) : DEFAULT_TAG_COLOR;
              const content = readContent(todo);

              return (
                <li key={todo.id} className="library-item">
                  <button type="button" className="library-item-main" onClick={() => openTaskEditor(todo)}>
                    <p
                      className={`break-words text-sm ${
                        todo.status === "completed" ? "text-subtle line-through" : "text-main"
                      }`}
                    >
                      {todo.title}
                    </p>
                    <div className="task-meta-row mt-2">
                      {primaryTag ? (
                        <span className="task-pill" style={tagPillStyle(primaryColor)}>
                          {primaryTag}
                        </span>
                      ) : (
                        <span className="task-meta-muted">{DEFAULT_PRIMARY_TAG}</span>
                      )}
                      {secondaryTag ? <span className="task-pill task-pill-tag">{secondaryTag}</span> : null}
                    </div>
                    {content ? <p className="task-content-preview">{content}</p> : null}
                  </button>
                  <button
                    type="button"
                    className={selected ? "btn-primary h-9 px-3 text-xs" : "btn-muted h-9 px-3 text-xs"}
                    onClick={(event) => {
                      event.stopPropagation();
                      void handleTogglePlan(todo.id);
                    }}
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
              <h3 className="page-title text-lg font-bold text-main">管理标签</h3>
              <button
                type="button"
                className="btn-muted h-8 px-3 text-xs"
                onClick={() => setMetaManagerOpen(false)}
                disabled={metaSaving}
              >
                关闭
              </button>
            </header>

            <div className="meta-manager-body">
              <form className="meta-manager-create" onSubmit={handleAddTag}>
                <input
                  value={newTagName}
                  onChange={(event) => setNewTagName(event.target.value)}
                  className="input-base h-10"
                  disabled={metaSaving}
                />
                <button type="submit" className="btn-primary h-10 px-3 text-xs" disabled={metaSaving}>
                  新增
                </button>
              </form>

              <div className="meta-manager-color-palette">
                {COMMON_TAG_COLORS.map((color) => (
                  <button
                    key={color}
                    type="button"
                    className={`meta-color-swatch ${newTagColor === color ? "is-active" : ""}`}
                    style={{ backgroundColor: color }}
                    onClick={() => setNewTagColor(color)}
                    disabled={metaSaving}
                    aria-label={`选择颜色 ${color}`}
                  />
                ))}
              </div>

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
                        <span className="meta-manager-name-wrap">
                          <span className="meta-manager-swatch" style={{ backgroundColor: getTagColor(tag) }} />
                          <span className="meta-manager-name">{tag}</span>
                        </span>
                        <div className="meta-manager-row-actions">
                          <div className="meta-manager-color-palette is-inline">
                            {COMMON_TAG_COLORS.map((color) => (
                              <button
                                key={`${tag}-${color}`}
                                type="button"
                                className={`meta-color-swatch ${getTagColor(tag) === color ? "is-active" : ""}`}
                                style={{ backgroundColor: color }}
                                onClick={() => handleUpdateTagColor(tag, color)}
                                disabled={metaSaving}
                                aria-label={`为标签 ${tag} 选择颜色 ${color}`}
                              />
                            ))}
                          </div>
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

            {metaNotice ? <p className="app-inline-note">{metaNotice}</p> : null}
          </aside>
        </div>
      ) : null}

      {taskEditorOpen ? (
        <div className="task-editor-backdrop" onClick={closeTaskEditor} aria-hidden={!taskEditorOpen}>
          <aside className="task-editor-sheet" onClick={(event) => event.stopPropagation()}>
            <header className="task-editor-header">
              <h3 className="page-title text-lg font-bold text-main">编辑任务</h3>
              <button
                type="button"
                className="btn-muted h-8 px-3 text-xs"
                onClick={closeTaskEditor}
                disabled={taskEditorSaving || taskEditorDeleting}
              >
                关闭
              </button>
            </header>

            <p className="task-editor-title">{taskEditorTodoTitle}</p>

            <label className="task-meta-form-item">
              <span className="task-meta-form-label">一级标签</span>
              <input
                value={taskEditorPrimaryTag}
                onChange={(event) => setTaskEditorPrimaryTag(event.target.value)}
                className="input-base h-10"
                disabled={taskEditorSaving || taskEditorDeleting}
              />
              {taskEditorPrimarySuggestions.length > 0 ? (
                <div className="tag-suggestion-row">
                  {taskEditorPrimarySuggestions.map((item) => (
                    <button
                      key={item}
                      type="button"
                      className="tag-suggestion-btn"
                      onClick={() => setTaskEditorPrimaryTag(item)}
                      disabled={taskEditorSaving || taskEditorDeleting}
                    >
                      {item}
                    </button>
                  ))}
                </div>
              ) : null}
            </label>

            <label className="task-meta-form-item">
              <span className="task-meta-form-label">二级标签</span>
              <input
                value={taskEditorSecondaryTag}
                onChange={(event) => setTaskEditorSecondaryTag(event.target.value)}
                className="input-base h-10"
                disabled={taskEditorSaving || taskEditorDeleting}
              />
              {taskEditorSecondarySuggestions.length > 0 ? (
                <div className="tag-suggestion-row">
                  {taskEditorSecondarySuggestions.map((item) => (
                    <button
                      key={item}
                      type="button"
                      className="tag-suggestion-btn"
                      onClick={() => setTaskEditorSecondaryTag(item)}
                      disabled={taskEditorSaving || taskEditorDeleting}
                    >
                      {item}
                    </button>
                  ))}
                </div>
              ) : null}
            </label>

            <label className="task-meta-form-item">
              <span className="task-meta-form-label">具体内容</span>
              <textarea
                value={taskEditorContent}
                onChange={(event) => setTaskEditorContent(event.target.value)}
                className="input-base min-h-[6rem] resize-none"
                disabled={taskEditorSaving || taskEditorDeleting}
              />
            </label>

            <div className="task-editor-actions">
              <button
                type="button"
                className="btn-danger h-10 px-4 text-sm"
                onClick={() => void handleDeleteTaskFromEditor()}
                disabled={taskEditorSaving || taskEditorDeleting}
              >
                {taskEditorDeleting ? "删除中..." : "删除任务"}
              </button>
              <button
                type="button"
                className="btn-primary h-10 grow text-sm"
                onClick={() => void handleSaveTaskEditor()}
                disabled={taskEditorSaving || taskEditorDeleting}
              >
                {taskEditorSaving ? "保存中..." : "保存修改"}
              </button>
            </div>

            {taskEditorNotice ? <p className="app-inline-note">{taskEditorNotice}</p> : null}
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
          {formatDuration(Math.abs(efficiency.periodDelta.totalDurationSeconds))}，完成率 
          {efficiency.periodDelta.completionRate >= 0 ? "+" : ""}
          {efficiency.periodDelta.completionRate}%
        </p>
      </section>

      <section className="mobile-card">
        <h3 className="page-title text-lg font-bold text-main">标签贡献（一级）</h3>
        {categoryStats.length === 0 ? null : (
          <div className="mt-3 space-y-3">
            {categoryStats.map((item) => {
              const width = (item.totalDurationSeconds / maxCategorySeconds) * 100;
              return (
                <div key={item.category}>
                  <div className="mb-1 flex items-center justify-between text-xs">
                    <span className="text-main">{item.category}</span>
                    <span className="text-subtle">
                      {item.completedCount}/{item.taskCount} 路 {Math.round(item.completionRate)}%
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
                      className="h-full rounded-full bg-gradient-to-r from-blue-500 to-cyan-400"
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
          tagOptions={tagOptions}
          tagColorMap={tagColorMap}
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
