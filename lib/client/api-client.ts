import { getAccessToken } from "@/lib/client/session";

interface ApiFailurePayload {
  success: false;
  error?: {
    code?: string;
    message?: string;
    details?: unknown;
  };
}

interface ApiSuccessPayload<T> {
  success: true;
  data: T;
}

type ApiPayload<T> = ApiSuccessPayload<T> | ApiFailurePayload | T;

export class ApiClientError extends Error {
  status: number;
  payload: unknown;
  code?: string;

  constructor(message: string, status: number, payload: unknown, code?: string) {
    super(message);
    this.name = "ApiClientError";
    this.status = status;
    this.payload = payload;
    this.code = code;
  }
}

type ApiRequestOptions = RequestInit & {
  auth?: boolean;
};

function isJsonResponse(response: Response): boolean {
  const contentType = response.headers.get("content-type");
  return !!contentType && contentType.includes("application/json");
}

async function parsePayload(response: Response): Promise<unknown> {
  if (response.status === 204) {
    return null;
  }
  if (isJsonResponse(response)) {
    return response.json();
  }
  const text = await response.text();
  return text.length > 0 ? text : null;
}

function mergeHeaders(headers?: HeadersInit): Headers {
  const merged = new Headers(headers);
  if (!merged.has("Content-Type")) {
    merged.set("Content-Type", "application/json");
  }
  return merged;
}

function normalizePath(path: string): string {
  if (path.startsWith("http://") || path.startsWith("https://")) {
    return path;
  }
  return path.startsWith("/") ? path : `/${path}`;
}

function unwrapSuccessData<T>(payload: ApiPayload<T>): T {
  if (
    typeof payload === "object" &&
    payload !== null &&
    "success" in payload &&
    (payload as { success: boolean }).success === true &&
    "data" in payload
  ) {
    return (payload as ApiSuccessPayload<T>).data;
  }
  return payload as T;
}

function readFailure(payload: unknown): { message: string; code?: string } {
  if (
    typeof payload === "object" &&
    payload !== null &&
    "success" in payload &&
    (payload as { success: boolean }).success === false
  ) {
    const error = (payload as ApiFailurePayload).error;
    return {
      message: error?.message ?? "请求失败，请稍后重试。",
      code: error?.code,
    };
  }
  return { message: "请求失败，请稍后重试。" };
}

export async function apiRequest<T>(
  path: string,
  options: ApiRequestOptions = {},
): Promise<T> {
  const { auth = true, ...rest } = options;
  const headers = mergeHeaders(rest.headers);

  if (auth) {
    const token = getAccessToken();
    if (token) {
      headers.set("Authorization", `Bearer ${token}`);
    }
  }

  const response = await fetch(normalizePath(path), {
    ...rest,
    headers,
    cache: "no-store",
  });

  const payload = await parsePayload(response);
  if (!response.ok) {
    const failure = readFailure(payload);
    throw new ApiClientError(failure.message, response.status, payload, failure.code);
  }

  return unwrapSuccessData(payload as ApiPayload<T>);
}

