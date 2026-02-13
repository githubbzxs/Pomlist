import type { NextRequest } from "next/server";

import { formatAuthData } from "@/lib/auth-response";
import { errorResponse, parseJsonBody, successResponse } from "@/lib/http";
import { createServerClient } from "@/lib/supabase/server";
import { toSupabaseErrorResponse } from "@/lib/supabase-error";
import { isValidEmail } from "@/lib/validation";

interface SignInBody {
  email?: unknown;
  password?: unknown;
}

export async function POST(request: NextRequest) {
  const parsedBody = await parseJsonBody<SignInBody>(request);
  if (!parsedBody.ok) {
    return parsedBody.response;
  }

  const email = typeof parsedBody.data.email === "string" ? parsedBody.data.email.trim().toLowerCase() : "";
  const password = typeof parsedBody.data.password === "string" ? parsedBody.data.password : "";

  if (!isValidEmail(email)) {
    return errorResponse("VALIDATION_ERROR", "邮箱格式不正确。", 400);
  }
  if (password.length < 6) {
    return errorResponse("VALIDATION_ERROR", "密码长度不能少于 6 位。", 400);
  }

  const client = createServerClient();
  const signInResult = await client.auth.signIn(email, password);
  if (signInResult.error) {
    return toSupabaseErrorResponse(signInResult, "登录失败，请检查邮箱和密码。");
  }

  return successResponse(formatAuthData(signInResult.data), 200);
}
