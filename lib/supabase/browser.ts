import { SupabaseHttpClient } from "@/lib/supabase/shared";

let cachedBrowserClient: SupabaseHttpClient | null = null;

export function createBrowserClient(accessToken?: string): SupabaseHttpClient {
  return new SupabaseHttpClient({ accessToken });
}

export function getBrowserClient(): SupabaseHttpClient {
  if (!cachedBrowserClient) {
    cachedBrowserClient = createBrowserClient();
  }

  return cachedBrowserClient;
}
