import { describe, expect, it } from "vitest";

import {
  buildCategoryStats,
  buildDashboard,
  buildDistribution,
  buildEfficiencyMetrics,
  buildHourlyDistribution,
  buildPeriodMetrics,
  buildTrend,
  computeStreak,
} from "../lib/analytics-service";
import type { DbFocusSessionRow, DbSessionTaskRefRow, DbTodoRow } from "../lib/domain-mappers";

function sessionRow(input: Partial<DbFocusSessionRow>): DbFocusSessionRow {
  return {
    id: input.id ?? crypto.randomUUID(),
    user_id: input.user_id ?? "user-1",
    state: input.state ?? "ended",
    started_at: input.started_at ?? "2026-02-13T08:00:00.000Z",
    ended_at: input.ended_at ?? "2026-02-13T09:00:00.000Z",
    elapsed_seconds: input.elapsed_seconds ?? 3600,
    total_task_count: input.total_task_count ?? 10,
    completed_task_count: input.completed_task_count ?? 8,
    created_at: input.created_at ?? "2026-02-13T08:00:00.000Z",
    updated_at: input.updated_at ?? "2026-02-13T09:00:00.000Z",
  };
}

function refRow(input: Partial<DbSessionTaskRefRow>): DbSessionTaskRefRow {
  return {
    id: input.id ?? crypto.randomUUID(),
    user_id: input.user_id ?? "user-1",
    session_id: input.session_id ?? "s1",
    todo_id: input.todo_id ?? "t1",
    title_snapshot: input.title_snapshot ?? "任务",
    order_index: input.order_index ?? 0,
    is_completed_in_session: input.is_completed_in_session ?? false,
    completed_at: input.completed_at ?? null,
    created_at: input.created_at ?? "2026-02-13T08:00:00.000Z",
    updated_at: input.updated_at ?? "2026-02-13T08:00:00.000Z",
  };
}

function todoRow(input: Partial<DbTodoRow>): DbTodoRow {
  return {
    id: input.id ?? crypto.randomUUID(),
    user_id: input.user_id ?? "user-1",
    title: input.title ?? "任务",
    subject: input.subject ?? null,
    notes: input.notes ?? null,
    category: input.category ?? "学习",
    tags: input.tags ?? [],
    priority: input.priority ?? 2,
    due_at: input.due_at ?? null,
    status: input.status ?? "pending",
    completed_at: input.completed_at ?? null,
    created_at: input.created_at ?? "2026-02-13T08:00:00.000Z",
    updated_at: input.updated_at ?? "2026-02-13T08:00:00.000Z",
  };
}

describe("analytics-service", () => {
  it("计算 dashboard 指标", () => {
    const rows = [
      sessionRow({ elapsed_seconds: 1800, total_task_count: 10, completed_task_count: 8 }),
      sessionRow({ id: "s2", elapsed_seconds: 1200, total_task_count: 5, completed_task_count: 5 }),
    ];

    const dashboard = buildDashboard(rows, 3, new Date("2026-02-13T10:00:00.000Z"));

    expect(dashboard.sessionCount).toBe(2);
    expect(dashboard.totalDurationSeconds).toBe(3000);
    expect(dashboard.completedTaskCount).toBe(13);
    expect(dashboard.completionRate).toBeCloseTo(86.67, 2);
    expect(dashboard.streakDays).toBe(3);
  });

  it("计算 streak", () => {
    const rows = [
      sessionRow({ ended_at: "2026-02-13T10:00:00.000Z" }),
      sessionRow({ id: "2", ended_at: "2026-02-12T10:00:00.000Z" }),
      sessionRow({ id: "3", ended_at: "2026-02-11T10:00:00.000Z" }),
    ];

    const streak = computeStreak(rows, new Date("2026-02-13T23:00:00.000Z"));
    expect(streak).toBe(3);
  });

  it("生成趋势与分布", () => {
    const rows = [
      sessionRow({ ended_at: "2026-02-11T10:00:00.000Z", elapsed_seconds: 900 }),
      sessionRow({ id: "2", ended_at: "2026-02-12T10:00:00.000Z", elapsed_seconds: 2100 }),
      sessionRow({ id: "3", ended_at: "2026-02-13T10:00:00.000Z", elapsed_seconds: 3600 }),
    ];

    const trend = buildTrend(rows, 3, new Date("2026-02-13T23:00:00.000Z"));
    expect(trend).toHaveLength(3);
    expect(trend[2]?.totalDurationSeconds).toBe(3600);

    const distribution = buildDistribution(rows);
    expect(distribution.find((item) => item.bucketLabel === "0-15 分钟")?.sessionCount).toBe(0);
    expect(distribution.find((item) => item.bucketLabel === "15-30 分钟")?.sessionCount).toBe(1);
    expect(distribution.find((item) => item.bucketLabel === "30-45 分钟")?.sessionCount).toBe(1);
    expect(distribution.find((item) => item.bucketLabel === "45+ 分钟")?.sessionCount).toBe(1);
  });

  it("聚合分类和时段", () => {
    const sessions = [
      sessionRow({ id: "s1", elapsed_seconds: 3600, completed_task_count: 1, total_task_count: 2, ended_at: "2026-02-13T10:10:00.000Z" }),
      sessionRow({ id: "s2", elapsed_seconds: 1800, completed_task_count: 1, total_task_count: 1, ended_at: "2026-02-13T22:10:00.000Z" }),
    ];

    const refs: DbSessionTaskRefRow[] = [
      refRow({ id: "r1", session_id: "s1", todo_id: "t1", is_completed_in_session: true }),
      refRow({ id: "r2", session_id: "s1", todo_id: "t2", is_completed_in_session: false, order_index: 1 }),
      refRow({ id: "r3", session_id: "s2", todo_id: "t3", is_completed_in_session: true }),
    ];

    const todos: DbTodoRow[] = [
      todoRow({ id: "t1", category: "学习" }),
      todoRow({ id: "t2", category: "工作" }),
      todoRow({ id: "t3", category: "学习" }),
    ];

    const categoryStats = buildCategoryStats(sessions, refs, todos);
    expect(categoryStats).toHaveLength(2);
    expect(categoryStats.find((item) => item.category === "学习")?.taskCount).toBe(2);

    const hourly = buildHourlyDistribution(sessions);
    expect(hourly[10]?.sessionCount).toBe(1);
    expect(hourly[22]?.sessionCount).toBe(1);
  });

  it("计算效率指标", () => {
    const recentRows = [
      sessionRow({ elapsed_seconds: 1800, completed_task_count: 2, total_task_count: 3 }),
      sessionRow({ id: "s2", elapsed_seconds: 3600, completed_task_count: 4, total_task_count: 5 }),
    ];
    const previousRows = [sessionRow({ id: "old", elapsed_seconds: 1200, completed_task_count: 1, total_task_count: 3 })];

    const efficiency = buildEfficiencyMetrics(recentRows, previousRows);
    expect(efficiency.tasksPerHour).toBeGreaterThan(0);
    expect(efficiency.avgCompletionRate).toBeGreaterThan(0);
    expect(efficiency.periodDelta.sessionCount).toBe(1);
  });

  it("构建周期统计", () => {
    const rows = [sessionRow({ elapsed_seconds: 600, completed_task_count: 1, total_task_count: 2 })];
    const period = buildPeriodMetrics(rows);
    expect(period.sessionCount).toBe(1);
    expect(period.totalDurationSeconds).toBe(600);
    expect(period.completedTaskCount).toBe(1);
  });
});

