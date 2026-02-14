import type { NextRequest } from "next/server";

import { requireAuth } from "@/lib/auth";
import {
  type DbFocusSessionRow,
  type DbSessionTaskRefRow,
  type DbTodoRow,
} from "@/lib/domain-mappers";
import { errorResponse, parseJsonBody, successResponse } from "@/lib/http";
import { buildIdInFilter, toActiveSessionPayload } from "@/lib/session-service";
import { createServerClient } from "@/lib/supabase/server";
import { toSupabaseErrorResponse } from "@/lib/supabase-error";
import { isUuid, uniqueIds } from "@/lib/validation";

interface RouteParams {
  params: Promise<{ id: string }>;
}

interface AddSessionTasksBody {
  todoIds?: unknown;
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

  const parsedBody = await parseJsonBody<AddSessionTasksBody>(request);
  if (!parsedBody.ok) {
    return parsedBody.response;
  }

  if (!Array.isArray(parsedBody.data.todoIds)) {
    return errorResponse("VALIDATION_ERROR", "todoIds 必须是数组。", 400);
  }

  const rawIds = parsedBody.data.todoIds.filter((id): id is string => typeof id === "string");
  const todoIds = uniqueIds(rawIds);
  if (todoIds.length === 0) {
    return errorResponse("INVALID_TASK_SELECTION", "请至少选择一个任务。", 400);
  }
  if (!todoIds.every((id) => isUuid(id))) {
    return errorResponse("VALIDATION_ERROR", "todoIds 中存在非法 id。", 400);
  }

  const client = createServerClient(authResult.context.accessToken);

  const sessionResult = await client.rest<DbFocusSessionRow[]>({
    table: "focus_sessions",
    query: {
      select: "*",
      user_id: `eq.${authResult.context.user.id}`,
      id: `eq.${sessionId}`,
      state: "eq.active",
      limit: 1,
    },
  });
  if (sessionResult.error) {
    return toSupabaseErrorResponse(sessionResult, "读取任务钟失败。");
  }

  const session = sessionResult.data?.[0];
  if (!session) {
    return errorResponse("SESSION_NOT_ACTIVE", "当前任务钟不存在或已结束。", 409);
  }

  const refsResult = await client.rest<DbSessionTaskRefRow[]>({
    table: "session_task_refs",
    query: {
      select: "*",
      user_id: `eq.${authResult.context.user.id}`,
      session_id: `eq.${sessionId}`,
      order: "order_index.asc",
    },
  });
  if (refsResult.error) {
    return toSupabaseErrorResponse(refsResult, "读取任务钟任务失败。");
  }

  const existingRefs = refsResult.data ?? [];
  const existingTodoIds = new Set(existingRefs.map((ref) => ref.todo_id));
  const candidateIds = todoIds.filter((todoId) => !existingTodoIds.has(todoId));

  if (candidateIds.length === 0) {
    const payload = await toActiveSessionPayload(client, authResult.context.user.id, sessionId);
    if (!payload) {
      return errorResponse("NOT_FOUND", "未找到进行中的任务钟。", 404);
    }
    return successResponse(payload, 200);
  }

  const todosResult = await client.rest<DbTodoRow[]>({
    table: "todos",
    query: {
      select: "*",
      user_id: `eq.${authResult.context.user.id}`,
      id: buildIdInFilter(candidateIds),
      status: "eq.pending",
      order: "created_at.asc",
    },
  });
  if (todosResult.error) {
    return toSupabaseErrorResponse(todosResult, "读取待办任务失败。");
  }

  const todos = todosResult.data ?? [];
  if (todos.length === 0) {
    return errorResponse("INVALID_TASK_SELECTION", "所选任务不可加入当前任务钟。", 400);
  }

  const startIndex = existingRefs.length;
  const refsPayload = todos.map((todo, index) => ({
    session_id: session.id,
    todo_id: todo.id,
    title_snapshot: todo.title,
    order_index: startIndex + index,
    is_completed_in_session: false,
    completed_at: null,
  }));

  const insertResult = await client.rest<DbSessionTaskRefRow[]>({
    table: "session_task_refs",
    method: "POST",
    query: { select: "*" },
    body: refsPayload,
  });
  if (insertResult.error) {
    return toSupabaseErrorResponse(insertResult, "添加任务到任务钟失败。");
  }

  const updatedTotalCount = existingRefs.length + (insertResult.data?.length ?? 0);
  const updateSessionResult = await client.rest<DbFocusSessionRow[]>({
    table: "focus_sessions",
    method: "PATCH",
    query: {
      select: "*",
      user_id: `eq.${authResult.context.user.id}`,
      id: `eq.${sessionId}`,
      state: "eq.active",
    },
    body: {
      total_task_count: updatedTotalCount,
    },
  });

  if (updateSessionResult.error) {
    return toSupabaseErrorResponse(updateSessionResult, "更新任务钟总任务数失败。");
  }

  const payload = await toActiveSessionPayload(client, authResult.context.user.id, sessionId);
  if (!payload) {
    return errorResponse("NOT_FOUND", "未找到进行中的任务钟。", 404);
  }

  return successResponse(payload, 200);
}

