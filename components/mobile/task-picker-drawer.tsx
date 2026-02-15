"use client";

import { FormEvent, useMemo, useState } from "react";
import type { CSSProperties } from "react";
import type { TodoItem } from "@/lib/client/types";

const TAG_COLOR_PALETTE = ["#2563eb", "#06b6d4", "#14b8a6", "#22c55e", "#eab308", "#f97316", "#ef4444", "#8b5cf6"];
const DEFAULT_TAG_COLOR = TAG_COLOR_PALETTE[0];
const DEFAULT_CATEGORY = "未分类";

export type CreateTaskInput = {
  title: string;
  tags: string[];
  content: string;
};

type TaskPickerDrawerProps = {
  open: boolean;
  todos: TodoItem[];
  selectedIds: string[];
  tagOptions: string[];
  tagColorMap: Record<string, string>;
  creating: boolean;
  sessionActive: boolean;
  onClose: () => void;
  onToggleTodo: (todoId: string) => Promise<void> | void;
  onCreateTodo: (input: CreateTaskInput) => Promise<void> | void;
};

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
    if (result.length >= 2) {
      break;
    }
  }
  return result;
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
  const normalized = normalizeHexColor(hex) ?? DEFAULT_TAG_COLOR;
  const r = Number.parseInt(normalized.slice(1, 3), 16);
  const g = Number.parseInt(normalized.slice(3, 5), 16);
  const b = Number.parseInt(normalized.slice(5, 7), 16);
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

function resolveTagColor(tag: string): string {
  const value = tag.trim();
  if (!value) {
    return DEFAULT_TAG_COLOR;
  }
  let hash = 0;
  for (const char of value) {
    hash = (hash * 31 + char.charCodeAt(0)) % 2147483647;
  }
  return TAG_COLOR_PALETTE[Math.abs(hash) % TAG_COLOR_PALETTE.length];
}

function primaryTagPillStyle(color: string): CSSProperties {
  return {
    color,
    borderColor: hexToRgba(color, 0.55),
    background: hexToRgba(color, 0.2),
  };
}

function readLegacyCategory(todo: TodoItem): string | null {
  const raw = (todo as TodoItem & { category?: unknown }).category;
  if (typeof raw !== "string") {
    return null;
  }
  const value = raw.trim();
  if (!value || value === DEFAULT_CATEGORY) {
    return null;
  }
  return value;
}

function readTagLevels(todo: TodoItem): string[] {
  const raw = (todo as TodoItem & { tags?: unknown }).tags;
  if (Array.isArray(raw)) {
    const normalized = mergeUniqueValues(raw.filter((item): item is string => typeof item === "string"));
    if (normalized.length > 0) {
      return normalized;
    }
  }

  const fallback = readLegacyCategory(todo);
  return fallback ? [fallback] : [];
}

