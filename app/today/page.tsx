"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { ApiClientError } from "@/lib/client/api-client";
import {
  getActiveSession,
  getDashboardMetrics,
  listTodos,
  startSession,
} from "@/lib/client/pomlist-api";
import type { ActiveSession, DashboardMetrics, TodoItem } from "@/lib/client/types";
import { FeedbackState } from "@/components/feedback-state";

function formatDuration(seconds: number): string {
  const minute = Math.floor(seconds / 60);
  if (minute < 60) {
    return `${minute} 分钟`;
  }
  const hour = Math.floor(minute / 60);
  const remain = minute % 60;
  return `${hour} 小时 ${remain} 分钟`;
}

function errorToText(error: unknown): string {
  if (error instanceof ApiClientError) {
    return error.message;
  }
  return "加载失败，请稍后重试。";
}

export default function TodayPage() {
  const router = useRouter();
  const [loading, setLoading] = useState(true);
  const [starting, setStarting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [dashboard, setDashboard] = useState<DashboardMetrics>({
    date: "",
    sessionCount: 0,
    totalDurationSeconds: 0,
    completionRate: 0,
    streakDays: 0,
    completedTaskCount: 0,
  });
  const [activeSession, setActiveSession] = useState<ActiveSession | null>(null);
  const [todos, setTodos] = useState<TodoItem[]>([]);
  const [selectedIds, setSelectedIds] = useState<string[]>([]);

  const pendingTodos = useMemo(() => todos.filter((todo) => todo.status === "pending"), [todos]);

  const loadData = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [dashboardData, active, todoList] = await Promise.all([
        getDashboardMetrics(),
        getActiveSession(),
        listTodos("pending"),
      ]);
      setDashboard(dashboardData);
      setActiveSession(active);
      setTodos(todoList);
      setSelectedIds((prev) => prev.filter((id) => todoList.some((item) => item.id === id)));
    } catch (loadError) {
      setError(errorToText(loadError));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadData();
  }, [loadData]);

  function toggleSelected(todoId: string) {
    setSelectedIds((prev) =>
      prev.includes(todoId) ? prev.filter((id) => id !== todoId) : [...prev, todoId],
    );
  }

  async function handleStartSession() {
    if (selectedIds.length === 0 || starting) {
      return;
    }
    setStarting(true);
    setError(null);
    try {
      await startSession(selectedIds);
      router.push("/focus");
    } catch (startError) {
      setError(errorToText(startError));
    } finally {
      setStarting(false);
    }
  }

  if (loading) {
    return <FeedbackState variant="loading" title="加载今日概览中" description="正在同步任务和复盘数据" />;
  }

  if (error && todos.length === 0) {
    return (
      <FeedbackState
        variant="error"
        title="今日页面加载失败"
        description={error}
        action={
          <button type="button" className="btn-primary h-10 px-4 text-sm" onClick={() => void loadData()}>
            重新加载
          </button>
        }
      />
    );
  }

  return (
    <div className="space-y-4">
      <section className="grid grid-cols-2 gap-3 md:grid-cols-4">
        <article className="panel p-4">
          <p className="text-xs text-subtle">今日任务钟</p>
          <p className="page-title mt-2 text-2xl font-bold text-slate-900">{dashboard.sessionCount}</p>
        </article>
        <article className="panel p-4">
          <p className="text-xs text-subtle">已完成任务</p>
          <p className="page-title mt-2 text-2xl font-bold text-slate-900">{dashboard.completedTaskCount}</p>
        </article>
        <article className="panel p-4">
          <p className="text-xs text-subtle">今日完成率</p>
          <p className="page-title mt-2 text-2xl font-bold text-slate-900">{Math.round(dashboard.completionRate)}%</p>
        </article>
        <article className="panel p-4">
          <p className="text-xs text-subtle">连续天数</p>
          <p className="page-title mt-2 text-2xl font-bold text-slate-900">{dashboard.streakDays} 天</p>
        </article>
      </section>

      <section className="panel p-5">
        <div className="flex items-center justify-between gap-3">
          <div>
            <h2 className="page-title text-xl font-bold text-slate-900">今日专注时长</h2>
            <p className="mt-1 text-sm text-subtle">{formatDuration(dashboard.totalDurationSeconds)}</p>
          </div>
          <button type="button" onClick={() => void loadData()} className="btn-muted h-10 px-4 text-sm">
            刷新
          </button>
        </div>
      </section>

      {activeSession ? (
        <section className="panel p-5">
          <div className="flex items-start justify-between gap-3">
            <div>
              <p className="text-sm text-subtle">当前有进行中的任务钟</p>
              <p className="page-title mt-1 text-3xl font-bold text-slate-900">
                {activeSession.completedTaskCount}/{activeSession.totalTaskCount}
              </p>
            </div>
            <button type="button" onClick={() => router.push("/focus")} className="btn-primary h-11 px-4 text-sm">
              继续专注
            </button>
          </div>
        </section>
      ) : (
        <section className="panel p-5">
          <h2 className="page-title text-xl font-bold text-slate-900">快速开始任务钟</h2>
          <p className="mt-1 text-sm text-subtle">可选择多个任务开始一次任务钟，支持 8/10 结束记录。</p>
          {pendingTodos.length === 0 ? (
            <div className="panel-solid mt-4 p-4 text-sm text-subtle">暂无待办任务，先去待办页添加。</div>
          ) : (
            <div className="mt-4 space-y-2">
              {pendingTodos.slice(0, 6).map((todo) => (
                <label key={todo.id} className="panel-solid flex items-center gap-3 px-3 py-2">
                  <input
                    type="checkbox"
                    checked={selectedIds.includes(todo.id)}
                    onChange={() => toggleSelected(todo.id)}
                    className="h-4 w-4 accent-orange-500"
                  />
                  <span className="line-clamp-1 text-sm text-slate-800">{todo.title}</span>
                </label>
              ))}
            </div>
          )}
          <div className="mt-4 flex items-center gap-3">
            <button
              type="button"
              onClick={handleStartSession}
              disabled={selectedIds.length === 0 || starting}
              className="btn-primary h-11 px-4 text-sm"
            >
              {starting ? "正在开始..." : `开始任务钟（${selectedIds.length}项）`}
            </button>
            <button type="button" onClick={() => router.push("/todo")} className="btn-muted h-11 px-4 text-sm">
              去待办页
            </button>
          </div>
        </section>
      )}

      {error ? <p className="rounded-xl bg-red-50 px-3 py-2 text-sm text-red-700">{error}</p> : null}
    </div>
  );
}

