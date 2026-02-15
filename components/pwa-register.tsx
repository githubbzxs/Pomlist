"use client";

import { useEffect } from "react";

export function PWARegister() {
  useEffect(() => {
    if (!("serviceWorker" in navigator)) {
      return;
    }

    const isProduction = process.env.NODE_ENV === "production";

    if (!isProduction) {
      const cleanupDevServiceWorker = async () => {
        const registrations = await navigator.serviceWorker.getRegistrations();
        await Promise.all(registrations.map((registration) => registration.unregister()));

        if ("caches" in window) {
          const cacheKeys = await caches.keys();
          await Promise.all(
            cacheKeys
              .filter((key) => key.startsWith("pomlist-static"))
              .map((key) => caches.delete(key)),
          );
        }
      };

      void cleanupDevServiceWorker();
      return;
    }

    const onReady = () => {
      navigator.serviceWorker.register("/sw.js").catch(() => {
        // 这里静默失败，避免阻塞主流程。
      });
    };

    if (document.readyState === "complete") {
      onReady();
      return;
    }

    window.addEventListener("load", onReady);
    return () => {
      window.removeEventListener("load", onReady);
    };
  }, []);

  return null;
}
