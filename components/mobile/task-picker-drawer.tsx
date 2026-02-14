"use client";

import { FormEvent, useMemo, useState } from "react";
import type { TodoItem } from "@/lib/client/types";

export type CreateTaskInput = {
  title: string;
  category: string;
  tags: string[];
  content: string;
};

type TaskPickerDrawerProps = {
  open: boolean;
  todos: TodoItem[];
  selectedIds: string[];
  categoryOptions: string[];
  tagOptions: string[];
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
  categoryOptions,
  tagOptions,
  creating,
  sessionActive,
  onClose,
  onToggleTodo,
  onCreateTodo,
}: TaskPickerDrawerProps) {
  const [title, setTitle] = useState("");
  const [category, setCategory] = useState("");
  const [tagsText, setTagsText] = useState("");
  const [content, setContent] = useState("");

  const pendingTodos = useMemo(() => todos.filter((item) => item.status === "pending"), [todos]);

  async function handleCreate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const nextTitle = title.trim();
    if (!nextTitle) {
      return;
    }

    await onCreateTodo({
      title: nextTitle,
      category: category.trim() || "未分类",
      tags: parseTagsText(tagsText),
      content: content.trim(),
    });

    setTitle("");
    setCategory("");
    setTagsText("");
    setContent("");
  }

  return (
    <div className={`task-picker-backdrop ${open ? "is-open" : ""}`} onClick={onClose} aria-hidden={!open}>
      <aside className={`task-picker-drawer ${open ? "is-open" : ""}`} onClick={(event) => event.stopPropagation()}>
        <header className="task-picker-header">
          <h3 className="page-title text-xl font-bold text-main">添加任务</h3>
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

          <div className="task-meta-form-grid">
            <label className="task-meta-form-item">
              <span className="task-meta-form-label">分类</span>
              <input
                value={category}
                onChange={(event) => setCategory(event.target.value)}
                className="input-base h-10"
                list="task-category-options"
                placeholder="默认未分类"
              />
            </label>
            <label className="task-meta-form-item">
              <span className="task-meta-form-label">标签</span>
              <input
                value={tagsText}
                onChange={(event) => setTagsText(event.target.value)}
                className="input-base h-10"
                list="task-tag-options"
                placeholder="逗号分隔多个标签"
              />
            </label>
          </div>

          <label className="task-meta-form-item">
            <span className="task-meta-form-label">具体内容</span>
            <textarea
              value={content}
              onChange={(event) => setContent(event.target.value)}
              className="input-base min-h-[4.5rem] resize-none"
              placeholder="补充任务细节（可选）"
            />
          </label>

          <datalist id="task-category-options">
            {categoryOptions.map((item) => (
              <option key={item} value={item} />
            ))}
          </datalist>
          <datalist id="task-tag-options">
            {tagOptions.map((item) => (
              <option key={item} value={item} />
            ))}
          </datalist>

          <button type="submit" className="btn-primary h-10 text-sm" disabled={creating || !title.trim()}>
            {creating ? "创建中..." : "新建并加入计划"}
          </button>
        </form>

        <section className="task-picker-list">
          <div className="mb-2 flex items-center justify-between text-xs text-subtle">
            <span>待办 {pendingTodos.length}</span>
            <span>
              {sessionActive ? "会话中" : "已加入"} {selectedIds.length}
            </span>
          </div>
          {pendingTodos.length === 0 ? null : (
            <div className="md-task-list">
              {pendingTodos.map((todo) => {
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
