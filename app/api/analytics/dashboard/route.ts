import type { NextRequest } from "next/server";

import { addDays, loadEndedSessions, startOfUtcDay } from "@/app/api/analytics/_helpers";
import { buildDashboard, computeStreak } from "@/lib/analytics-service";
import { requireAuth } from "@/lib/auth";
import { errorResponse, successResponse } from "@/lib/http";
import { createServerClient } from "@/lib/supabase/server";

export async function GET(request: NextRequest) {
  const authResult = await requireAuth(request);
  if (!authResult.ok) {
    return authResult.response;
  }

  const client = createServerClient(authResult.context.accessToken);
  const now = new Date();
  const start = startOfUtcDay(now);
  const end = addDays(start, 1);
  const streakStart = addDays(start, -90);

  try {
    const [todayRows, streakRows] = await Promise.all([
      loadEndedSessions(client, authResult.context.user.id, start, end),
      loadEndedSessions(client, authResult.context.user.id, streakStart, end),
    ]);

    const streakDays = computeStreak(streakRows, now);
    const dashboard = buildDashboard(todayRows, streakDays, now);
    return successResponse(dashboard, 200);
  } catch (error) {
    return errorResponse(
      "INTERNAL_ERROR",
      error instanceof Error ? error.message : "计算复盘概览失败。",
      500,
    );
  }
}

