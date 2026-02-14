"use client";

import { usePathname, useRouter } from "next/navigation";
import { useEffect, useMemo } from "react";
import { getAccessToken } from "@/lib/client/session";

function isPublicPath(pathname: string) {
  if (pathname === "/") {
    return true;
  }
  return pathname.startsWith("/auth") || pathname.startsWith("/offline");
}

export function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const isPublic = useMemo(() => isPublicPath(pathname), [pathname]);
  const hasToken = getAccessToken();

  useEffect(() => {
    if (!isPublic && !hasToken) {
      router.replace("/auth");
    }
  }, [isPublic, hasToken, router]);

  if (!isPublic && !hasToken) {
    return (
      <main className="flex min-h-screen items-center justify-center px-6">
        <section className="panel w-full max-w-sm p-6 text-center">
          <p className="page-title text-xl font-bold text-main">Pomlist</p>
          <p className="mt-2 text-sm text-subtle">姝ｅ湪楠岃瘉鐧诲綍鐘舵€?..</p>
        </section>
      </main>
    );
  }

  if (isPublic) {
    return <>{children}</>;
  }

  return <main className="app-shell-authed">{children}</main>;
}

