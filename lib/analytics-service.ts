import {
  buildTrendSeries,
  completionRate,
  emptyDistribution,
  resolveDurationBucketLabel,
  type DbFocusSessionRow,
  type DbSessionTaskRefRow,
  type DbTodoRow,
} from "@/lib/domain-mappers";
import { DEFAULT_TODO_CATEGORY, normalizeTodoCategory } from "@/lib/validation";
import type {
  CategoryAnalyticsPoint,
  DashboardAnalytics,
  DurationDistributionItem,
  EfficiencyAnalytics,
  HourlyAnalyticsPoint,
  PeriodAnalytics,
  TrendAnalyticsPoint,
} from "@/types/domain";

function startOfUtcDay(input: Date): Date {
  return new Date(Date.UTC(input.getUTCFullYear(), input.getUTCMonth(), input.getUTCDate()));
}

function addDays(input: Date, days: number): Date {
  return new Date(input.getTime() + days * 24 * 60 * 60 * 1000);
}

function dateKey(isoText: string): string {
  return isoText.slice(0, 10);
}

function toSessionSummary(rows: DbFocusSessionRow[]): PeriodAnalytics {
  const totalDurationSeconds = rows.reduce((sum, row) => sum + row.elapsed_seconds, 0);
  const completedTaskCount = rows.reduce((sum, row) => sum + row.completed_task_count, 0);
  const totalTaskCount = rows.reduce((sum, row) => sum + row.total_task_count, 0);

  return {
    sessionCount: rows.length,
    totalDurationSeconds,
    completedTaskCount,
    completionRate: completionRate(completedTaskCount, totalTaskCount),
  };
}

export function resolveTodayRange(now: Date = new Date()): { start: Date; end: Date } {
  const start = startOfUtcDay(now);
  return { start, end: addDays(start, 1) };
}

export function resolveRecentRange(days: number, now: Date = new Date()): { start: Date; end: Date } {
  const safeDays = Math.max(1, Math.min(60, Math.floor(days)));
  const startOfToday = startOfUtcDay(now);
  return {
    start: addDays(startOfToday, -(safeDays - 1)),
    end: addDays(startOfToday, 1),
  };
}

export function computeStreak(rows: DbFocusSessionRow[], now: Date = new Date()): number {
  if (rows.length === 0) {
    return 0;
  }

  const daySet = new Set(rows.map((row) => dateKey(row.ended_at ?? row.started_at)));
  let streak = 0;
  let cursor = startOfUtcDay(now);

  while (daySet.has(cursor.toISOString().slice(0, 10))) {
    streak += 1;
    cursor = addDays(cursor, -1);
  }

  return streak;
}

interface DashboardBuildExtras {
  period?: {
    today: PeriodAnalytics;
    last7: PeriodAnalytics;
    last30: PeriodAnalytics;
  };
  categoryStats?: CategoryAnalyticsPoint[];
  hourlyDistribution?: HourlyAnalyticsPoint[];
  efficiency?: EfficiencyAnalytics;
}

export function buildDashboard(
  todayRows: DbFocusSessionRow[],
  streakDays: number,
  now: Date = new Date(),
  extras: DashboardBuildExtras = {},
): DashboardAnalytics {
  const todayPeriod = toSessionSummary(todayRows);

  return {
    date: startOfUtcDay(now).toISOString().slice(0, 10),
    sessionCount: todayPeriod.sessionCount,
    totalDurationSeconds: todayPeriod.totalDurationSeconds,
    completionRate: todayPeriod.completionRate,
    streakDays,
    completedTaskCount: todayPeriod.completedTaskCount,
    period: extras.period ?? {
      today: todayPeriod,
      last7: todayPeriod,
      last30: todayPeriod,
    },
    categoryStats: extras.categoryStats ?? [],
    hourlyDistribution: extras.hourlyDistribution ?? buildHourlyDistribution(todayRows),
    efficiency:
      extras.efficiency ??
      buildEfficiencyMetrics(
        todayRows,
        [],
      ),
  };
}

export function buildTrend(rows: DbFocusSessionRow[], days: number, now: Date = new Date()): TrendAnalyticsPoint[] {
  const base = buildTrendSeries(days, now);
  const byDate = new Map<
    string,
    {
      sessionCount: number;
      totalDurationSeconds: number;
      completedTaskCount: number;
      totalTaskCount: number;
    }
  >();

  for (const row of rows) {
    const key = dateKey(row.ended_at ?? row.started_at);
    const value = byDate.get(key) ?? {
      sessionCount: 0,
      totalDurationSeconds: 0,
      completedTaskCount: 0,
      totalTaskCount: 0,
    };
    value.sessionCount += 1;
    value.totalDurationSeconds += row.elapsed_seconds;
    value.completedTaskCount += row.completed_task_count;
    value.totalTaskCount += row.total_task_count;
    byDate.set(key, value);
  }

  return base.map((point) => {
    const value = byDate.get(point.date);
    if (!value) {
      return point;
    }
    return {
      date: point.date,
      sessionCount: value.sessionCount,
      totalDurationSeconds: value.totalDurationSeconds,
      completionRate: completionRate(value.completedTaskCount, value.totalTaskCount),
    };
  });
}

