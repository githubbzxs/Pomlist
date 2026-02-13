import type { NextRequest } from "next/server";

import { requireAuth } from "@/lib/auth";
import { type DbTodoRow, mapTodoRow } from "@/lib/domain-mappers";
import { errorResponse, parseJsonBody, successResponse } from "@/lib/http";
import { createServerClient } from "@/lib/supabase/server";
import { toSupabaseErrorResponse } from "@/lib/supabase-error";
import { normalizeDueAt, normalizePriority, normalizeText, normalizeTitle } from "@/lib/validation";
import type { TodoStatus } from "@/types/domain";

interface RouteParams {
  params: Promise<{ id: string }>;
}

interface UpdateTodoBody {
  title?: unknown;
  subject?: unknown;
  notes?: unknown;
  priority?: unknown;
  dueAt?: unknown;
  status?: unknown;
  completed?: unknown;
}

const STATUSES: TodoStatus[] = ["pending", "completed", "archived"];

function buildStatus(input: unknown): TodoStatus | null {
  if (typeof input !== "string") {
    return null;
  }
  return STATUSES.includes(input as TodoStatus) ? (input as TodoStatus) : null;
}

export async function PATCH(request: NextRequest, context: RouteParams) {
  const authResult = await requireAuth(request);
  if (!authResult.ok) {
    return authResult.response;
  }

  const { id } = await context.params;
  if (!id) {
    return errorResponse("VALIDATION_ERROR", "缺少任务 id。", 400);
  }

  const parsedBody = await parseJsonBody<UpdateTodoBody>(request);
  if (!parsedBody.ok) {
    return parsedBody.response;
  }

  const updates: Record<string, unknown> = {};

  if (parsedBody.data.title !== undefined) {
    const title = normalizeTitle(parsedBody.data.title);
    if (!title) {
      return errorResponse("VALIDATION_ERROR", "标题不能为空，且长度不能超过 200 字。", 400);
    }
    updates.title = title;
  }

  if (parsedBody.data.subject !== undefined) {
    if (parsedBody.data.subject === null || parsedBody.data.subject === "") {
      updates.subject = null;
    } else {
      const subject = normalizeText(parsedBody.data.subject, 60);
      if (subject === null) {
        return errorResponse("VALIDATION_ERROR", "subject 必须是字符串。", 400);
      }
      updates.subject = subject;
    }
  }

  if (parsedBody.data.notes !== undefined) {
    if (parsedBody.data.notes === null || parsedBody.data.notes === "") {
      updates.notes = null;
    } else {
      const notes = normalizeText(parsedBody.data.notes, 2000);
      if (notes === null) {
        return errorResponse("VALIDATION_ERROR", "notes 必须是字符串。", 400);
      }
      updates.notes = notes;
    }
  }

  if (parsedBody.data.priority !== undefined) {
    const priority = normalizePriority(parsedBody.data.priority);
    if (priority === null) {
      return errorResponse("VALIDATION_ERROR", "priority 只能是 1/2/3。", 400);
    }
    updates.priority = priority;
  }

  if (parsedBody.data.dueAt !== undefined) {
    if (parsedBody.data.dueAt === null || parsedBody.data.dueAt === "") {
      updates.due_at = null;
    } else {
      const dueAt = normalizeDueAt(parsedBody.data.dueAt);
      if (dueAt === null) {
        return errorResponse("VALIDATION_ERROR", "dueAt 必须是合法日期字符串。", 400);
      }
      updates.due_at = dueAt;
    }
  }

  let status: TodoStatus | null = null;
  if (parsedBody.data.status !== undefined) {
    status = buildStatus(parsedBody.data.status);
    if (!status) {
      return errorResponse("VALIDATION_ERROR", "status 只能是 pending/completed/archived。", 400);
    }
  }

  if (typeof parsedBody.data.completed === "boolean") {
    status = parsedBody.data.completed ? "completed" : "pending";
  }

  if (status) {
    updates.status = status;
    updates.completed_at = status === "completed" ? new Date().toISOString() : null;
  }

  if (Object.keys(updates).length === 0) {
    return errorResponse("VALIDATION_ERROR", "未提供可更新字段。", 400);
  }

  const client = createServerClient(authResult.context.accessToken);
  const updateResult = await client.rest<DbTodoRow[]>({
    table: "todos",
    method: "PATCH",
    query: {
      select: "*",
      id: `eq.${id}`,
      user_id: `eq.${authResult.context.user.id}`,
    },
    body: updates,
  });

  if (updateResult.error) {
    return toSupabaseErrorResponse(updateResult, "更新任务失败。");
  }

  const row = updateResult.data?.[0];
  if (!row) {
    return errorResponse("NOT_FOUND", "未找到任务或无权限更新。", 404);
  }

  return successResponse(mapTodoRow(row), 200);
}

export async function DELETE(request: NextRequest, context: RouteParams) {
  const authResult = await requireAuth(request);
  if (!authResult.ok) {
    return authResult.response;
  }

  const { id } = await context.params;
  if (!id) {
    return errorResponse("VALIDATION_ERROR", "缺少任务 id。", 400);
  }

  const client = createServerClient(authResult.context.accessToken);
  const deleteResult = await client.rest<DbTodoRow[]>({
    table: "todos",
    method: "DELETE",
    query: {
      select: "*",
      id: `eq.${id}`,
      user_id: `eq.${authResult.context.user.id}`,
    },
  });

  if (deleteResult.error) {
    return toSupabaseErrorResponse(deleteResult, "删除任务失败。");
  }

  if (!deleteResult.data || deleteResult.data.length === 0) {
    return errorResponse("NOT_FOUND", "未找到任务或无权限删除。", 404);
  }

  return successResponse({ deleted: true }, 200);
}

