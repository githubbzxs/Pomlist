import { SupabaseHttpClient } from "@/lib/supabase/shared";

export function createServerClient(accessToken?: string): SupabaseHttpClient {
  return new SupabaseHttpClient({ accessToken });
}

export function createServerAdminClient(accessToken?: string): SupabaseHttpClient {
  return new SupabaseHttpClient({ accessToken });
}
