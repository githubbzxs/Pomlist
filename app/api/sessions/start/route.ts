import type { NextRequest } from "next/server";

import { requireAuth } from "@/lib/auth";
import { type DbFocusSessionRow, type DbSessionTaskRefRow, type DbTodoRow } from "@/lib/domain-mappers";
import { errorResponse, parseJsonBody, successResponse } from "@/lib/http";
import { buildIdInFilter, toActiveSessionPayload } from "@/lib/session-service";
import { createServerClient } from "@/lib/supabase/server";
import { isUniqueActiveSessionError, toSupabaseErrorResponse } from "@/lib/supabase-error";
import { isUuid, uniqueIds } from "@/lib/validation";

interface StartSessionBody {
  todoIds?: unknown;
}

export async function POST(request: NextRequest) {
  const authResult = await requireAuth(request);
  if (!authResult.ok) {
    return authResult.response;
  }

  const parsed = await parseJsonBody<StartSessionBody>(request);
  if (!parsed.ok) {
    return parsed.response;
  }

  if (!Array.isArray(parsed.data.todoIds)) {
    return errorResponse("VALIDATION_ERROR", "todoIds 必须是数组。", 400);
  }

  const rawIds = parsed.data.todoIds.filter((id): id is string => typeof id === "string");
  const todoIds = uniqueIds(rawIds);
  if (todoIds.length === 0) {
    return errorResponse("INVALID_TASK_SELECTION", "请至少选择一个任务。", 400);
  }
  if (!todoIds.every((id) => isUuid(id))) {
    return errorResponse("VALIDATION_ERROR", "todoIds 中存在非法 id。", 400);
  }

  const client = createServerClient(authResult.context.accessToken);

  const existingResult = await client.rest<DbFocusSessionRow[]>({
    table: "focus_sessions",
    query: {
      select: "*",
      user_id: `eq.${authResult.context.user.id}`,
      state: "eq.active",
      order: "started_at.desc",
      limit: 1,
    },
  });
  if (existingResult.error) {
    return toSupabaseErrorResponse(existingResult, "检查进行中任务钟失败。");
  }
  if (existingResult.data && existingResult.data.length > 0) {
    return errorResponse("ACTIVE_SESSION_EXISTS", "当前已有进行中的任务钟，请先结束后再创建。", 409);
  }

  const todosResult = await client.rest<DbTodoRow[]>({
    table: "todos",
    query: {
      select: "*",
      user_id: `eq.${authResult.context.user.id}`,
      id: buildIdInFilter(todoIds),
      status: "eq.pending",
      order: "created_at.asc",
    },
  });

  if (todosResult.error) {
    return toSupabaseErrorResponse(todosResult, "查询待办任务失败。");
  }

  const todos = todosResult.data ?? [];
  if (todos.length === 0) {
    return errorResponse("INVALID_TASK_SELECTION", "所选任务中没有可执行的待办项。", 400);
  }

  const sessionInsert = await client.rest<DbFocusSessionRow[]>({
    table: "focus_sessions",
    method: "POST",
    query: { select: "*" },
    body: {
      state: "active",
      started_at: new Date().toISOString(),
      ended_at: null,
      elapsed_seconds: 0,
      total_task_count: todos.length,
      completed_task_count: 0,
    },
  });

  if (sessionInsert.error) {
    if (isUniqueActiveSessionError(sessionInsert)) {
      return errorResponse("ACTIVE_SESSION_EXISTS", "当前已有进行中的任务钟，请先结束后再创建。", 409);
    }
    return toSupabaseErrorResponse(sessionInsert, "创建任务钟失败。");
  }

  const session = sessionInsert.data?.[0];
  if (!session) {
    return errorResponse("INTERNAL_ERROR", "创建任务钟失败，未返回会话数据。", 500);
  }

  const refsPayload = todos.map((todo, index) => ({
    session_id: session.id,
    todo_id: todo.id,
    title_snapshot: todo.title,
    order_index: index,
    is_completed_in_session: false,
    completed_at: null,
  }));

  const refsInsert = await client.rest<DbSessionTaskRefRow[]>({
    table: "session_task_refs",
    method: "POST",
    query: { select: "*" },
    body: refsPayload,
  });

  if (refsInsert.error) {
    return toSupabaseErrorResponse(refsInsert, "初始化任务钟任务列表失败。");
  }

  const activeSession = await toActiveSessionPayload(client, authResult.context.user.id, session.id);
  if (!activeSession) {
    return errorResponse("INTERNAL_ERROR", "创建任务钟后读取会话失败。", 500);
  }

  return successResponse(activeSession, 201);
}

