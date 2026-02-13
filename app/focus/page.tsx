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
    <div className="space-y-4 pb-20">
      <section className="panel p-6 text-center">
        <p className="text-sm text-subtle">当前完成进度</p>
        <p className="page-title mt-2 text-5xl font-bold text-slate-900">
          {session.completedTaskCount}/{session.totalTaskCount}
        </p>
        <p className="mt-2 text-sm text-slate-600">已用时 {formatMmSs(displaySeconds)}</p>
      </section>

      <section className="panel p-4">
        <div className="flex items-center justify-between">
          <h2 className="page-title text-xl font-bold text-slate-900">本钟任务</h2>
          <span className="rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold text-slate-600">
            完成率 {Math.round(session.completionRate)}%
          </span>
        </div>
        <ul className="mt-3 space-y-2">
          {session.tasks.map((task) => (
            <li key={task.todoId} className="panel-solid flex items-center justify-between gap-3 px-3 py-2">
              <label className="flex min-w-0 flex-1 items-center gap-3">
                <input
                  type="checkbox"
                  checked={task.completed}
                  onChange={(event) => void toggleTask(task.todoId, event.target.checked)}
                  className="h-4 w-4 accent-orange-500"
                />
                <span className={`line-clamp-1 text-sm ${task.completed ? "text-slate-500 line-through" : "text-slate-900"}`}>
                  {task.title}
                </span>
              </label>
              <span className={`rounded-full px-2 py-1 text-[11px] font-semibold ${task.completed ? "bg-emerald-100 text-emerald-700" : "bg-slate-100 text-slate-600"}`}>
                {task.completed ? "已完成" : "进行中"}
              </span>
            </li>
          ))}
        </ul>
      </section>

      {error ? <p className="rounded-xl bg-red-50 px-3 py-2 text-sm text-red-700">{error}</p> : null}

      <div className="fixed inset-x-0 bottom-16 z-30 px-4 md:bottom-6 md:left-auto md:right-8 md:inset-x-auto md:w-80">
        <button type="button" onClick={() => setDialogOpen(true)} className="btn-primary h-12 w-full text-sm shadow-lg">
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

