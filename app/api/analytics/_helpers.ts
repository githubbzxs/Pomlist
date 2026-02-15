import type { DbFocusSessionRow } from "@/lib/domain-mappers";
import type { SupabaseHttpClient } from "@/lib/supabase/shared";

export function startOfUtcDay(input: Date): Date {
  return new Date(Date.UTC(input.getUTCFullYear(), input.getUTCMonth(), input.getUTCDate()));
}

export function addDays(input: Date, days: number): Date {
  return new Date(input.getTime() + days * 24 * 60 * 60 * 1000);
}

export async function loadEndedSessions(
  client: SupabaseHttpClient,
  userId: string,
  start: Date,
  end: Date,
): Promise<DbFocusSessionRow[]> {
  const result = await client.rest<DbFocusSessionRow[]>({
    table: "focus_sessions",
    query: {
      select: "*",
      user_id: `eq.${userId}`,
      state: "eq.ended",
      and: `(ended_at.gte.${start.toISOString()},ended_at.lt.${end.toISOString()})`,
      order: "ended_at.desc",
    },
  });

  if (result.error) {
    throw new Error(result.error.message ?? "读取复盘数据失败。");
  }

  return result.data ?? [];
}
