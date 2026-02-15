import type { NextRequest } from "next/server";

import { addDays, loadEndedSessions, startOfUtcDay } from "@/app/api/analytics/_helpers";
import {
  buildCategoryStats,
  buildDashboard,
  buildEfficiencyMetrics,
  buildHourlyDistribution,
  buildPeriodMetrics,
  computeStreak,
} from "@/lib/analytics-service";
import { requireAuth } from "@/lib/auth";
import {
  type DbSessionTaskRefRow,
  type DbTodoRow,
} from "@/lib/domain-mappers";
import { errorResponse, successResponse } from "@/lib/http";
import { buildIdInFilter } from "@/lib/session-service";
import { createServerClient } from "@/lib/supabase/server";
import { toSupabaseErrorResponse } from "@/lib/supabase-error";

export async function GET(request: NextRequest) {
  const authResult = await requireAuth(request);
  if (!authResult.ok) {
    return authResult.response;
  }

  const client = createServerClient(authResult.context.accessToken);
  const now = new Date();
  const start = startOfUtcDay(now);
  const end = addDays(start, 1);

  const last7Start = addDays(start, -6);
  const last30Start = addDays(start, -29);
  const previous7Start = addDays(last7Start, -7);
  const streakStart = addDays(start, -90);

  try {
    const [todayRows, last7Rows, last30Rows, previous7Rows, streakRows] = await Promise.all([
      loadEndedSessions(client, authResult.context.user.id, start, end),
      loadEndedSessions(client, authResult.context.user.id, last7Start, end),
      loadEndedSessions(client, authResult.context.user.id, last30Start, end),
      loadEndedSessions(client, authResult.context.user.id, previous7Start, last7Start),
      loadEndedSessions(client, authResult.context.user.id, streakStart, end),
    ]);

    let refs: DbSessionTaskRefRow[] = [];
    let todos: DbTodoRow[] = [];

    if (last30Rows.length > 0) {
      const sessionIds = last30Rows.map((row) => row.id);
      const refsResult = await client.rest<DbSessionTaskRefRow[]>({
        table: "session_task_refs",
        query: {
          select: "*",
          user_id: `eq.${authResult.context.user.id}`,
          session_id: buildIdInFilter(sessionIds),
          order: "created_at.asc",
        },
      });

      if (refsResult.error) {
        return toSupabaseErrorResponse(refsResult, "读取任务引用失败。");
      }

      refs = refsResult.data ?? [];

      if (refs.length > 0) {
        const todoIds = Array.from(new Set(refs.map((ref) => ref.todo_id)));
        const todosResult = await client.rest<DbTodoRow[]>({
          table: "todos",
          query: {
            select: "*",
            user_id: `eq.${authResult.context.user.id}`,
            id: buildIdInFilter(todoIds),
          },
        });

        if (todosResult.error) {
          return toSupabaseErrorResponse(todosResult, "读取任务数据失败。");
        }

        todos = todosResult.data ?? [];
      }
    }

    const streakDays = computeStreak(streakRows, now);
    const period = {
      today: buildPeriodMetrics(todayRows),
      last7: buildPeriodMetrics(last7Rows),
      last30: buildPeriodMetrics(last30Rows),
    };

    const dashboard = buildDashboard(todayRows, streakDays, now, {
      period,
      categoryStats: buildCategoryStats(last30Rows, refs, todos),
      hourlyDistribution: buildHourlyDistribution(last30Rows),
      efficiency: buildEfficiencyMetrics(last7Rows, previous7Rows),
    });

    return successResponse(dashboard, 200);
  } catch (error) {
    return errorResponse(
      "INTERNAL_ERROR",
      error instanceof Error ? error.message : "计算统计看板失败。",
      500,
    );
  }
}

