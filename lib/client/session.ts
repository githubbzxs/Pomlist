const LOCAL_ACCESS_TOKEN_KEY = "pomlist.access_token";

function canUseStorage(): boolean {
  return typeof window !== "undefined" && Boolean(window.localStorage);
}

export function getAccessToken(): string | null {
  if (!canUseStorage()) {
    return null;
  }
  return window.localStorage.getItem(LOCAL_ACCESS_TOKEN_KEY);
}

export function setAccessToken(token: string): void {
  if (!canUseStorage()) {
    return;
  }
  window.localStorage.setItem(LOCAL_ACCESS_TOKEN_KEY, token);
}

export function clearAccessToken(): void {
  if (!canUseStorage()) {
    return;
  }
  window.localStorage.removeItem(LOCAL_ACCESS_TOKEN_KEY);
}
