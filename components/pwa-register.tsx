"use client";

import { useEffect } from "react";

export function PWARegister() {
  useEffect(() => {
    if (!("serviceWorker" in navigator)) {
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
