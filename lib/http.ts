import { NextResponse } from "next/server";

import type { ApiError, ApiErrorCode, ApiFailure, ApiSuccess } from "@/types/api";

export function successResponse<T>(data: T, status = 200): NextResponse<ApiSuccess<T>> {
  return NextResponse.json<ApiSuccess<T>>(
    {
      success: true,
      data,
    },
    { status },
  );
}

export function errorResponse(
  code: ApiErrorCode,
  message: string,
  status = 400,
  details?: unknown,
): NextResponse<ApiFailure> {
  const error: ApiError =
    details === undefined
      ? { code, message }
      : {
          code,
          message,
          details,
        };

  return NextResponse.json<ApiFailure>(
    {
      success: false,
      error,
    },
    { status },
  );
}

export type JsonBodyResult<T> =
  | { ok: true; data: T }
  | { ok: false; response: NextResponse<ApiFailure> };

export async function parseJsonBody<T>(request: Request): Promise<JsonBodyResult<T>> {
  try {
    const body = (await request.json()) as T;
    return { ok: true, data: body };
  } catch {
    return {
      ok: false,
      response: errorResponse("BAD_REQUEST", "请求体必须是合法 JSON。", 400),
    };
  }
}

export function parseIntegerParam(
  value: string | null,
  fallback: number,
  min: number,
  max: number,
): number {
  if (value === null || value.trim() === "") {
    return fallback;
  }

  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed)) {
    return fallback;
  }

  return Math.min(max, Math.max(min, parsed));
}
