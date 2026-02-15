"use client";

import { useEffect, useState } from "react";

export function useElapsedSeconds(startAt: Date | null): number {
  const [now, setNow] = useState(() => Date.now());

  useEffect(() => {
    if (!startAt) {
      return;
    }

    const timer = window.setInterval(() => {
      setNow(Date.now());
    }, 1000);
    return () => window.clearInterval(timer);
  }, [startAt]);

  if (!startAt) {
    return 0;
  }

  const diff = Math.floor((now - startAt.getTime()) / 1000);
  return Math.max(0, diff);
}
