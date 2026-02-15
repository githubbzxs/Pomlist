import type { NextRequest } from "next/server";

import { requireAuth } from "@/lib/auth";
import { type DbTodoRow, mapTodoRow } from "@/lib/domain-mappers";
import { errorResponse, parseJsonBody, successResponse } from "@/lib/http";
import { createServerClient } from "@/lib/supabase/server";
import { toSupabaseErrorResponse } from "@/lib/supabase-error";
import {
  DEFAULT_TODO_CATEGORY,
  mergeTodoTagsWithCategory,
  normalizeDueAt,
  normalizePriority,
  normalizeText,
  normalizeTitle,
  normalizeTodoCategory,
} from "@/lib/validation";
import type { TodoStatus } from "@/types/domain";

interface CreateTodoBody {
  title?: unknown;
  subject?: unknown;
  notes?: unknown;
  category?: unknown;
  tags?: unknown;
  priority?: unknown;
  dueAt?: unknown;
}

const TODO_STATUSES: TodoStatus[] = ["pending", "completed", "archived"];

export async function GET(request: NextRequest) {
  const authResult = await requireAuth(request);
  if (!authResult.ok) {
    return authResult.response;
  }

  const statusParam = request.nextUrl.searchParams.get("status");
  const hasStatusFilter = statusParam !== null && statusParam !== "";
  if (hasStatusFilter && !TODO_STATUSES.includes(statusParam as TodoStatus)) {
    return errorResponse("VALIDATION_ERROR", "status 只能是 pending/completed/archived。", 400);
  }

  const client = createServerClient(authResult.context.accessToken);
  const todosResult = await client.rest<DbTodoRow[]>({
    table: "todos",
    query: {
      select: "*",
      user_id: `eq.${authResult.context.user.id}`,
      ...(hasStatusFilter ? { status: `eq.${statusParam}` } : {}),
      order: "created_at.desc",
    },
  });

  if (todosResult.error) {
    return toSupabaseErrorResponse(todosResult, "获取任务列表失败。");
  }

  return successResponse((todosResult.data ?? []).map(mapTodoRow), 200);
}

export async function POST(request: NextRequest) {
  const authResult = await requireAuth(request);
  if (!authResult.ok) {
    return authResult.response;
  }

  const parsedBody = await parseJsonBody<CreateTodoBody>(request);
  if (!parsedBody.ok) {
    return parsedBody.response;
  }

  const title = normalizeTitle(parsedBody.data.title);
  if (!title) {
    return errorResponse("VALIDATION_ERROR", "标题不能为空，且长度不能超过 200 字。", 400);
  }

  const subject = normalizeText(parsedBody.data.subject, 60);
  const notes = normalizeText(parsedBody.data.notes, 2000);
  const category = normalizeTodoCategory(parsedBody.data.category);
  if (category === null) {
    return errorResponse("VALIDATION_ERROR", "category 必须是字符串，且长度不超过 32。", 400);
  }

  const tags = mergeTodoTagsWithCategory(parsedBody.data.tags, category);
  if (tags === null) {
    return errorResponse("VALIDATION_ERROR", "tags 最多 2 项，且每项长度不超过 20。", 400);
  }
  const storedCategory = tags[0] ?? category ?? DEFAULT_TODO_CATEGORY;

  const priority = normalizePriority(parsedBody.data.priority) ?? 2;
  const dueAt = normalizeDueAt(parsedBody.data.dueAt);
  if (parsedBody.data.dueAt !== undefined && parsedBody.data.dueAt !== null && dueAt === null) {
    return errorResponse("VALIDATION_ERROR", "dueAt 必须是合法日期字符串。", 400);
  }

  const client = createServerClient(authResult.context.accessToken);
  const insertResult = await client.rest<DbTodoRow[]>({
    table: "todos",
    method: "POST",
    query: { select: "*" },
    body: {
      title,
      subject,
      notes,
      category: storedCategory,
      tags,
      priority,
      due_at: dueAt,
      status: "pending",
      completed_at: null,
    },
  });

  if (insertResult.error) {
    return toSupabaseErrorResponse(insertResult, "创建任务失败。");
  }

  const row = insertResult.data?.[0];
  if (!row) {
    return errorResponse("INTERNAL_ERROR", "创建任务失败，未返回任务数据。", 500);
  }

  return successResponse(mapTodoRow(row), 201);
}