export function buildDistribution(rows: DbFocusSessionRow[]): DurationDistributionItem[] {
  const distribution = emptyDistribution();
  const map = new Map(distribution.map((item) => [item.bucketLabel, item]));

  for (const row of rows) {
    const elapsed = row.elapsed_seconds;
    const bucket = resolveDurationBucketLabel(elapsed);
    const item = map.get(bucket);
    if (!item) {
      continue;
    }
    item.sessionCount += 1;
    item.totalDurationSeconds += elapsed;
  }

  return distribution;
}

export function buildPeriodMetrics(rows: DbFocusSessionRow[]): PeriodAnalytics {
  return toSessionSummary(rows);
}

export function buildCategoryStats(
  rows: DbFocusSessionRow[],
  refs: DbSessionTaskRefRow[],
  todos: DbTodoRow[],
): CategoryAnalyticsPoint[] {
  if (rows.length === 0 || refs.length === 0) {
    return [];
  }

  const sessionMap = new Map(rows.map((row) => [row.id, row]));
  const todoCategoryMap = new Map(
    todos.map((todo) => [todo.id, normalizeTodoCategory(todo.category) ?? DEFAULT_TODO_CATEGORY]),
  );

  const totalRefCountBySession = new Map<string, number>();
  for (const ref of refs) {
    totalRefCountBySession.set(ref.session_id, (totalRefCountBySession.get(ref.session_id) ?? 0) + 1);
  }

  const stats = new Map<
    string,
    {
      taskCount: number;
      completedCount: number;
      totalDurationSeconds: number;
    }
  >();

  for (const ref of refs) {
    const session = sessionMap.get(ref.session_id);
    if (!session) {
      continue;
    }

    const category = todoCategoryMap.get(ref.todo_id) ?? DEFAULT_TODO_CATEGORY;
    const existing = stats.get(category) ?? {
      taskCount: 0,
      completedCount: 0,
      totalDurationSeconds: 0,
    };

    const refCount = Math.max(1, totalRefCountBySession.get(ref.session_id) ?? session.total_task_count);
    const shareSeconds = session.elapsed_seconds / refCount;

    existing.taskCount += 1;
    if (ref.is_completed_in_session) {
      existing.completedCount += 1;
    }
    existing.totalDurationSeconds += shareSeconds;

    stats.set(category, existing);
  }

  return Array.from(stats.entries())
    .map(([category, value]) => ({
      category,
      taskCount: value.taskCount,
      completedCount: value.completedCount,
      completionRate: completionRate(value.completedCount, value.taskCount),
      totalDurationSeconds: Math.round(value.totalDurationSeconds),
    }))
    .sort((left, right) => right.totalDurationSeconds - left.totalDurationSeconds);
}

export function buildHourlyDistribution(rows: DbFocusSessionRow[]): HourlyAnalyticsPoint[] {
  const buckets: HourlyAnalyticsPoint[] = Array.from({ length: 24 }, (_, hour) => ({
    hour,
    sessionCount: 0,
    totalDurationSeconds: 0,
    completedTaskCount: 0,
  }));

  for (const row of rows) {
    const source = row.ended_at ?? row.started_at;
    const date = new Date(source);
    if (Number.isNaN(date.getTime())) {
      continue;
    }

    const hour = date.getUTCHours();
    const bucket = buckets[hour];
    bucket.sessionCount += 1;
    bucket.totalDurationSeconds += row.elapsed_seconds;
    bucket.completedTaskCount += row.completed_task_count;
  }

  return buckets;
}

function roundTwo(value: number): number {
  return Number(value.toFixed(2));
}

export function buildEfficiencyMetrics(
  recentRows: DbFocusSessionRow[],
  previousRows: DbFocusSessionRow[],
): EfficiencyAnalytics {
  const recent = toSessionSummary(recentRows);
  const previous = toSessionSummary(previousRows);

  const tasksPerHour =
    recent.totalDurationSeconds > 0
      ? roundTwo(recent.completedTaskCount / (recent.totalDurationSeconds / 3600))
      : 0;

  const avgSessionDurationSeconds =
    recent.sessionCount > 0 ? Math.round(recent.totalDurationSeconds / recent.sessionCount) : 0;

  return {
    tasksPerHour,
    avgCompletionRate: recent.completionRate,
    avgSessionDurationSeconds,
    periodDelta: {
      sessionCount: recent.sessionCount - previous.sessionCount,
      totalDurationSeconds: recent.totalDurationSeconds - previous.totalDurationSeconds,
      completionRate: roundTwo(recent.completionRate - previous.completionRate),
    },
  };
}

