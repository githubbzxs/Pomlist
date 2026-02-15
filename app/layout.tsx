import type { Metadata, Viewport } from "next";
import "./globals.css";
import { AppShell } from "@/components/app-shell";
import { PWARegister } from "@/components/pwa-register";

export const metadata: Metadata = {
  title: {
    default: "Pomlist",
    template: "%s | Pomlist",
  },
  description: "任务驱动番茄钟、待办与复盘统计",
  manifest: "/manifest.webmanifest",
  icons: {
    icon: [
      { url: "/icons/icon-192.svg", type: "image/svg+xml" },
      { url: "/icons/icon-512.svg", type: "image/svg+xml" },
    ],
    apple: "/icons/icon-192.svg",
  },
  appleWebApp: {
    capable: true,
    title: "Pomlist",
    statusBarStyle: "default",
  },
};

export const viewport: Viewport = {
  themeColor: "#f5f5f7",
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="zh-CN" suppressHydrationWarning>
      <body>
        <PWARegister />
        <AppShell>{children}</AppShell>
      </body>
    </html>
  );
}
