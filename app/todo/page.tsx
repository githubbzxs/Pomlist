"use client";

import { FormEvent, useCallback, useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { ApiClientError } from "@/lib/client/api-client";
import {
  createTodo,
  deleteTodo,
  listTodos,
  startSession,
  updateTodo,
} from "@/lib/client/pomlist-api";
import type { TodoItem } from "@/lib/client/types";
import { FeedbackState } from "@/components/feedback-state";

function errorToText(error: unknown): string {
  if (error instanceof ApiClientError) {
    return error.message;
  }
  return "操作失败，请稍后重试。";
}

export default function TodoPage() {
  const router = useRouter();
  const [todos, setTodos] = useState<TodoItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [starting, setStarting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [title, setTitle] = useState("");
  const [subject, setSubject] = useState("");
  const [notes, setNotes] = useState("");
  const [priority, setPriority] = useState<1 | 2 | 3>(2);
  const [dueAt, setDueAt] = useState("");

  const [selectedIds, setSelectedIds] = useState<string[]>([]);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editingTitle, setEditingTitle] = useState("");

  const pendingTodos = useMemo(() => todos.filter((todo) => todo.status === "pending"), [todos]);
  const completedTodos = useMemo(() => todos.filter((todo) => todo.status === "completed"), [todos]);

  const loadTodos = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const items = await listTodos();
      setTodos(items);
      setSelectedIds((prev) =>
        prev.filter((id) => items.some((item) => item.id === id && item.status === "pending")),
      );
    } catch (loadError) {
      setError(errorToText(loadError));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadTodos();
  }, [loadTodos]);

  function toggleSelected(todoId: string) {
    setSelectedIds((prev) =>
      prev.includes(todoId) ? prev.filter((id) => id !== todoId) : [...prev, todoId],
    );
  }

  async function handleCreate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!title.trim() || saving) {
      return;
    }

    setSaving(true);
    setError(null);
    try {
      const created = await createTodo({
        title: title.trim(),
        subject: subject.trim() || null,
        notes: notes.trim() || null,
        priority,
        dueAt: dueAt ? new Date(dueAt).toISOString() : null,
      });
      setTodos((prev) => [created, ...prev]);
      setTitle("");
      setSubject("");
      setNotes("");
      setPriority(2);
      setDueAt("");
    } catch (createError) {
      setError(errorToText(createError));
    } finally {
      setSaving(false);
    }
  }

  async function handleToggleStatus(todo: TodoItem) {
    setError(null);
    try {
      const nextCompleted = todo.status !== "completed";
      const updated = await updateTodo(todo.id, { completed: nextCompleted });
      setTodos((prev) => prev.map((item) => (item.id === todo.id ? updated : item)));
      if (nextCompleted) {
        setSelectedIds((prev) => prev.filter((id) => id !== todo.id));
      }
    } catch (toggleError) {
      setError(errorToText(toggleError));
    }
  }

  async function handleDelete(todo: TodoItem) {
    setError(null);
    try {
      await deleteTodo(todo.id);
      setTodos((prev) => prev.filter((item) => item.id !== todo.id));
      setSelectedIds((prev) => prev.filter((id) => id !== todo.id));
    } catch (deleteError) {
      setError(errorToText(deleteError));
    }
  }

  function startEdit(todo: TodoItem) {
    setEditingId(todo.id);
    setEditingTitle(todo.title);
  }

  async function saveEdit(todoId: string) {
    const nextTitle = editingTitle.trim();
    if (!nextTitle) {
      setError("任务标题不能为空。");
      return;
    }

    setSaving(true);
    setError(null);
    try {
      const updated = await updateTodo(todoId, { title: nextTitle });
      setTodos((prev) => prev.map((item) => (item.id === todoId ? updated : item)));
      setEditingId(null);
      setEditingTitle("");
    } catch (editError) {
      setError(errorToText(editError));
    } finally {
      setSaving(false);
    }
  }

  async function handleStartSession() {
    if (selectedIds.length === 0 || starting) {
      return;
    }

    setStarting(true);
    setError(null);
    try {
      await startSession(selectedIds);
      setSelectedIds([]);
      router.push("/focus");
    } catch (startError) {
      setError(errorToText(startError));
    } finally {
      setStarting(false);
    }
  }

  if (loading) {
    return (
      <FeedbackState
        variant="loading"
        title="加载待办中"
        description="正在读取你的任务清单"
      />
    );
  }

  if (todos.length === 0 && error) {
    return (
      <FeedbackState
        variant="error"
        title="加载失败"
        description={error}
        action={
          <button type="button" className="btn-primary h-10 px-4 text-sm" onClick={() => void loadTodos()}>
            重新加载
          </button>
        }
      />
    );
  }

  return (
    <div className="space-y-4 pb-20">
      <section className="panel p-4">
        <h2 className="page-title text-xl font-bold text-slate-900">新建任务</h2>
        <form onSubmit={handleCreate} className="mt-3 grid gap-3 md:grid-cols-2">
          <input
            value={title}
            onChange={(event) => setTitle(event.target.value)}
            className="input-base md:col-span-2"
            placeholder="任务标题（必填）"
          />
          <input
            value={subject}
            onChange={(event) => setSubject(event.target.value)}
            className="input-base"
            placeholder="科目（可选）"
          />
          <input
            type="datetime-local"
            value={dueAt}
            onChange={(event) => setDueAt(event.target.value)}
            className="input-base"
          />
          <textarea
            value={notes}
            onChange={(event) => setNotes(event.target.value)}
            className="input-base md:col-span-2 min-h-20"
            placeholder="备注（可选）"
          />
          <div className="flex items-center gap-3">
            <span className="text-sm text-slate-600">优先级</span>
            <select
              value={priority}
              onChange={(event) => setPriority(Number(event.target.value) as 1 | 2 | 3)}
              className="input-base h-11 w-36"
            >
              <option value={1}>低</option>
              <option value={2}>中</option>
              <option value={3}>高</option>
            </select>
          </div>
          <button type="submit" disabled={saving || !title.trim()} className="btn-primary h-11 text-sm md:justify-self-end md:w-40">
            {saving ? "保存中..." : "添加任务"}
          </button>
        </form>
      </section>

      {error ? (
        <p className="rounded-xl bg-red-50 px-3 py-2 text-sm text-red-700">{error}</p>
      ) : null}

      <section className="panel p-4">
        <div className="flex items-center justify-between">
          <h2 className="page-title text-xl font-bold text-slate-900">待办任务</h2>
          <span className="rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold text-slate-600">
            {pendingTodos.length} 项
          </span>
        </div>

        {pendingTodos.length === 0 ? (
          <FeedbackState variant="empty" title="暂无待办任务" description="先创建任务，或从已完成中恢复。" />
        ) : (
          <ul className="mt-3 space-y-2">
            {pendingTodos.map((todo) => {
              const isSelected = selectedIds.includes(todo.id);
              const isEditing = editingId === todo.id;
              return (
                <li key={todo.id} className="panel-solid p-3">
                  <div className="flex items-start gap-3">
                    <input
                      type="checkbox"
                      checked={isSelected}
                      onChange={() => toggleSelected(todo.id)}
                      className="mt-1 h-4 w-4 accent-orange-500"
                    />
                    <div className="min-w-0 flex-1">
                      {isEditing ? (
                        <input
                          value={editingTitle}
                          onChange={(event) => setEditingTitle(event.target.value)}
                          className="input-base"
                        />
                      ) : (
                        <>
                          <p className="break-words text-sm text-slate-900">{todo.title}</p>
                          <p className="mt-1 text-xs text-slate-500">
                            优先级 {todo.priority} {todo.subject ? `· ${todo.subject}` : ""}
                          </p>
                        </>
                      )}
                      <div className="mt-2 flex flex-wrap gap-2">
                        <button type="button" className="btn-muted h-9 px-3 text-xs" onClick={() => void handleToggleStatus(todo)}>
                          标记完成
                        </button>
                        {isEditing ? (
                          <>
                            <button type="button" className="btn-primary h-9 px-3 text-xs" onClick={() => void saveEdit(todo.id)} disabled={saving}>
                              保存
                            </button>
                            <button type="button" className="btn-muted h-9 px-3 text-xs" onClick={() => { setEditingId(null); setEditingTitle(""); }}>
                              取消
                            </button>
                          </>
                        ) : (
                          <button type="button" className="btn-muted h-9 px-3 text-xs" onClick={() => startEdit(todo)}>
                            编辑
                          </button>
                        )}
                        <button type="button" className="btn-danger h-9 px-3 text-xs" onClick={() => void handleDelete(todo)}>
                          删除
                        </button>
                      </div>
                    </div>
                  </div>
                </li>
              );
            })}
          </ul>
        )}
      </section>

      <section className="panel p-4">
        <div className="flex items-center justify-between">
          <h2 className="page-title text-xl font-bold text-slate-900">已完成</h2>
          <span className="rounded-full bg-emerald-100 px-3 py-1 text-xs font-semibold text-emerald-700">
            {completedTodos.length} 项
          </span>
        </div>
        {completedTodos.length === 0 ? (
          <p className="mt-3 text-sm text-subtle">还没有已完成任务。</p>
        ) : (
          <ul className="mt-3 space-y-2">
            {completedTodos.map((todo) => (
              <li key={todo.id} className="panel-solid flex items-center justify-between gap-3 p-3">
                <p className="line-clamp-1 text-sm text-slate-500 line-through">{todo.title}</p>
                <div className="flex gap-2">
                  <button type="button" className="btn-muted h-9 px-3 text-xs" onClick={() => void handleToggleStatus(todo)}>
                    恢复
                  </button>
                  <button type="button" className="btn-danger h-9 px-3 text-xs" onClick={() => void handleDelete(todo)}>
                    删除
                  </button>
                </div>
              </li>
            ))}
          </ul>
        )}
      </section>

      <div className="fixed inset-x-0 bottom-16 z-30 px-4 md:bottom-6 md:left-auto md:right-8 md:inset-x-auto md:w-80">
        <button
          type="button"
          onClick={handleStartSession}
          disabled={selectedIds.length === 0 || starting}
          className="btn-primary h-12 w-full text-sm shadow-lg"
        >
          {starting ? "正在开始..." : `开始任务钟（${selectedIds.length}项）`}
        </button>
      </div>
    </div>
  );
}

