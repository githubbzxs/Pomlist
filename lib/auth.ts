import type { NextRequest } from "next/server";
import type { NextResponse } from "next/server";

import { errorResponse } from "@/lib/http";
import { createServerClient } from "@/lib/supabase/server";
import type { ApiFailure } from "@/types/api";

export interface AuthUser {
  id: string;
  email: string | null;
}

export interface AuthContext {
  accessToken: string;
  user: AuthUser;
}

export type RequireAuthResult =
  | { ok: true; context: AuthContext }
  | { ok: false; response: NextResponse<ApiFailure> };

function readBearerToken(request: NextRequest): string | null {
  const header = request.headers.get("authorization");
  if (!header || !header.startsWith("Bearer ")) {
    return null;
  }

  const token = header.slice(7).trim();
  return token === "" ? null : token;
}

export async function requireAuth(request: NextRequest): Promise<RequireAuthResult> {
  const accessToken = readBearerToken(request);
  if (!accessToken) {
    return {
      ok: false,
      response: errorResponse("UNAUTHORIZED", "缺少或非法的 Authorization Bearer token。", 401),
    };
  }

  const client = createServerClient(accessToken);
  const userResult = await client.auth.getUser();

  if (userResult.error || !userResult.data?.user?.id) {
    return {
      ok: false,
      response: errorResponse("UNAUTHORIZED", "登录状态已失效，请重新登录。", 401),
    };
  }

  return {
    ok: true,
    context: {
      accessToken,
      user: {
        id: userResult.data.user.id,
        email: userResult.data.user.email ?? null,
      },
    },
  };
}
