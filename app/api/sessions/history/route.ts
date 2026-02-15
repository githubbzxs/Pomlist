import type { NextRequest } from "next/server";

import { requireAuth } from "@/lib/auth";
import { completionRate, type DbFocusSessionRow, type DbSessionTaskRefRow } from "@/lib/domain-mappers";
import { successResponse } from "@/lib/http";
import { buildIdInFilter } from "@/lib/session-service";
import { createServerClient } from "@/lib/supabase/server";
import { toSupabaseErrorResponse } from "@/lib/supabase-error";

const DEFAULT_HISTORY_LIMIT = 30;
const MAX_HISTORY_LIMIT = 120;

function parseHistoryLimit(raw: string | null): number {
  if (!raw) {
    return DEFAULT_HISTORY_LIMIT;
  }

  const parsed = Number(raw);
  if (!Number.isFinite(parsed)) {
    return DEFAULT_HISTORY_LIMIT;
  }

  return Math.min(MAX_HISTORY_LIMIT, Math.max(1, Math.floor(parsed)));
}

export async function GET(request: NextRequest) {
  const authResult = await requireAuth(request);
  if (!authResult.ok) {
    return authResult.response;
  }

  const client = createServerClient(authResult.context.accessToken);
  const limit = parseHistoryLimit(request.nextUrl.searchParams.get("limit"));

  const sessionsResult = await client.rest<DbFocusSessionRow[]>({
    table: "focus_sessions",
    query: {
      select: "*",
      user_id: `eq.${authResult.context.user.id}`,
      state: "eq.ended",
      order: "ended_at.desc",
      limit,
    },
  });

  if (sessionsResult.error) {
    return toSupabaseErrorResponse(sessionsResult, "Failed to load completed session history.");
  }

  const sessions = sessionsResult.data ?? [];
  if (sessions.length === 0) {
    return successResponse([], 200);
  }

  const refsResult = await client.rest<DbSessionTaskRefRow[]>({
    table: "session_task_refs",
    query: {
      select: "*",
      user_id: `eq.${authResult.context.user.id}`,
      session_id: buildIdInFilter(sessions.map((item) => item.id)),
      order: "order_index.asc",
    },
  });

  if (refsResult.error) {
    return toSupabaseErrorResponse(refsResult, "Failed to load session task snapshots.");
  }

  const refsBySession = new Map<string, DbSessionTaskRefRow[]>();
  for (const ref of refsResult.data ?? []) {
    const list = refsBySession.get(ref.session_id);
    if (list) {
      list.push(ref);
    } else {
      refsBySession.set(ref.session_id, [ref]);
    }
  }

  for (const refs of refsBySession.values()) {
    refs.sort((left, right) => left.order_index - right.order_index);
  }

  const payload = sessions.map((session) => {
    const refs = refsBySession.get(session.id) ?? [];
    return {
      session: {
        id: session.id,
        state: "ended" as const,
        startedAt: session.started_at,
        endedAt: session.ended_at,
        elapsedSeconds: session.elapsed_seconds,
        totalTaskCount: session.total_task_count,
        completedTaskCount: session.completed_task_count,
        completionRate: completionRate(session.completed_task_count, session.total_task_count),
      },
      tasks: refs.map((ref) => ({
        ref: {
          todoId: ref.todo_id,
          isCompletedInSession: ref.is_completed_in_session,
        },
        displayTitle: ref.title_snapshot,
      })),
    };
  });

  return successResponse(payload, 200);
}
