"use client";

import { FormEvent, KeyboardEvent, useMemo, useState } from "react";
import type { CSSProperties } from "react";
import type { TodoItem } from "@/lib/client/types";

const DEFAULT_CATEGORY = "未分类";
const DEFAULT_CATEGORY_COLOR = "#38bdf8";

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
  categoryColorMap: Record<string, string>;
  tagOptions: string[];
  creating: boolean;
  sessionActive: boolean;
  onClose: () => void;
  onToggleTodo: (todoId: string) => Promise<void> | void;
  onCreateTodo: (input: CreateTaskInput) => Promise<void> | void;
};

function readCategory(todo: TodoItem): string {
  const raw = (todo as TodoItem & { category?: unknown }).category;
  return typeof raw === "string" && raw.trim().length > 0 ? raw.trim() : DEFAULT_CATEGORY;
}

function readTags(todo: TodoItem): string[] {
  const raw = (todo as TodoItem & { tags?: unknown }).tags;
  if (!Array.isArray(raw)) {
    return [];
  }
  return raw.filter((item): item is string => typeof item === "string" && item.trim().length > 0);
}

function mergeUniqueValues(input: string[]): string[] {
  const seen = new Set<string>();
  const result: string[] = [];
  for (const item of input) {
    const value = item.trim();
    if (!value || seen.has(value)) {
      continue;
    }
    seen.add(value);
    result.push(value);
  }
  return result;
}

function parseDraftTags(input: string): { committed: string[]; draft: string } {
  const split = input.split(/[，,\s]+/);
  const endsWithSeparator = /[，,\s]$/.test(input);
  const cleaned = split.map((item) => item.trim()).filter((item) => item.length > 0);
  if (cleaned.length === 0) {
    return { committed: [], draft: "" };
  }
  if (endsWithSeparator) {
    return { committed: cleaned, draft: "" };
  }
  return { committed: cleaned.slice(0, -1), draft: cleaned[cleaned.length - 1] ?? "" };
}

function normalizeHexColor(input: unknown): string | null {
  if (typeof input !== "string") {
    return null;
  }
  const value = input.trim();
  if (!/^#[0-9a-fA-F]{6}$/.test(value)) {
    return null;
  }
  return value.toLowerCase();
}

