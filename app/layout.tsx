import type { Metadata, Viewport } from "next";
import { DM_Sans, Noto_Sans_SC } from "next/font/google";
import "./globals.css";
import { AppShell } from "@/components/app-shell";
import { PWARegister } from "@/components/pwa-register";

const contentFont = Noto_Sans_SC({
  subsets: ["latin"],
  weight: ["400", "500", "700"],
  variable: "--font-content",
});

const displayFont = DM_Sans({
  subsets: ["latin"],
  weight: ["500", "700"],
  variable: "--font-display",
});

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
  themeColor: "#f97316",
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
      <body className={`${contentFont.variable} ${displayFont.variable}`}>
        <PWARegister />
        <AppShell>{children}</AppShell>
      </body>
    </html>
  );
}
