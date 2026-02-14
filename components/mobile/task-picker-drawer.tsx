"use client";

import { FormEvent, useMemo, useState } from "react";
import type { TodoItem } from "@/lib/client/types";

export type CreateTaskInput = {
  title: string;
  subject: string;
  notes: string;
  category: string;
  tags: string[];
  priority: 1 | 2 | 3;
};

type TaskPickerDrawerProps = {
  open: boolean;
  todos: TodoItem[];
  selectedIds: string[];
  creating: boolean;
  sessionActive: boolean;
  onClose: () => void;
  onToggleTodo: (todoId: string) => Promise<void> | void;
  onCreateTodo: (input: CreateTaskInput) => Promise<void> | void;
};

function readCategory(todo: TodoItem): string {
  const raw = (todo as TodoItem & { category?: unknown }).category;
  return typeof raw === "string" && raw.trim().length > 0 ? raw.trim() : "未分类";
}

function readTags(todo: TodoItem): string[] {
  const raw = (todo as TodoItem & { tags?: unknown }).tags;
  if (!Array.isArray(raw)) {
    return [];
  }
  return raw.filter((item): item is string => typeof item === "string" && item.trim().length > 0);
}

function parseTagsText(input: string): string[] {
  const parts = input
    .split(/[，,\s]+/)
    .map((item) => item.trim())
    .filter((item) => item.length > 0);

  return Array.from(new Set(parts));
}

export function TaskPickerDrawer({
  open,
  todos,
  selectedIds,
  creating,
  sessionActive,
  onClose,
  onToggleTodo,
  onCreateTodo,
}: TaskPickerDrawerProps) {
  const [query, setQuery] = useState("");
  const [title, setTitle] = useState("");
  const [subject, setSubject] = useState("");
  const [notes, setNotes] = useState("");
  const [category, setCategory] = useState("");
  const [tagsText, setTagsText] = useState("");
  const [priority, setPriority] = useState<1 | 2 | 3>(2);

  const pendingTodos = useMemo(() => todos.filter((item) => item.status === "pending"), [todos]);
  const filteredTodos = useMemo(() => {
    const keyword = query.trim().toLowerCase();
    if (keyword.length === 0) {
      return pendingTodos;
    }

    return pendingTodos.filter((todo) => {
      const categoryText = readCategory(todo).toLowerCase();
      const tags = readTags(todo).join(" ").toLowerCase();
      return `${todo.title} ${todo.subject ?? ""} ${categoryText} ${tags}`.toLowerCase().includes(keyword);
    });
  }, [pendingTodos, query]);

  async function handleCreate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const nextTitle = title.trim();
    if (!nextTitle) {
      return;
    }

    await onCreateTodo({
      title: nextTitle,
      subject: subject.trim(),
      notes: notes.trim(),
      category: category.trim() || "未分类",
      tags: parseTagsText(tagsText),
      priority,
    });

    setTitle("");
    setSubject("");
    setNotes("");
    setCategory("");
    setTagsText("");
    setPriority(2);
  }

  return (
    <div className={`task-picker-backdrop ${open ? "is-open" : ""}`} onClick={onClose} aria-hidden={!open}>
      <aside className={`task-picker-drawer ${open ? "is-open" : ""}`} onClick={(event) => event.stopPropagation()}>
        <header className="task-picker-header">
          <div>
            <p className="text-xs text-subtle">从右侧快速管理任务</p>
            <h3 className="page-title text-xl font-bold text-main">添加任务</h3>
          </div>
          <button type="button" className="btn-muted h-9 px-3 text-xs" onClick={onClose}>
            关闭
          </button>
        </header>

        <form onSubmit={(event) => void handleCreate(event)} className="task-picker-create-form">
          <input
            value={title}
            onChange={(event) => setTitle(event.target.value)}
            className="input-base h-10"
            placeholder="任务标题"
          />
          <div className="grid grid-cols-2 gap-2">
            <input
              value={category}
              onChange={(event) => setCategory(event.target.value)}
              className="input-base h-10"
              placeholder="分类（默认未分类）"
            />
            <select
              value={priority}
              onChange={(event) => setPriority(Number(event.target.value) as 1 | 2 | 3)}
              className="input-base h-10"
            >
              <option value={1}>优先级 1</option>
              <option value={2}>优先级 2</option>
              <option value={3}>优先级 3</option>
            </select>
          </div>
          <input
            value={tagsText}
            onChange={(event) => setTagsText(event.target.value)}
            className="input-base h-10"
            placeholder="标签，用逗号或空格分隔"
          />
          <input
            value={subject}
            onChange={(event) => setSubject(event.target.value)}
            className="input-base h-10"
            placeholder="科目（可选）"
          />
          <textarea
            value={notes}
            onChange={(event) => setNotes(event.target.value)}
            className="input-base min-h-20"
            placeholder="备注（可选）"
          />
          <button type="submit" className="btn-primary h-10 text-sm" disabled={creating || !title.trim()}>
            {creating ? "创建中..." : "新建并加入计划"}
          </button>
        </form>

        <section className="task-picker-search">
          <input
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            className="input-base h-10"
            placeholder="搜索待办 / 分类 / 标签"
          />
        </section>

        <section className="task-picker-list">
          <div className="mb-2 flex items-center justify-between text-xs text-subtle">
            <span>待办 {filteredTodos.length}</span>
            <span>{sessionActive ? "会话中" : "已加入"} {selectedIds.length}</span>
          </div>
          {filteredTodos.length === 0 ? (
            <p className="task-picker-empty">没有匹配任务，先新建一个吧。</p>
          ) : (
            <div className="md-task-list">
              {filteredTodos.map((todo) => {
                const selected = selectedIds.includes(todo.id);
                const categoryText = readCategory(todo);
                const tags = readTags(todo);

                return (
                  <button
                    key={todo.id}
                    type="button"
                    className={`md-task-item ${selected ? "is-selected" : ""}`}
                    onClick={() => void onToggleTodo(todo.id)}
                    disabled={sessionActive && selected}
                  >
                    <span className={`md-task-checkbox ${selected ? "is-checked" : ""}`} />
                    <span className="md-task-content">
                      <span className="md-task-text">{todo.title}</span>
                      <span className="task-meta-row">
                        <span className="task-pill">{categoryText}</span>
                        {tags.map((tag) => (
                          <span key={`${todo.id}-${tag}`} className="task-pill task-pill-tag">
                            #{tag}
                          </span>
                        ))}
                      </span>
                    </span>
                  </button>
                );
              })}
            </div>
          )}
        </section>

        <footer className="task-picker-footer">
          <button type="button" className="btn-primary h-10 w-full text-sm" onClick={onClose}>
            完成（{selectedIds.length}）
          </button>
        </footer>
      </aside>
    </div>
  );
}

