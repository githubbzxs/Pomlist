import { SupabaseHttpClient, getSupabaseEnv } from "@/lib/supabase/shared";

export function createServerClient(accessToken?: string): SupabaseHttpClient {
  const env = getSupabaseEnv({ requireServiceRole: false });

  return new SupabaseHttpClient({
    url: env.url,
    apiKey: env.anonKey,
    accessToken,
  });
}

export function createServerAdminClient(accessToken?: string): SupabaseHttpClient {
  const env = getSupabaseEnv({ requireServiceRole: true });

  return new SupabaseHttpClient({
    url: env.url,
    apiKey: env.serviceRoleKey!,
    accessToken,
  });
}
