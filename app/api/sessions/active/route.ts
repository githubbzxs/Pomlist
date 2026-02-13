import type { NextRequest } from "next/server";

import { requireAuth } from "@/lib/auth";
import { errorResponse, successResponse } from "@/lib/http";
import { toActiveSessionPayload } from "@/lib/session-service";
import { createServerClient } from "@/lib/supabase/server";

export async function GET(request: NextRequest) {
  const authResult = await requireAuth(request);
  if (!authResult.ok) {
    return authResult.response;
  }

  const client = createServerClient(authResult.context.accessToken);
  try {
    const activeSession = await toActiveSessionPayload(client, authResult.context.user.id);
    if (!activeSession) {
      return errorResponse("NOT_FOUND", "当前没有进行中的任务钟。", 404);
    }
    return successResponse(activeSession, 200);
  } catch (error) {
    return errorResponse(
      "INTERNAL_ERROR",
      error instanceof Error ? error.message : "查询任务钟失败。",
      500,
    );
  }
}

