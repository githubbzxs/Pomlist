import type { NextRequest } from "next/server";

import { requireAuth } from "@/lib/auth";
import { successResponse } from "@/lib/http";
import { createServerClient } from "@/lib/supabase/server";
import { toSupabaseErrorResponse } from "@/lib/supabase-error";

export async function POST(request: NextRequest) {
  const authResult = await requireAuth(request);
  if (!authResult.ok) {
    return authResult.response;
  }

  const client = createServerClient(authResult.context.accessToken);
  const signOutResult = await client.auth.signOut();

  if (signOutResult.error) {
    return toSupabaseErrorResponse(signOutResult, "退出登录失败，请稍后重试。");
  }

  return successResponse({ signedOut: true }, 200);
}
