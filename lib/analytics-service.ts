import {
  buildTrendSeries,
  completionRate,
  emptyDistribution,
  resolveDurationBucketLabel,
  type DbFocusSessionRow,
} from "@/lib/domain-mappers";
import type { DashboardAnalytics, DurationDistributionItem, TrendAnalyticsPoint } from "@/types/domain";

function startOfUtcDay(input: Date): Date {
  return new Date(Date.UTC(input.getUTCFullYear(), input.getUTCMonth(), input.getUTCDate()));
}

function addDays(input: Date, days: number): Date {
  return new Date(input.getTime() + days * 24 * 60 * 60 * 1000);
}

function dateKey(isoText: string): string {
  return isoText.slice(0, 10);
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

export function buildDashboard(todayRows: DbFocusSessionRow[], streakDays: number, now: Date = new Date()): DashboardAnalytics {
  const totalDurationSeconds = todayRows.reduce((sum, row) => sum + row.elapsed_seconds, 0);
  const completedTaskCount = todayRows.reduce((sum, row) => sum + row.completed_task_count, 0);
  const totalTaskCount = todayRows.reduce((sum, row) => sum + row.total_task_count, 0);

  return {
    date: startOfUtcDay(now).toISOString().slice(0, 10),
    sessionCount: todayRows.length,
    totalDurationSeconds,
    completionRate: completionRate(completedTaskCount, totalTaskCount),
    streakDays,
    completedTaskCount,
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

