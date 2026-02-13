export interface SupabaseErrorPayload {
  code?: string;
  message: string;
  details?: string;
  hint?: string;
}

export interface SupabaseResult<T> {
  data: T | null;
  error: SupabaseErrorPayload | null;
  status: number;
}

export interface SupabaseAuthUser {
  id: string;
  email?: string | null;
}

export interface SupabaseAuthPayload {
  access_token?: string;
  refresh_token?: string;
  expires_in?: number;
  token_type?: string;
  user?: SupabaseAuthUser;
}

export interface SupabaseUserPayload {
  user?: SupabaseAuthUser;
}

interface SupabaseClientConfig {
  url: string;
  apiKey: string;
  accessToken?: string;
}

interface SupabaseRequest {
  method: "GET" | "POST" | "PATCH" | "DELETE";
  path: string;
  query?: Record<string, string | number | boolean | undefined>;
  body?: unknown;
  prefer?: string;
}

interface SupabaseRestRequest {
  table: string;
  method?: "GET" | "POST" | "PATCH" | "DELETE";
  query?: Record<string, string | number | boolean | undefined>;
  body?: unknown;
  prefer?: string;
}

interface SupabaseRpcRequest {
  fn: string;
  query?: Record<string, string | number | boolean | undefined>;
  body?: unknown;
}

interface SupabaseEnv {
  url: string;
  anonKey: string;
  serviceRoleKey?: string;
}

function ensureEnv(name: string, value: string | undefined): string {
  if (!value || value.trim() === "") {
    throw new Error(`缺少环境变量：${name}`);
  }

  return value;
}

function normalizeBaseUrl(rawUrl: string): string {
  return rawUrl.endsWith("/") ? rawUrl.slice(0, -1) : rawUrl;
}

function buildUrl(
  baseUrl: string,
  path: string,
  query?: Record<string, string | number | boolean | undefined>,
): string {
  const url = new URL(path, baseUrl);

  if (!query) {
    return url.toString();
  }

  Object.entries(query).forEach(([key, value]) => {
    if (value === undefined) {
      return;
    }

    url.searchParams.set(key, String(value));
  });

  return url.toString();
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function toSupabaseError(payload: unknown, statusText: string): SupabaseErrorPayload {
  if (isObject(payload)) {
    const code = typeof payload.code === "string" ? payload.code : undefined;
    const message =
      typeof payload.message === "string"
        ? payload.message
        : typeof payload.error_description === "string"
          ? payload.error_description
          : typeof payload.error === "string"
            ? payload.error
            : `Supabase 请求失败：${statusText}`;
    const details = typeof payload.details === "string" ? payload.details : undefined;
    const hint = typeof payload.hint === "string" ? payload.hint : undefined;

    return { code, message, details, hint };
  }

  return { message: `Supabase 请求失败：${statusText}` };
}

async function parseResponsePayload(response: Response): Promise<unknown> {
  if (response.status === 204) {
    return null;
  }

  const contentType = response.headers.get("content-type") ?? "";
  if (contentType.includes("application/json")) {
    return response.json();
  }

  const text = await response.text();
  return text === "" ? null : text;
}

export function getSupabaseEnv(options?: { requireServiceRole?: boolean }): SupabaseEnv {
  const url = ensureEnv(
    "NEXT_PUBLIC_SUPABASE_URL 或 SUPABASE_URL",
    process.env.NEXT_PUBLIC_SUPABASE_URL ?? process.env.SUPABASE_URL,
  );
  const anonKey = ensureEnv("NEXT_PUBLIC_SUPABASE_ANON_KEY", process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY);
  const serviceRoleKey = options?.requireServiceRole
    ? ensureEnv("SUPABASE_SERVICE_ROLE_KEY", process.env.SUPABASE_SERVICE_ROLE_KEY)
    : process.env.SUPABASE_SERVICE_ROLE_KEY;

  return {
    url: normalizeBaseUrl(url),
    anonKey,
    serviceRoleKey,
  };
}

export class SupabaseHttpClient {
  private readonly baseUrl: string;
  private readonly apiKey: string;
  private readonly accessToken?: string;

  constructor(config: SupabaseClientConfig) {
    this.baseUrl = normalizeBaseUrl(config.url);
    this.apiKey = config.apiKey;
    this.accessToken = config.accessToken;
  }

  private buildHeaders(hasBody: boolean, prefer?: string): HeadersInit {
    const headers: Record<string, string> = {
      apikey: this.apiKey,
      Authorization: `Bearer ${this.accessToken ?? this.apiKey}`,
    };

    if (hasBody) {
      headers["Content-Type"] = "application/json";
    }

    if (prefer) {
      headers.Prefer = prefer;
    }

    return headers;
  }

  private async request<T>(request: SupabaseRequest): Promise<SupabaseResult<T>> {
    const url = buildUrl(this.baseUrl, request.path, request.query);
    const hasBody = request.body !== undefined;

    const response = await fetch(url, {
      method: request.method,
      headers: this.buildHeaders(hasBody, request.prefer),
      body: hasBody ? JSON.stringify(request.body) : undefined,
      cache: "no-store",
    });

    const payload = await parseResponsePayload(response);

    if (!response.ok) {
      return {
        data: null,
        error: toSupabaseError(payload, response.statusText),
        status: response.status,
      };
    }

    return {
      data: payload as T,
      error: null,
      status: response.status,
    };
  }

  auth = {
    signUp: (email: string, password: string): Promise<SupabaseResult<SupabaseAuthPayload>> =>
      this.request<SupabaseAuthPayload>({
        method: "POST",
        path: "/auth/v1/signup",
        body: { email, password },
      }),

    signIn: (email: string, password: string): Promise<SupabaseResult<SupabaseAuthPayload>> =>
      this.request<SupabaseAuthPayload>({
        method: "POST",
        path: "/auth/v1/token",
        query: { grant_type: "password" },
        body: { email, password },
      }),

    signOut: (): Promise<SupabaseResult<Record<string, never>>> =>
      this.request<Record<string, never>>({
        method: "POST",
        path: "/auth/v1/logout",
      }),

    getUser: (): Promise<SupabaseResult<SupabaseUserPayload>> =>
      this.request<SupabaseUserPayload>({
        method: "GET",
        path: "/auth/v1/user",
      }),
  };

  rest<T>(request: SupabaseRestRequest): Promise<SupabaseResult<T>> {
    const method = request.method ?? "GET";
    const prefer = request.prefer ?? (method === "GET" ? undefined : "return=representation");

    return this.request<T>({
      method,
      path: `/rest/v1/${request.table}`,
      query: request.query,
      body: request.body,
      prefer,
    });
  }

  rpc<T>(request: SupabaseRpcRequest): Promise<SupabaseResult<T>> {
    return this.request<T>({
      method: "POST",
      path: `/rest/v1/rpc/${request.fn}`,
      query: request.query,
      body: request.body ?? {},
    });
  }
}
