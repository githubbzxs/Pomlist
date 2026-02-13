import {
  type DbFocusSessionRow,
  type DbSessionTaskRefRow,
  type DbTodoRow,
  mapActiveSession,
} from "@/lib/domain-mappers";
import type { SupabaseHttpClient, SupabaseResult } from "@/lib/supabase/shared";
import type { ActiveSession } from "@/types/domain";

export interface LoadedSessionBundle {
  session: DbFocusSessionRow;
  refs: DbSessionTaskRefRow[];
  todos: DbTodoRow[];
}

function inFilter(ids: string[]): string {
  return `in.(${ids.join(",")})`;
}

function hasSupabaseError(result: SupabaseResult<unknown>): boolean {
  return Boolean(result.error);
}

export function buildIdInFilter(ids: string[]): string {
  return inFilter(ids);
}

export async function findActiveSession(
  client: SupabaseHttpClient,
  userId: string,
  sessionId?: string,
): Promise<LoadedSessionBundle | null> {
  const sessionResult = await client.rest<DbFocusSessionRow[]>({
    table: "focus_sessions",
    query: {
      select: "*",
      user_id: `eq.${userId}`,
      state: "eq.active",
      ...(sessionId ? { id: `eq.${sessionId}` } : {}),
      order: "started_at.desc",
      limit: 1,
    },
  });

  if (hasSupabaseError(sessionResult)) {
    throw new Error(sessionResult.error?.message ?? "查询 active session 失败。");
  }

  const sessionRow = sessionResult.data?.[0];
  if (!sessionRow) {
    return null;
  }

  const refsResult = await client.rest<DbSessionTaskRefRow[]>({
    table: "session_task_refs",
    query: {
      select: "*",
      user_id: `eq.${userId}`,
      session_id: `eq.${sessionRow.id}`,
      order: "order_index.asc",
    },
  });

  if (hasSupabaseError(refsResult)) {
    throw new Error(refsResult.error?.message ?? "查询 session_task_refs 失败。");
  }

  const refs = refsResult.data ?? [];
  if (refs.length === 0) {
    return { session: sessionRow, refs: [], todos: [] };
  }

  const todoIds = refs.map((ref) => ref.todo_id);
  const todosResult = await client.rest<DbTodoRow[]>({
    table: "todos",
    query: {
      select: "*",
      user_id: `eq.${userId}`,
      id: inFilter(todoIds),
    },
  });

  if (hasSupabaseError(todosResult)) {
    throw new Error(todosResult.error?.message ?? "查询 todos 失败。");
  }

  return {
    session: sessionRow,
    refs,
    todos: todosResult.data ?? [],
  };
}

export async function toActiveSessionPayload(
  client: SupabaseHttpClient,
  userId: string,
  sessionId?: string,
): Promise<ActiveSession | null> {
  const bundle = await findActiveSession(client, userId, sessionId);
  if (!bundle) {
    return null;
  }

  return mapActiveSession(bundle.session, bundle.refs, bundle.todos);
}

export async function countCompletedTasksInSession(
  client: SupabaseHttpClient,
  userId: string,
  sessionId: string,
): Promise<number> {
  const result = await client.rest<{ count: number }[]>({
    table: "session_task_refs",
    query: {
      select: "count",
      user_id: `eq.${userId}`,
      session_id: `eq.${sessionId}`,
      is_completed_in_session: "eq.true",
    },
    prefer: "count=exact",
  });

  if (hasSupabaseError(result)) {
    throw new Error(result.error?.message ?? "统计 session 完成任务失败。");
  }

  return result.data?.length ?? 0;
}