function hexToRgba(hex: string, alpha: number): string {
  const normalized = normalizeHexColor(hex) ?? DEFAULT_CATEGORY_COLOR;
  const r = Number.parseInt(normalized.slice(1, 3), 16);
  const g = Number.parseInt(normalized.slice(3, 5), 16);
  const b = Number.parseInt(normalized.slice(5, 7), 16);
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

function categoryPillStyle(color: string): CSSProperties {
  return {
    color,
    borderColor: hexToRgba(color, 0.55),
    background: hexToRgba(color, 0.2),
  };
}

export function TaskPickerDrawer({
  open,
  todos,
  selectedIds,
  categoryOptions,
  categoryColorMap,
  tagOptions,
  creating,
  sessionActive,
  onClose,
  onToggleTodo,
  onCreateTodo,
}: TaskPickerDrawerProps) {
  const normalizedCategoryOptions = useMemo(() => {
    if (categoryOptions.length === 0) {
      return [DEFAULT_CATEGORY];
    }
    if (categoryOptions.includes(DEFAULT_CATEGORY)) {
      return categoryOptions;
    }
    return [DEFAULT_CATEGORY, ...categoryOptions];
  }, [categoryOptions]);

  const [title, setTitle] = useState("");
  const [category, setCategory] = useState(DEFAULT_CATEGORY);
  const [tags, setTags] = useState<string[]>([]);
  const [tagDraft, setTagDraft] = useState("");
  const [content, setContent] = useState("");

  const pendingTodos = useMemo(() => todos.filter((item) => item.status === "pending"), [todos]);
  const tagSuggestions = useMemo(
    () => tagOptions.filter((item) => !tags.includes(item)).slice(0, 8),
    [tagOptions, tags],
  );
  const selectedCategory = normalizedCategoryOptions.includes(category)
    ? category
    : (normalizedCategoryOptions[0] ?? DEFAULT_CATEGORY);

  function commitTags(values: string[]) {
    if (values.length === 0) {
      return;
    }
    setTags((prev) => mergeUniqueValues([...prev, ...values]));
  }

  function commitTagDraft() {
    const value = tagDraft.trim();
    if (!value) {
      return;
    }
    commitTags([value]);
    setTagDraft("");
  }

  function handleTagInputChange(value: string) {
    if (!/[，,\s]/.test(value)) {
      setTagDraft(value);
      return;
    }
    const parsed = parseDraftTags(value);
    commitTags(parsed.committed);
    setTagDraft(parsed.draft);
  }

  function handleTagInputKeyDown(event: KeyboardEvent<HTMLInputElement>) {
    if (event.nativeEvent.isComposing) {
      return;
    }
    if (event.key === "Backspace" && !tagDraft && tags.length > 0) {
      event.preventDefault();
      setTags((prev) => prev.slice(0, -1));
      return;
    }
    if (event.key === " " || event.key === "Enter" || event.key === "," || event.key === "，") {
      event.preventDefault();
      commitTagDraft();
    }
  }

  async function handleCreate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const nextTitle = title.trim();
    if (!nextTitle) {
      return;
    }
    const parsed = parseDraftTags(tagDraft);
    const nextTags = mergeUniqueValues([...tags, ...parsed.committed, parsed.draft].filter((item) => item));
    const nextCategory = selectedCategory.trim() || DEFAULT_CATEGORY;

    await onCreateTodo({
      title: nextTitle,
      category: nextCategory,
      tags: nextTags,
      content: content.trim(),
    });

    setTitle("");
    setCategory(normalizedCategoryOptions[0] ?? DEFAULT_CATEGORY);
    setTags([]);
    setTagDraft("");
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
          <input value={title} onChange={(event) => setTitle(event.target.value)} className="input-base h-10" />

          <div className="task-meta-form-grid">
            <label className="task-meta-form-item">
              <span className="task-meta-form-label">分类</span>
              <select
                value={selectedCategory}
                onChange={(event) => setCategory(event.target.value)}
                className="input-base h-10"
              >
                {normalizedCategoryOptions.map((item) => (
                  <option key={item} value={item}>
                    {item}
                  </option>
                ))}
              </select>
            </label>
            <label className="task-meta-form-item">
              <span className="task-meta-form-label">标签</span>
              <div className="tag-input-shell">
                {tags.map((tag) => (
                  <span key={tag} className="tag-input-chip">
                    #{tag}
                    <button
                      type="button"
                      className="tag-input-chip-remove"
                      onClick={() => setTags((prev) => prev.filter((item) => item !== tag))}
                      aria-label={`删除标签 ${tag}`}
                    >
                      ×
                    </button>
                  </span>
                ))}
                <input
                  value={tagDraft}
                  onChange={(event) => handleTagInputChange(event.target.value)}
                  onKeyDown={handleTagInputKeyDown}
                  onBlur={commitTagDraft}
                  className="tag-input-draft"
                />
              </div>
              {tagSuggestions.length > 0 ? (
                <div className="tag-suggestion-row">
                  {tagSuggestions.map((item) => (
                    <button
                      key={item}
                      type="button"
                      className="tag-suggestion-btn"
                      onClick={() => commitTags([item])}
                    >
                      #{item}
                    </button>
                  ))}
                </div>
              ) : null}
            </label>
          </div>

          <label className="task-meta-form-item">
            <span className="task-meta-form-label">具体内容</span>
            <textarea
              value={content}
              onChange={(event) => setContent(event.target.value)}
              className="input-base min-h-[4.5rem] resize-none"
            />
          </label>

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
                const tagsInTodo = readTags(todo);
                const categoryColor = normalizeHexColor(categoryColorMap[categoryText]) ?? DEFAULT_CATEGORY_COLOR;

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
                        <span className="task-pill" style={categoryPillStyle(categoryColor)}>
                          {categoryText}
                        </span>
                        {tagsInTodo.map((tag) => (
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
