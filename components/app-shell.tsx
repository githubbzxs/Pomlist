"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useMemo } from "react";
import { getAccessToken } from "@/lib/client/session";

type NavItem = {
  href: "/today" | "/todo" | "/focus" | "/analytics";
  label: string;
  subtitle: string;
  icon: string;
};

const NAV_ITEMS: NavItem[] = [
  { href: "/today", label: "今日", subtitle: "概览", icon: "○" },
  { href: "/todo", label: "待办", subtitle: "清单", icon: "▣" },
  { href: "/focus", label: "任务钟", subtitle: "专注", icon: "◉" },
  { href: "/analytics", label: "复盘", subtitle: "趋势", icon: "△" },
];

function getHeaderCopy(pathname: string) {
  if (pathname.startsWith("/today")) {
    return { title: "今天做什么", description: "先挑任务，再开始任务钟" };
  }
  if (pathname.startsWith("/todo")) {
    return { title: "待办清单", description: "先整理清单，再开始专注" };
  }
  if (pathname.startsWith("/focus")) {
    return { title: "专注进行中", description: "边做边勾选，允许手动收钟" };
  }
  if (pathname.startsWith("/analytics")) {
    return { title: "复盘统计", description: "看今天、7天趋势和30天分布" };
  }
  return { title: "Pomlist", description: "任务驱动番茄钟" };
}

function isPublicPath(pathname: string) {
  if (pathname === "/") {
    return true;
  }
  return pathname.startsWith("/auth") || pathname.startsWith("/offline");
}

function NavEntry({
  item,
  active,
}: {
  item: NavItem;
  active: boolean;
}) {
  return (
    <Link
      href={item.href}
      className={`flex items-center gap-3 rounded-xl border px-3 py-2 transition ${
        active
          ? "border-orange-300 bg-orange-50 text-orange-800 shadow-sm"
          : "border-slate-200/70 bg-white/60 text-slate-600 hover:border-orange-200"
      }`}
    >
      <span aria-hidden className="text-lg leading-none">
        {item.icon}
      </span>
      <span className="flex flex-col leading-tight">
        <span className="text-sm font-semibold">{item.label}</span>
        <span className="text-xs opacity-80">{item.subtitle}</span>
      </span>
    </Link>
  );
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
          <p className="page-title text-xl font-bold text-slate-900">Pomlist</p>
          <p className="mt-2 text-sm text-subtle">正在验证登录状态...</p>
        </section>
      </main>
    );
  }

  if (isPublic) {
    return <>{children}</>;
  }

  const header = getHeaderCopy(pathname);

  return (
    <div className="mx-auto flex min-h-screen w-full max-w-7xl md:p-4">
      <aside className="panel m-4 hidden w-64 shrink-0 p-4 md:flex md:flex-col">
        <h1 className="page-title text-2xl font-bold text-slate-900">Pomlist</h1>
        <p className="mt-1 text-sm text-subtle">任务驱动番茄钟</p>
        <nav className="mt-5 flex flex-col gap-2">
          {NAV_ITEMS.map((item) => (
            <NavEntry key={item.href} item={item} active={pathname.startsWith(item.href)} />
          ))}
        </nav>
      </aside>

      <div className="flex min-h-screen flex-1 flex-col pb-24 md:min-h-0 md:pb-6">
        <header className="sticky top-0 z-20 border-b border-slate-200/60 bg-white/75 px-4 py-3 backdrop-blur md:rounded-t-2xl md:px-8">
          <p className="page-title text-2xl font-bold text-slate-900">{header.title}</p>
          <p className="text-sm text-subtle">{header.description}</p>
        </header>
        <main className="w-full flex-1 px-4 py-4 md:px-8 md:py-6">{children}</main>
      </div>

      <nav className="fixed inset-x-0 bottom-0 z-40 border-t border-slate-200/70 bg-white/90 px-3 py-2 backdrop-blur md:hidden">
        <div className="mx-auto grid max-w-lg grid-cols-4 gap-2">
          {NAV_ITEMS.map((item) => {
            const active = pathname.startsWith(item.href);
            return (
              <Link
                key={item.href}
                href={item.href}
                className={`flex flex-col items-center rounded-lg px-2 py-2 text-center transition ${
                  active ? "bg-orange-50 text-orange-700" : "text-slate-500"
                }`}
              >
                <span aria-hidden className="text-sm leading-none">
                  {item.icon}
                </span>
                <span className="mt-1 text-xs font-semibold">{item.label}</span>
              </Link>
            );
          })}
        </div>
      </nav>
    </div>
  );
}
