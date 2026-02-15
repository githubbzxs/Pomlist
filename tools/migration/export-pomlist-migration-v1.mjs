#!/usr/bin/env node

import { randomUUID } from "node:crypto";
import { promises as fs } from "node:fs";
import path from "node:path";

const SCHEMA = "PomlistMigrationV1";
const DEFAULT_INPUT = "data/pomlist-db.json";
const DEFAULT_OUTPUT_DIR = "tools/migration/output";

function printHelp() {
  console.log(`将旧版 pomlist-db.json 导出为 ${SCHEMA}。\n
用法:
  node tools/migration/export-pomlist-migration-v1.mjs [options]

参数:
  -i, --input <path>    输入文件路径（默认: ${DEFAULT_INPUT}）
  -o, --output <path>   输出文件路径（默认: ${DEFAULT_OUTPUT_DIR}/${SCHEMA}-时间戳.json）
  -h, --help            显示帮助`);
}

function parseArgs(argv) {
  const options = {
    input: DEFAULT_INPUT,
    output: null,
    help: false,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "-h" || arg === "--help") {
      options.help = true;
      continue;
    }

    if (arg === "-i" || arg === "--input") {
      const value = argv[i + 1];
      if (!value) {
        throw new Error("缺少 --input 参数值");
      }
      options.input = value;
      i += 1;
      continue;
    }

    if (arg === "-o" || arg === "--output") {
      const value = argv[i + 1];
      if (!value) {
        throw new Error("缺少 --output 参数值");
      }
      options.output = value;
      i += 1;
      continue;
    }

    throw new Error(`不支持的参数: ${arg}`);
  }

  return options;
}

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function toArray(value) {
  return Array.isArray(value) ? value : [];
}

function toString(value, fallback = "") {
  return typeof value === "string" ? value : fallback;
}

function toNullableString(value) {
  if (value === null || value === undefined) {
    return null;
  }
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length === 0 ? null : trimmed;
}

function toInteger(value, fallback = 0) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    return fallback;
  }
  return Math.floor(parsed);
}

function toNonNegativeInteger(value, fallback = 0) {
  return Math.max(0, toInteger(value, fallback));
}

function normalizePriority(value) {
  return Math.min(3, Math.max(1, Math.round(Number(value) || 2)));
}

function normalizeStatus(value) {
  if (value === "pending" || value === "completed" || value === "archived") {
    return value;
  }
  return "pending";
}

function normalizeTags(value, category) {
  const set = new Set();
  if (Array.isArray(value)) {
    for (const tag of value) {
      if (typeof tag !== "string") {
        continue;
      }
      const trimmed = tag.trim();
      if (trimmed.length > 0) {
        set.add(trimmed);
      }
    }
  }

  if (category) {
    set.add(category);
  }

  return [...set];
}

function ensureId(value, warnings, hint) {
  if (typeof value === "string" && value.trim() !== "") {
    return value.trim();
  }
  const generated = randomUUID();
  warnings.push(`${hint} 缺少 id，已自动生成 ${generated}`);
  return generated;
}

function normalizeTodo(raw, index, warnings) {
  if (!isObject(raw)) {
    warnings.push(`todos[${index}] 不是对象，已跳过`);
    return null;
  }

  const id = ensureId(raw.id, warnings, `todos[${index}]`);
  const title = toString(raw.title, "").trim() || `未命名任务 ${index + 1}`;
  const category = toString(raw.category, "").trim() || "未分类";

  return {
    id,
    title,
    subject: toNullableString(raw.subject),
    notes: toNullableString(raw.notes),
    category,
    tags: normalizeTags(raw.tags, category),
    priority: normalizePriority(raw.priority),
    status: normalizeStatus(raw.status),
    dueAt: toNullableString(raw.due_at),
    completedAt: toNullableString(raw.completed_at),
    createdAt: toString(raw.created_at, new Date().toISOString()),
    updatedAt: toString(raw.updated_at, new Date().toISOString()),
  };
}

function normalizeSession(raw, index, warnings) {
  if (!isObject(raw)) {
    warnings.push(`focus_sessions[${index}] 不是对象，已跳过`);
    return null;
  }

  const id = ensureId(raw.id, warnings, `focus_sessions[${index}]`);
  const totalTaskCount = toNonNegativeInteger(raw.total_task_count, 0);
  const completedTaskCount = Math.min(
    toNonNegativeInteger(raw.completed_task_count, 0),
    totalTaskCount,
  );

  return {
    id,
    state: raw.state === "ended" ? "ended" : "active",
    startedAt: toString(raw.started_at, new Date().toISOString()),
    endedAt: toNullableString(raw.ended_at),
    elapsedSeconds: toNonNegativeInteger(raw.elapsed_seconds, 0),
    totalTaskCount,
    completedTaskCount,
    completionRate:
      totalTaskCount > 0 ? Number((completedTaskCount / totalTaskCount).toFixed(4)) : 0,
    createdAt: toString(raw.created_at, new Date().toISOString()),
    updatedAt: toString(raw.updated_at, new Date().toISOString()),
  };
}

