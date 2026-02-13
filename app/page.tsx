"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { getAccessToken } from "@/lib/client/session";

export default function RootPage() {
  const router = useRouter();

  useEffect(() => {
    const token = getAccessToken();
    router.replace(token ? "/today" : "/auth");
  }, [router]);

  return (
    <main className="flex min-h-screen items-center justify-center px-6">
      <section className="panel w-full max-w-sm p-6 text-center">
        <p className="page-title text-xl font-bold text-slate-900">Pomlist</p>
        <p className="mt-2 text-sm text-subtle">正在为你跳转到合适页面...</p>
      </section>
    </main>
  );
}
