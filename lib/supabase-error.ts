import type { NextResponse } from "next/server";

import { errorResponse } from "@/lib/http";
import type { SupabaseResult } from "@/lib/supabase/shared";
import type { ApiErrorCode, ApiFailure } from "@/types/api";

export function isUniqueActiveSessionError(result: SupabaseResult<unknown>): boolean {
  if (!result.error) {
    return false;
  }

  return (
    result.error.code === "23505" &&
    (result.error.message.includes("focus_sessions_one_active_per_user_idx") ||
      (result.error.details ?? "").includes("focus_sessions_one_active_per_user_idx"))
  );
}

export function toSupabaseErrorResponse(
  result: SupabaseResult<unknown>,
  fallbackMessage: string,
): NextResponse<ApiFailure> {
  const status = result.status >= 500 ? 502 : result.status;
  const message = result.error?.message ?? fallbackMessage;

  let code: ApiErrorCode = "SUPABASE_ERROR";
  if (status === 400) {
    code = "BAD_REQUEST";
  } else if (status === 401) {
    code = "UNAUTHORIZED";
  } else if (status === 403) {
    code = "FORBIDDEN";
  } else if (status === 404) {
    code = "NOT_FOUND";
  } else if (status === 409) {
    code = "CONFLICT";
  }

  return errorResponse(code, message, status, result.error);
}
