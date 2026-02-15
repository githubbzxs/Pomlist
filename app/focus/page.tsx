"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { EndSessionDialog } from "@/components/end-session-dialog";
import { FeedbackState } from "@/components/feedback-state";
import { useElapsedSeconds } from "@/hooks/use-elapsed-seconds";
import { ApiClientError } from "@/lib/client/api-client";
import { endSession, getActiveSession, toggleSessionTask } from "@/lib/client/pomlist-api";
import type { ActiveSession } from "@/lib/client/types";

function formatMmSs(seconds: number): string {
  const safeSeconds = Math.max(0, Math.floor(seconds));
  const minute = Math.floor(safeSeconds / 60);
  const second = safeSeconds % 60;
  return `${String(minute).padStart(2, "0")}:${String(second).padStart(2, "0")}`;
}

function errorToText(error: unknown): string {
  if (error instanceof ApiClientError) {
    return error.message;
  }
  return "操作失败，请稍后重试。";
}

function progressPercent(completed: number, total: number): number {
  if (total <= 0) {
    return 0;
  }
  return Math.round((completed / total) * 100);
}

export default function FocusPage() {
  const router = useRouter();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [ending, setEnding] = useState(false);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [session, setSession] = useState<ActiveSession | null>(null);
  const [tickStartAt, setTickStartAt] = useState<Date | null>(null);

  const extraSeconds = useElapsedSeconds(tickStartAt);
  const displaySeconds = useMemo(() => {
    if (!session) {
      return 0;
    }
    return session.state === "active" ? session.elapsedSeconds + extraSeconds : session.elapsedSeconds;
  }, [session, extraSeconds]);

  const loadSession = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const active = await getActiveSession();
      setSession(active);
      setTickStartAt(active ? new Date() : null);
    } catch (loadError) {
      setError(errorToText(loadError));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadSession();
  }, [loadSession]);

  async function toggleTask(todoId: string, nextCompleted: boolean) {
    if (!session) {
      return;
    }
    setError(null);
    try {
      const updated = await toggleSessionTask(session.id, todoId, nextCompleted);
      setSession(updated);
    } catch (toggleError) {
      setError(errorToText(toggleError));
    }
  }

  async function handleEndSession() {
    if (!session) {
      return;
    }
    setEnding(true);
    setError(null);
    try {
      await endSession(session.id);
      setDialogOpen(false);
      await loadSession();
    } catch (endError) {
      setError(errorToText(endError));
    } finally {
      setEnding(false);
    }
  }

  if (loading) {
    return <FeedbackState variant="loading" title="读取任务钟中" description="正在恢复你的专注状态" />;
  }

  if (!session) {
    return (
      <FeedbackState
        variant="empty"
        title="当前没有进行中的任务钟"
        description="去待办页选择任务后即可开始。"
        action={
          <button type="button" className="btn-primary h-10 px-4 text-sm" onClick={() => router.push("/todo")}>
            去待办页开始
          </button>
        }
      />
    );
  }

  return (
    <div className="focus-layout staggered-reveal">
      <section className="panel focus-hero">
        <p className="subtle-kicker">FOCUS SESSION</p>
        <p className="focus-hero-clock page-title">{formatMmSs(displaySeconds)}</p>
        <div className="progress-track mt-3">
          <div
            className="progress-fill"
            style={{ width: `${progressPercent(session.completedTaskCount, session.totalTaskCount)}%` }}
          />
        </div>
        <div className="mt-3 flex items-center justify-center gap-2">
          <span className="metric-badge">
            {session.completedTaskCount}/{session.totalTaskCount}
          </span>
          <span className="text-xs text-subtle">完成率 {Math.round(session.completionRate)}%</span>
        </div>
      </section>

      <section className="panel p-4">
        <div className="todo-section-title">
          <h2 className="page-title text-xl font-bold text-main">本钟任务</h2>
          <span className="metric-badge">进行中</span>
        </div>

        <ul className="mt-3 focus-task-list">
          {session.tasks.map((task) => (
            <li key={task.todoId} className="focus-task-item">
              <label className="flex min-w-0 flex-1 items-center gap-3">
                <input
                  type="checkbox"
                  checked={task.completed}
                  onChange={(event) => void toggleTask(task.todoId, event.target.checked)}
                  className="h-4 w-4 accent-blue-500"
                />
                <span className={`line-clamp-1 text-sm ${task.completed ? "text-subtle line-through" : "text-main"}`}>
                  {task.title}
                </span>
              </label>
              <span
                className={`rounded-full px-2 py-1 text-[11px] font-semibold ${
                  task.completed
                    ? "border border-[rgba(34,197,94,0.3)] bg-[rgba(34,197,94,0.12)] text-emerald-700"
                    : "bg-[rgba(148,163,184,0.16)] text-subtle"
                }`}
              >
                {task.completed ? "已完成" : "进行中"}
              </span>
            </li>
          ))}
        </ul>
      </section>

      {error ? <p className="app-inline-error">{error}</p> : null}

      <div className="focus-bottom-action">
        <button type="button" onClick={() => setDialogOpen(true)} className="btn-primary text-sm shadow-lg">
          结束并记录
        </button>
      </div>

      <EndSessionDialog
        open={dialogOpen}
        completed={session.completedTaskCount}
        total={session.totalTaskCount}
        onCancel={() => setDialogOpen(false)}
        onConfirm={() => void handleEndSession()}
        confirming={ending}
      />
    </div>
  );
}
