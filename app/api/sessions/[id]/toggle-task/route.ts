import type { NextRequest } from "next/server";

import { requireAuth } from "@/lib/auth";
import { type DbFocusSessionRow, type DbSessionTaskRefRow } from "@/lib/domain-mappers";
import { errorResponse, parseJsonBody, successResponse } from "@/lib/http";
import { toActiveSessionPayload } from "@/lib/session-service";
import { createServerClient } from "@/lib/supabase/server";
import { toSupabaseErrorResponse } from "@/lib/supabase-error";

interface RouteParams {
  params: Promise<{ id: string }>;
}

interface ToggleTaskBody {
  todoId?: unknown;
  isCompleted?: unknown;
}

export async function PATCH(request: NextRequest, context: RouteParams) {
  const authResult = await requireAuth(request);
  if (!authResult.ok) {
    return authResult.response;
  }

  const { id: sessionId } = await context.params;
  if (!sessionId) {
    return errorResponse("VALIDATION_ERROR", "缺少 session id。", 400);
  }

  const parsed = await parseJsonBody<ToggleTaskBody>(request);
  if (!parsed.ok) {
    return parsed.response;
  }

  if (typeof parsed.data.todoId !== "string" || parsed.data.todoId.trim() === "") {
    return errorResponse("VALIDATION_ERROR", "todoId 必须是非空字符串。", 400);
  }
  const todoId = parsed.data.todoId;

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
    return errorResponse("SESSION_NOT_ACTIVE", "该任务钟已结束，无法继续勾选。", 409);
  }

  const refResult = await client.rest<DbSessionTaskRefRow[]>({
    table: "session_task_refs",
    query: {
      select: "*",
      user_id: `eq.${authResult.context.user.id}`,
      session_id: `eq.${sessionId}`,
      todo_id: `eq.${todoId}`,
      limit: 1,
    },
  });
  if (refResult.error) {
    return toSupabaseErrorResponse(refResult, "读取任务钟任务失败。");
  }

  const ref = refResult.data?.[0];
  if (!ref) {
    return errorResponse("NOT_FOUND", "该任务不在当前任务钟内。", 404);
  }

  const isCompleted = typeof parsed.data.isCompleted === "boolean"
    ? parsed.data.isCompleted
    : !ref.is_completed_in_session;
  const now = new Date().toISOString();

  const updateRefResult = await client.rest<DbSessionTaskRefRow[]>({
    table: "session_task_refs",
    method: "PATCH",
    query: {
      select: "*",
      user_id: `eq.${authResult.context.user.id}`,
      session_id: `eq.${sessionId}`,
      todo_id: `eq.${todoId}`,
    },
    body: {
      is_completed_in_session: isCompleted,
      completed_at: isCompleted ? now : null,
    },
  });
  if (updateRefResult.error) {
    return toSupabaseErrorResponse(updateRefResult, "更新任务钟任务状态失败。");
  }

  const updateTodoResult = await client.rest({
    table: "todos",
    method: "PATCH",
    query: {
      select: "id",
      user_id: `eq.${authResult.context.user.id}`,
      id: `eq.${todoId}`,
    },
    body: {
      status: isCompleted ? "completed" : "pending",
      completed_at: isCompleted ? now : null,
    },
  });
  if (updateTodoResult.error) {
    return toSupabaseErrorResponse(updateTodoResult, "回写 To-Do 状态失败。");
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
    return toSupabaseErrorResponse(completedCountResult, "统计任务钟完成数量失败。");
  }

  const updateSessionResult = await client.rest<{ id: string }[]>({
    table: "focus_sessions",
    method: "PATCH",
    query: {
      select: "id",
      user_id: `eq.${authResult.context.user.id}`,
      id: `eq.${sessionId}`,
      state: "eq.active",
    },
    body: {
      completed_task_count: completedCountResult.data?.length ?? 0,
    },
  });
  if (updateSessionResult.error) {
    return toSupabaseErrorResponse(updateSessionResult, "更新任务钟进度失败。");
  }
  if (!updateSessionResult.data || updateSessionResult.data.length === 0) {
    return errorResponse("SESSION_NOT_ACTIVE", "该任务钟已结束，无法继续勾选。", 409);
  }

  try {
    const payload = await toActiveSessionPayload(client, authResult.context.user.id, sessionId);
    if (!payload) {
      return errorResponse("NOT_FOUND", "未找到进行中的任务钟。", 404);
    }
    return successResponse(payload, 200);
  } catch (error) {
    return errorResponse(
      "INTERNAL_ERROR",
      error instanceof Error ? error.message : "读取更新后的任务钟失败。",
      500,
    );
  }
}
