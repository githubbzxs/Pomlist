import { describe, expect, it } from "vitest";
import { buildDashboard, buildDistribution, buildTrend, computeStreak } from "../lib/analytics-service";
import type { DbFocusSessionRow } from "../lib/domain-mappers";

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
    expect(trend[2].totalDurationSeconds).toBe(3600);

    const distribution = buildDistribution(rows);
    expect(distribution.find((item) => item.bucketLabel === "0-15 分钟")?.sessionCount).toBe(0);
    expect(distribution.find((item) => item.bucketLabel === "15-30 分钟")?.sessionCount).toBe(1);
    expect(distribution.find((item) => item.bucketLabel === "30-45 分钟")?.sessionCount).toBe(1);
    expect(distribution.find((item) => item.bucketLabel === "45+ 分钟")?.sessionCount).toBe(1);
  });
});
