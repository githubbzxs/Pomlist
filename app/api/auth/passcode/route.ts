import type { NextRequest } from "next/server";

import { requireAuth } from "@/lib/auth";
import { errorResponse, parseJsonBody, successResponse } from "@/lib/http";
import { createServerClient } from "@/lib/supabase/server";
import { toSupabaseErrorResponse } from "@/lib/supabase-error";
import { isValidPasscode } from "@/lib/validation";

interface UpdatePasscodeBody {
  oldPasscode?: unknown;
  newPasscode?: unknown;
}

export async function PATCH(request: NextRequest) {
  const authResult = await requireAuth(request);
  if (!authResult.ok) {
    return authResult.response;
  }

  const parsedBody = await parseJsonBody<UpdatePasscodeBody>(request);
  if (!parsedBody.ok) {
    return parsedBody.response;
  }

  const oldPasscode =
    typeof parsedBody.data.oldPasscode === "string" ? parsedBody.data.oldPasscode.trim() : "";
  const newPasscode =
    typeof parsedBody.data.newPasscode === "string" ? parsedBody.data.newPasscode.trim() : "";

  if (!isValidPasscode(oldPasscode) || !isValidPasscode(newPasscode)) {
    return errorResponse("VALIDATION_ERROR", "口令必须是 4 个字符。", 400);
  }

  if (oldPasscode === newPasscode) {
    return errorResponse("VALIDATION_ERROR", "新口令不能与旧口令相同。", 400);
  }

  const client = createServerClient(authResult.context.accessToken);
  const updateResult = await client.auth.changePasscode(oldPasscode, newPasscode);
  if (updateResult.error) {
    return toSupabaseErrorResponse(updateResult, "修改口令失败。");
  }

  return successResponse({ updated: true }, 200);
}

