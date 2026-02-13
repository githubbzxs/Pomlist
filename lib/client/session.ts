const LOCAL_ACCESS_TOKEN_KEY = "pomlist.access_token";

const TOKEN_FIELD_NAMES = ["access_token", "accessToken"];

function canUseStorage() {
  return typeof window !== "undefined" && !!window.localStorage;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function deepFindAccessToken(value: unknown, depth = 0): string | null {
  if (depth > 6) {
    return null;
  }

  if (typeof value === "string" && value.trim().length > 0) {
    return value;
  }

  if (Array.isArray(value)) {
    for (const item of value) {
      const token = deepFindAccessToken(item, depth + 1);
      if (token) {
        return token;
      }
    }
    return null;
  }

  if (!isRecord(value)) {
    return null;
  }

  for (const key of TOKEN_FIELD_NAMES) {
    const tokenValue = value[key];
    if (typeof tokenValue === "string" && tokenValue.trim().length > 0) {
      return tokenValue;
    }
  }

  for (const nextValue of Object.values(value)) {
    const token = deepFindAccessToken(nextValue, depth + 1);
    if (token) {
      return token;
    }
  }

  return null;
}

function readSupabaseSessionToken() {
  if (!canUseStorage()) {
    return null;
  }

  const keys = Object.keys(window.localStorage).filter(
    (key) => key.startsWith("sb-") && key.includes("auth-token"),
  );

  for (const key of keys) {
    const raw = window.localStorage.getItem(key);
    if (!raw) {
      continue;
    }

    try {
      const parsed: unknown = JSON.parse(raw);
      const token = deepFindAccessToken(parsed);
      if (token) {
        return token;
      }
    } catch {
      // Supabase 存储结构偶发变化，这里容错处理。
    }
  }

  return null;
}

export function getAccessToken() {
  if (!canUseStorage()) {
    return null;
  }

  const localToken = window.localStorage.getItem(LOCAL_ACCESS_TOKEN_KEY);
  if (localToken) {
    return localToken;
  }

  return readSupabaseSessionToken();
}

export function setAccessToken(token: string) {
  if (!canUseStorage()) {
    return;
  }
  window.localStorage.setItem(LOCAL_ACCESS_TOKEN_KEY, token);
}

export function clearAccessToken() {
  if (!canUseStorage()) {
    return;
  }
  window.localStorage.removeItem(LOCAL_ACCESS_TOKEN_KEY);
}