function normalizeSessionTask(raw, index, warnings, todoTitleById) {
  if (!isObject(raw)) {
    warnings.push(`session_task_refs[${index}] 不是对象，已跳过`);
    return null;
  }

  const sessionId = toString(raw.session_id, "").trim();
  if (!sessionId) {
    warnings.push(`session_task_refs[${index}] 缺少 session_id，已跳过`);
    return null;
  }

  const todoId = toNullableString(raw.todo_id);
  return {
    id: ensureId(raw.id, warnings, `session_task_refs[${index}]`),
    sessionId,
    todoId,
    todoTitle: todoId ? todoTitleById.get(todoId) ?? null : null,
    titleSnapshot: toNullableString(raw.title_snapshot),
    orderIndex: toNonNegativeInteger(raw.order_index, 0),
    completed: Boolean(raw.is_completed_in_session),
    completedAt: toNullableString(raw.completed_at),
    createdAt: toString(raw.created_at, new Date().toISOString()),
    updatedAt: toString(raw.updated_at, new Date().toISOString()),
  };
}

function toOutputPath(input) {
  const date = new Date();
  const ts = [
    date.getFullYear(),
    String(date.getMonth() + 1).padStart(2, "0"),
    String(date.getDate()).padStart(2, "0"),
    "-",
    String(date.getHours()).padStart(2, "0"),
    String(date.getMinutes()).padStart(2, "0"),
    String(date.getSeconds()).padStart(2, "0"),
  ].join("");
  const filename = `${SCHEMA}-${ts}.json`;
  if (input) {
    return path.isAbsolute(input) ? input : path.resolve(process.cwd(), input);
  }
  return path.resolve(process.cwd(), DEFAULT_OUTPUT_DIR, filename);
}

function normalizeSourcePath(filePath) {
  const relative = path.relative(process.cwd(), filePath);
  const normalized = relative && !relative.startsWith("..") ? relative : filePath;
  return normalized.split(path.sep).join("/");
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  if (options.help) {
    printHelp();
    return;
  }

  const inputPath = path.isAbsolute(options.input)
    ? options.input
    : path.resolve(process.cwd(), options.input);
  const outputPath = toOutputPath(options.output);

  const rawText = await fs.readFile(inputPath, "utf8");
  const raw = JSON.parse(rawText);
  if (!isObject(raw)) {
    throw new Error("输入 JSON 顶层必须是对象");
  }

  const warnings = [];
  const todos = toArray(raw.todos)
    .map((item, index) => normalizeTodo(item, index, warnings))
    .filter(Boolean);

  const todoTitleById = new Map(todos.map((todo) => [todo.id, todo.title]));

  const sessions = toArray(raw.focus_sessions)
    .map((item, index) => normalizeSession(item, index, warnings))
    .filter(Boolean);

  const refs = toArray(raw.session_task_refs)
    .map((item, index) => normalizeSessionTask(item, index, warnings, todoTitleById))
    .filter(Boolean);

  const refsBySession = new Map();
  for (const ref of refs) {
    const list = refsBySession.get(ref.sessionId) ?? [];
    list.push(ref);
    refsBySession.set(ref.sessionId, list);
  }

  for (const list of refsBySession.values()) {
    list.sort((a, b) => a.orderIndex - b.orderIndex);
  }

  const sessionIdSet = new Set(sessions.map((session) => session.id));
  const orphanSessionTasks = refs.filter((ref) => !sessionIdSet.has(ref.sessionId));

  const sessionPayload = sessions.map((session) => ({
    ...session,
    tasks: refsBySession.get(session.id) ?? [],
  }));

  const user = toArray(raw.users)[0] ?? null;
  const auth = isObject(raw.auth) ? raw.auth : null;

  const payload = {
    schema: SCHEMA,
    exportedAt: new Date().toISOString(),
    source: {
      type: "pomlist-db.json",
      version: Number.isFinite(Number(raw.version)) ? Number(raw.version) : null,
      path: normalizeSourcePath(inputPath),
    },
    user: {
      id: toNullableString(user?.id),
      email: toNullableString(user?.email),
      passcodeUpdatedAt: toNullableString(auth?.updated_at),
      passcode:
        typeof auth?.passcode === "string" && auth.passcode.length === 4
          ? auth.passcode
          : null,
    },
    todos,
    sessions: sessionPayload,
    orphanSessionTasks,
    summary: {
      todoCount: todos.length,
      sessionCount: sessionPayload.length,
      sessionTaskCount: refs.length,
      orphanSessionTaskCount: orphanSessionTasks.length,
      warningCount: warnings.length,
    },
    warnings,
  };

  await fs.mkdir(path.dirname(outputPath), { recursive: true });
  await fs.writeFile(outputPath, `${JSON.stringify(payload, null, 2)}\n`, "utf8");

  console.log(`导出完成: ${normalizeSourcePath(outputPath)}`);
  console.log(
    `任务 ${payload.summary.todoCount}，会话 ${payload.summary.sessionCount}，会话任务 ${payload.summary.sessionTaskCount}，告警 ${payload.summary.warningCount}`,
  );
}

main().catch((error) => {
  console.error("导出失败:", error instanceof Error ? error.message : error);
  process.exit(1);
});
