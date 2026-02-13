import type { NextRequest } from "next/server";

import { requireAuth } from "@/lib/auth";
import { type DbFocusSessionRow } from "@/lib/domain-mappers";
import { errorResponse, successResponse } from "@/lib/http";
import { createServerClient } from "@/lib/supabase/server";
import { toSupabaseErrorResponse } from "@/lib/supabase-error";

interface RouteParams {
  params: Promise<{ id: string }>;
}

export async function POST(request: NextRequest, context: RouteParams) {
  const authResult = await requireAuth(request);
  if (!authResult.ok) {
    return authResult.response;
  }

  const { id: sessionId } = await context.params;
  if (!sessionId) {
    return errorResponse("VALIDATION_ERROR", "缺少 session id。", 400);
  }

  const client = createServerClient(authResult.context.accessToken);
  const sessionResult = await client.rest<DbFocusSessionRow[]>({
    table: "focus_sessions",
    query: {
      select: "*",
      user_id: `eq.${authResult.context.user.id}`,
      id: `eq.${sessionId}`,
      limit: 1,
    },
  });
  if (sessionResult.error) {
    return toSupabaseErrorResponse(sessionResult, "读取任务钟失败。");
  }

  const session = sessionResult.data?.[0];
  if (!session) {
    return errorResponse("NOT_FOUND", "未找到任务钟。", 404);
  }
  if (session.state !== "active") {
    return errorResponse("SESSION_NOT_ACTIVE", "该任务钟已结束。", 409);
  }

  const completedCountResult = await client.rest<{ id: string }[]>({
    table: "session_task_refs",
    query: {
      select: "id",
      user_id: `eq.${authResult.context.user.id}`,
      session_id: `eq.${sessionId}`,
      is_completed_in_session: "eq.true",
    },
  });
  if (completedCountResult.error) {
    return toSupabaseErrorResponse(completedCountResult, "统计任务完成数量失败。");
  }

  const totalCountResult = await client.rest<{ id: string }[]>({
    table: "session_task_refs",
    query: {
      select: "id",
      user_id: `eq.${authResult.context.user.id}`,
      session_id: `eq.${sessionId}`,
    },
  });
  if (totalCountResult.error) {
    return toSupabaseErrorResponse(totalCountResult, "统计任务总数失败。");
  }

  const now = new Date();
  const elapsedSeconds = Math.max(
    0,
    Math.floor((now.getTime() - new Date(session.started_at).getTime()) / 1000),
  );
  const completedTaskCount = completedCountResult.data?.length ?? 0;
  const totalTaskCount = totalCountResult.data?.length ?? session.total_task_count;

  const updateResult = await client.rest<DbFocusSessionRow[]>({
    table: "focus_sessions",
    method: "PATCH",
    query: {
      select: "*",
      user_id: `eq.${authResult.context.user.id}`,
      id: `eq.${sessionId}`,
      state: "eq.active",
    },
    body: {
      state: "ended",
      ended_at: now.toISOString(),
      elapsed_seconds: elapsedSeconds,
      completed_task_count: completedTaskCount,
      total_task_count: totalTaskCount,
    },
  });
  if (updateResult.error) {
    return toSupabaseErrorResponse(updateResult, "结束任务钟失败。");
  }

  const updated = updateResult.data?.[0];
  if (!updated) {
    return errorResponse("SESSION_NOT_ACTIVE", "任务钟已被结束。", 409);
  }

  return successResponse(
    {
      id: updated.id,
      state: updated.state,
      completedTaskCount: updated.completed_task_count,
      totalTaskCount: updated.total_task_count,
      elapsedSeconds: updated.elapsed_seconds,
      endedAt: updated.ended_at,
    },
    200,
  );
}

