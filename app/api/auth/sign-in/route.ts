import type { NextRequest } from "next/server";

import { formatAuthData } from "@/lib/auth-response";
import { errorResponse, parseJsonBody, successResponse } from "@/lib/http";
import { createServerClient } from "@/lib/supabase/server";
import { toSupabaseErrorResponse } from "@/lib/supabase-error";
import { isValidPasscode } from "@/lib/validation";

interface SignInBody {
  passcode?: unknown;
}

export async function POST(request: NextRequest) {
  const parsedBody = await parseJsonBody<SignInBody>(request);
  if (!parsedBody.ok) {
    return parsedBody.response;
  }

  const passcode = typeof parsedBody.data.passcode === "string" ? parsedBody.data.passcode.trim() : "";

  if (!isValidPasscode(passcode)) {
    return errorResponse("VALIDATION_ERROR", "口令必须是 4 个字符。", 400);
  }

  const client = createServerClient();
  const signInResult = await client.auth.signIn(passcode);
  if (signInResult.error) {
    return toSupabaseErrorResponse(signInResult, "口令错误，请重试。");
  }

  return successResponse(formatAuthData(signInResult.data), 200);
}
