import type { NextRequest } from "next/server";

import { loadEndedSessions } from "@/app/api/analytics/_helpers";
import { buildTrend, resolveRecentRange } from "@/lib/analytics-service";
import { requireAuth } from "@/lib/auth";
import { errorResponse, parseIntegerParam, successResponse } from "@/lib/http";
import { createServerClient } from "@/lib/supabase/server";

export async function GET(request: NextRequest) {
  const authResult = await requireAuth(request);
  if (!authResult.ok) {
    return authResult.response;
  }

  const days = parseIntegerParam(request.nextUrl.searchParams.get("days"), 7, 1, 60);
  const range = resolveRecentRange(days, new Date());
  const client = createServerClient(authResult.context.accessToken);

  try {
    const rows = await loadEndedSessions(client, authResult.context.user.id, range.start, range.end);
    const trend = buildTrend(rows, days);
    return successResponse(trend, 200);
  } catch (error) {
    return errorResponse(
      "INTERNAL_ERROR",
      error instanceof Error ? error.message : "读取趋势数据失败。",
      500,
    );
  }
}