export function TaskPickerDrawer({
  open,
  todos,
  selectedIds,
  tagOptions,
  tagColorMap,
  creating,
  sessionActive,
  onClose,
  onToggleTodo,
  onCreateTodo,
}: TaskPickerDrawerProps) {
  const [title, setTitle] = useState("");
  const [primaryTag, setPrimaryTag] = useState("");
  const [secondaryTag, setSecondaryTag] = useState("");
  const [content, setContent] = useState("");
  const [createMode, setCreateMode] = useState(false);

  const pendingTodos = useMemo(() => todos.filter((item) => item.status === "pending"), [todos]);
  const primarySuggestions = useMemo(
    () => tagOptions.filter((item) => item !== secondaryTag).slice(0, 8),
    [tagOptions, secondaryTag],
  );
  const secondarySuggestions = useMemo(
    () => tagOptions.filter((item) => item !== primaryTag).slice(0, 8),
    [tagOptions, primaryTag],
  );

  function resetCreateForm() {
    setCreateMode(false);
    setTitle("");
    setPrimaryTag("");
    setSecondaryTag("");
    setContent("");
  }

  function handleClose() {
    resetCreateForm();
    onClose();
  }

  async function handleCreate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const nextTitle = title.trim();
    if (!nextTitle) {
      return;
    }

    const tags = mergeUniqueValues([primaryTag, secondaryTag]);

    await onCreateTodo({
      title: nextTitle,
      tags,
      content: content.trim(),
    });

    resetCreateForm();
  }

  return (
    <div className={`task-picker-backdrop ${open ? "is-open" : ""}`} onClick={handleClose} aria-hidden={!open}>
      <aside
        className={`task-picker-drawer panel-glass-task ${open ? "is-open" : ""}`}
        onClick={(event) => event.stopPropagation()}
      >
        <header className="task-picker-header">
          <div className="task-picker-header-main">
            <h3 className="page-title text-xl font-bold text-main">选择任务</h3>
            <p className="subtle-kicker">从任务库中选择并加入本次计划</p>
          </div>
          <div className="task-picker-header-actions">
            <button
              type="button"
              className="task-picker-create-toggle"
              onClick={() => setCreateMode((prev) => !prev)}
              disabled={creating}
            >
              {createMode ? "收起新建" : "+ 新建项目"}
            </button>
            <button type="button" className="btn-muted h-9 px-3 text-xs" onClick={handleClose}>
              关闭
            </button>
          </div>
        </header>

        {createMode ? (
          <form onSubmit={(event) => void handleCreate(event)} className="task-picker-create-form">
            <p className="task-picker-create-kicker">新建后会自动加入当前计划</p>
            <input
              value={title}
              onChange={(event) => setTitle(event.target.value)}
              className="input-base h-10"
              placeholder="任务标题"
            />

            <div className="task-meta-form-grid">
              <label className="task-meta-form-item">
                <span className="task-meta-form-label">一级标签</span>
                <input
                  value={primaryTag}
                  onChange={(event) => setPrimaryTag(event.target.value)}
                  className="input-base h-10"
                  placeholder="例如：工作"
                />
                {primarySuggestions.length > 0 ? (
                  <div className="tag-suggestion-row">
                    {primarySuggestions.map((item) => (
                      <button
                        key={item}
                        type="button"
                        className="tag-suggestion-btn"
                        onClick={() => setPrimaryTag(item)}
                      >
                        {item}
                      </button>
                    ))}
                  </div>
                ) : null}
              </label>

              <label className="task-meta-form-item">
                <span className="task-meta-form-label">二级标签</span>
                <input
                  value={secondaryTag}
                  onChange={(event) => setSecondaryTag(event.target.value)}
                  className="input-base h-10"
                  placeholder="例如：会议"
                />
                {secondarySuggestions.length > 0 ? (
                  <div className="tag-suggestion-row">
                    {secondarySuggestions.map((item) => (
                      <button
                        key={item}
                        type="button"
                        className="tag-suggestion-btn"
                        onClick={() => setSecondaryTag(item)}
                      >
                        {item}
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
        ) : null}

        <section className="task-picker-list">
          <div className="mb-2 flex items-center justify-between text-xs text-subtle">
            <span>任务库待办 {pendingTodos.length}</span>
            <span>
              {sessionActive ? "会话中" : "已加入"} {selectedIds.length}
            </span>
          </div>
          {pendingTodos.length === 0 ? null : (
            <div className="md-task-list">
              {pendingTodos.map((todo) => {
                const selected = selectedIds.includes(todo.id);
                const tagLevels = readTagLevels(todo);
                const primary = tagLevels[0];
                const secondary = tagLevels[1];
                const primaryColor = primary
                  ? normalizeHexColor(tagColorMap[primary]) ?? resolveTagColor(primary)
                  : DEFAULT_TAG_COLOR;

                return (
                  <button
                    key={todo.id}
                    type="button"
                    className={`md-task-item glass-item ${selected ? "is-selected" : ""}`}
                    onClick={() => void onToggleTodo(todo.id)}
                    disabled={sessionActive && selected}
                  >
                    <span className={`md-task-checkbox ${selected ? "is-checked" : ""}`} />
                    <span className="md-task-content">
                      <span className="md-task-text">{todo.title}</span>
                      <span className="task-meta-row">
                        {primary ? (
                          <span className="task-pill" style={primaryTagPillStyle(primaryColor)}>
                            {primary}
                          </span>
                        ) : (
                          <span className="task-meta-muted">未设置标签</span>
                        )}
                        {secondary ? <span className="task-pill task-pill-tag">{secondary}</span> : null}
                      </span>
                    </span>
                  </button>
                );
              })}
            </div>
          )}
          {pendingTodos.length === 0 ? (
            <p className="task-picker-empty">任务库暂无可选任务，可点右上角“新建项目”。</p>
          ) : null}
        </section>

        <footer className="task-picker-footer">
          <button type="button" className="btn-primary h-10 w-full text-sm" onClick={handleClose}>
            完成选择（{selectedIds.length}）
          </button>
        </footer>
      </aside>
    </div>
  );
}
