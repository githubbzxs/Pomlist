import type { SupabaseAuthPayload } from "@/lib/supabase/shared";

export interface AuthApiData {
  user: {
    id: string;
    email: string | null;
  } | null;
  session: {
    accessToken: string;
    refreshToken: string | null;
    expiresIn: number | null;
    tokenType: string | null;
  } | null;
}

function toNullableString(value: unknown): string | null {
  return typeof value === "string" ? value : null;
}

function toNullableNumber(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

export function formatAuthData(payload: SupabaseAuthPayload | null): AuthApiData {
  if (!payload) {
    return { user: null, session: null };
  }

  return {
    user: payload.user
      ? {
          id: payload.user.id,
          email: payload.user.email ?? null,
        }
      : null,
    session:
      typeof payload.access_token === "string"
        ? {
            accessToken: payload.access_token,
            refreshToken: toNullableString(payload.refresh_token),
            expiresIn: toNullableNumber(payload.expires_in),
            tokenType: toNullableString(payload.token_type),
          }
        : null,
  };
}
