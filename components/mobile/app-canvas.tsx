"use client";

import { useMemo, useRef } from "react";
import type { ReactNode, TouchEvent } from "react";

export type CanvasPanel = "center" | "right" | "down";

type AppCanvasProps = {
  panel: CanvasPanel;
  onPanelChange: (panel: CanvasPanel) => void;
  center: ReactNode;
  right: ReactNode;
  down: ReactNode;
};

type SwipeDirection = "left" | "right" | "up" | "down";

const SWIPE_THRESHOLD = 56;

const PANEL_OFFSET: Record<CanvasPanel, { x: number; y: number }> = {
  center: { x: 0, y: 0 },
  right: { x: 1, y: 0 },
  down: { x: 0, y: 1 },
};

function resolvePanelBySwipe(current: CanvasPanel, direction: SwipeDirection): CanvasPanel {
  if (current === "center") {
    if (direction === "left") {
      return "right";
    }
    if (direction === "up") {
      return "down";
    }
    return "center";
  }

  if (current === "right" && direction === "right") {
    return "center";
  }
  if (current === "down" && direction === "down") {
    return "center";
  }

  return current;
}

export function AppCanvas({ panel, onPanelChange, center, right, down }: AppCanvasProps) {
  const touchStartRef = useRef<{ x: number; y: number } | null>(null);

  const trackStyle = useMemo(() => {
    const offset = PANEL_OFFSET[panel];
    return {
      transform: `translate3d(${offset.x * -100}%, ${offset.y * -100}%, 0)`,
    };
  }, [panel]);

  function handleTouchStart(event: TouchEvent<HTMLDivElement>) {
    const firstTouch = event.changedTouches[0];
    touchStartRef.current = {
      x: firstTouch.clientX,
      y: firstTouch.clientY,
    };
  }

  function handleTouchEnd(event: TouchEvent<HTMLDivElement>) {
    if (!touchStartRef.current) {
      return;
    }

    const firstTouch = event.changedTouches[0];
    const dx = firstTouch.clientX - touchStartRef.current.x;
    const dy = firstTouch.clientY - touchStartRef.current.y;
    touchStartRef.current = null;

    const absX = Math.abs(dx);
    const absY = Math.abs(dy);

    let direction: SwipeDirection | null = null;

    if (absX >= SWIPE_THRESHOLD && absX > absY * 1.2) {
      direction = dx > 0 ? "right" : "left";
    } else if (absY >= SWIPE_THRESHOLD && absY > absX * 1.2) {
      direction = dy > 0 ? "down" : "up";
    }

    if (!direction) {
      return;
    }

    const nextPanel = resolvePanelBySwipe(panel, direction);
    if (nextPanel !== panel) {
      onPanelChange(nextPanel);
    }
  }

  return (
    <div className="app-canvas">
      <div className="app-canvas-viewport" onTouchStart={handleTouchStart} onTouchEnd={handleTouchEnd}>
        <div className="app-canvas-track" style={trackStyle}>
          <section className="app-canvas-panel app-canvas-panel-center">{center}</section>
          <section className="app-canvas-panel app-canvas-panel-right">{right}</section>
          <section className="app-canvas-panel app-canvas-panel-down">{down}</section>
        </div>
      </div>

      {panel === "center" ? null : (
        <button type="button" className="canvas-center-button" onClick={() => onPanelChange("center")}>
          返回专注
        </button>
      )}
    </div>
  );
}

