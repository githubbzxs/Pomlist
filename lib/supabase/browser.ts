import { SupabaseHttpClient } from "@/lib/supabase/shared";

interface BrowserEnv {
  url: string;
  anonKey: string;
}

let cachedBrowserClient: SupabaseHttpClient | null = null;

function getBrowserEnv(): BrowserEnv {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!url || url.trim() === "") {
    throw new Error("缺少环境变量：NEXT_PUBLIC_SUPABASE_URL");
  }

  if (!anonKey || anonKey.trim() === "") {
    throw new Error("缺少环境变量：NEXT_PUBLIC_SUPABASE_ANON_KEY");
  }

  return {
    url,
    anonKey,
  };
}

export function createBrowserClient(accessToken?: string): SupabaseHttpClient {
  const env = getBrowserEnv();

  return new SupabaseHttpClient({
    url: env.url,
    apiKey: env.anonKey,
    accessToken,
  });
}

export function getBrowserClient(): SupabaseHttpClient {
  if (cachedBrowserClient) {
    return cachedBrowserClient;
  }

  cachedBrowserClient = createBrowserClient();
  return cachedBrowserClient;
}
