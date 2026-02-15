#!/usr/bin/env node

import { randomUUID } from "node:crypto";
import { promises as fs } from "node:fs";
import path from "node:path";

const DEFAULT_INPUT_PATH = "data/pomlist-db.json";
const DEFAULT_OUTPUT_DIR = "tools/migration/output";
const MIGRATION_SCHEMA = "PomlistMigrationV1";

function printHelp() {
  console.log(
    [
      "将旧版 pomlist-db.json 导出为 PomlistMigrationV1。",
      "",
      "用法：",
      "  node tools/migration/export-pomlist-migration-v1.mjs [options]",
      "",
      "参数：",
      "  -i, --input <path>    输入文件路径（默认：data/pomlist-db.json）",
      "  -o, --output <path>   输出文件路径（默认：tools/migration/output/PomlistMigrationV1-时间戳.json）",
      "  -h, --help            显示帮助",
    ].join("\n"),
  );
}

function parseArgs(argv) {
  const options = {
    input: DEFAULT_INPUT_PATH,
    output: "",
    help: false,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];

    if (arg === "-h" || arg === "--help") {
      options.help = true;
      continue;
    }

    if (arg === "-i" || arg === "--input") {
      const value = argv[index + 1];
      if (!value) {
        throw new Error("缺少 --input 的路径参数。");
      }
      options.input = value;
      index += 1;
      continue;
    }

    if (arg === "-o" || arg === "--output") {
      const value = argv[index + 1];
      if (!value) {
        throw new Error("缺少 --output 的路径参数。");
      }
      options.output = value;
      index += 1;
      continue;
    }

    throw new Error(`不支持的参数：${arg}`);
  }

  return options;
}

function isObject(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value);
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
  return value.trim() === "" ? null : value;
}

function toNonNegativeInteger(value, fallback = 0) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    return fallback;
  }
  return Math.max(0, Math.floor(parsed));
}

function toBoolean(value, fallback = false) {
  return typeof value === "boolean" ? value : fallback;
}

function normalizeStatus(value) {
  if (value === "pending" || value === "completed" || value === "archived") {
    return value;
  }
  return "pending";
}

function normalizePriority(value) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    return 2;
  }
  return Math.min(3, Math.max(1, Math.round(parsed)));
}

function normalizeTags(value) {
  if (!Array.isArray(value)) {
    return [];
  }
  const unique = new Set();
  for (const tag of value) {
    if (typeof tag !== "string") {
      continue;
    }
    const trimmed = tag.trim();
    if (trimmed) {
      unique.add(trimmed);
    }
  }
  return [...unique];
}

function ensureUuid(value, warnings, pathHint) {
  if (typeof value === "string" && value.trim() !== "") {
    return value;
  }
  const generated = randomUUID();
  warnings.push(`${pathHint} 缺少 id，已自动生成：${generated}`);
  return generated;
}

function normalizeTodoRow(rawTodo, index, warnings) {
  if (!isObject(rawTodo)) {
    warnings.push(`todos[${index}] 不是对象，已跳过。`);
    return null;
  }

  const id = ensureUuid(rawTodo.id, warnings, `todos[${index}]`);
  const title = toString(rawTodo.title, "").trim() || `未命名任务-${index + 1}`;
  const category = toString(rawTodo.category, "").trim() || "未分类";
  const tags = normalizeTags(rawTodo.tags);
  if (!tags.includes(category)) {
    tags.unshift(category);
  }

  return {
    id,
    title,
    subject: toNullableString(rawTodo.subject),
    notes: toNullableString(rawTodo.notes),
    category,
    tags,
    priority: normalizePriority(rawTodo.priority),
    status: normalizeStatus(rawTodo.status),
    dueAt: toNullableString(rawTodo.due_at),
    completedAt: toNullableString(rawTodo.completed_at),
    createdAt: toString(rawTodo.created_at, new Date().toISOString()),
    updatedAt: toString(rawTodo.updated_at, new Date().toISOString()),
  };
}

function normalizeSessionRow(rawSession, index, warnings) {
  if (!isObject(rawSession)) {
    warnings.push(`focus_sessions[${index}] 不是对象，已跳过。`);
    return null;
  }

  const id = ensureUuid(rawSession.id, warnings, `focus_sessions[${index}]`);
  const totalTaskCount = toNonNegativeInteger(rawSession.total_task_count, 0);
  const completedTaskCount = Math.min(toNonNegativeInteger(rawSession.completed_task_count, 0), totalTaskCount);
  const completionRate = totalTaskCount > 0 ? Number((completedTaskCount / totalTaskCount).toFixed(4)) : 0;

  return {
    id,
    state: rawSession.state === "ended" ? "ended" : "active",
    startedAt: toString(rawSession.started_at, new Date().toISOString()),
    endedAt: toNullableString(rawSession.ended_at),
    elapsedSeconds: toNonNegativeInteger(rawSession.elapsed_seconds, 0),
    totalTaskCount,
    completedTaskCount,
    completionRate,
    createdAt: toString(rawSession.created_at, new Date().toISOString()),
    updatedAt: toString(rawSession.updated_at, new Date().toISOString()),
  };
}

function normalizeSessionTaskRefRow(rawRef, index, warnings) {
  if (!isObject(rawRef)) {
    warnings.push(`session_task_refs[${index}] 不是对象，已跳过。`);
    return null;
  }

  const sessionId = toString(rawRef.session_id, "").trim();
  if (!sessionId) {
    warnings.push(`session_task_refs[${index}] 缺少 session_id，已跳过。`);
    return null;
  }

  return {
    id: ensureUuid(rawRef.id, warnings, `session_task_refs[${index}]`),
    sessionId,
    todoId: toNullableString(rawRef.todo_id),
    titleSnapshot: toString(rawRef.title_snapshot, "").trim(),
    orderIndex: toNonNegativeInteger(rawRef.order_index, 0),
    completed: toBoolean(rawRef.is_completed_in_session),
    completedAt: toNullableString(rawRef.completed_at),
    createdAt: toString(rawRef.created_at, new Date().toISOString()),
    updatedAt: toString(rawRef.updated_at, new Date().toISOString()),
  };
}

function resolveFilePath(inputPath) {
  return path.isAbsolute(inputPath) ? inputPath : path.resolve(process.cwd(), inputPath);
}

function toFilenameTimestamp(date) {
  const yyyy = date.getFullYear();
  const mm = String(date.getMonth() + 1).padStart(2, "0");
  const dd = String(date.getDate()).padStart(2, "0");
  const hh = String(date.getHours()).padStart(2, "0");
  const mi = String(date.getMinutes()).padStart(2, "0");
  const ss = String(date.getSeconds()).padStart(2, "0");
  return `${yyyy}${mm}${dd}-${hh}${mi}${ss}`;
}

function toPosixPath(targetPath) {
  return targetPath.split(path.sep).join("/");
}

async function buildMigrationPayload(raw, sourcePath) {
  const warnings = [];
  const todos = toArray(raw.todos)
    .map((item, index) => normalizeTodoRow(item, index, warnings))
    .filter((item) => item !== null);
  const sessions = toArray(raw.focus_sessions)
    .map((item, index) => normalizeSessionRow(item, index, warnings))
    .filter((item) => item !== null);
  const refs = toArray(raw.session_task_refs)
    .map((item, index) => normalizeSessionTaskRefRow(item, index, warnings))
    .filter((item) => item !== null);

  const todoById = new Map(todos.map((todo) => [todo.id, todo.title]));
  const refsBySessionId = new Map();

  for (const ref of refs) {
    const current = refsBySessionId.get(ref.sessionId) ?? [];
    current.push(ref);
    refsBySessionId.set(ref.sessionId, current);
  }

  for (const [, current] of refsBySessionId) {
    current.sort((left, right) => left.orderIndex - right.orderIndex);
  }

  const sessionIdSet = new Set(sessions.map((session) => session.id));
  const orphanSessionTasks = refs
    .filter((ref) => !sessionIdSet.has(ref.sessionId))
    .sort((left, right) => left.sessionId.localeCompare(right.sessionId) || left.orderIndex - right.orderIndex)
    .map((ref) => ({
      id: ref.id,
      sessionId: ref.sessionId,
      todoId: ref.todoId,
      todoTitle: ref.todoId ? todoById.get(ref.todoId) ?? null : null,
      titleSnapshot: ref.titleSnapshot || null,
      orderIndex: ref.orderIndex,
      completed: ref.completed,
      completedAt: ref.completedAt,
      createdAt: ref.createdAt,
      updatedAt: ref.updatedAt,
    }));

  const mappedSessions = sessions.map((session) => {
    const tasks = (refsBySessionId.get(session.id) ?? []).map((ref) => ({
      id: ref.id,
      todoId: ref.todoId,
      todoTitle: ref.todoId ? todoById.get(ref.todoId) ?? null : null,
      titleSnapshot: ref.titleSnapshot || null,
      orderIndex: ref.orderIndex,
      completed: ref.completed,
      completedAt: ref.completedAt,
      createdAt: ref.createdAt,
      updatedAt: ref.updatedAt,
    }));

    return {
      ...session,
      tasks,
    };
  });

  return {
    schema: MIGRATION_SCHEMA,
    exportedAt: new Date().toISOString(),
    source: {
      type: "pomlist-db.json",
      version: Number.isFinite(Number(raw.version)) ? Number(raw.version) : null,
      path: toPosixPath(path.relative(process.cwd(), sourcePath) || sourcePath),
    },
    summary: {
      todoCount: todos.length,
      sessionCount: mappedSessions.length,
      sessionTaskCount: refs.length,
      orphanSessionTaskCount: orphanSessionTasks.length,
      warningCount: warnings.length,
    },
    warnings,
    todos,
    sessions: mappedSessions,
    orphanSessionTasks,
  };
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  if (options.help) {
    printHelp();
    return;
  }

  const inputPath = resolveFilePath(options.input);
  let outputPath = options.output ? resolveFilePath(options.output) : "";
  if (!outputPath) {
    const filename = `${MIGRATION_SCHEMA}-${toFilenameTimestamp(new Date())}.json`;
    outputPath = resolveFilePath(path.join(DEFAULT_OUTPUT_DIR, filename));
  }

  const sourceText = await fs.readFile(inputPath, "utf8");
  const raw = JSON.parse(sourceText);
  if (!isObject(raw)) {
    throw new Error("输入文件不是合法的 JSON 对象。");
  }

  const payload = await buildMigrationPayload(raw, inputPath);
  await fs.mkdir(path.dirname(outputPath), { recursive: true });
  await fs.writeFile(outputPath, `${JSON.stringify(payload, null, 2)}\n`, "utf8");

  console.log(`导出完成：${toPosixPath(path.relative(process.cwd(), outputPath) || outputPath)}`);
  console.log(
    `统计：任务 ${payload.summary.todoCount}，会话 ${payload.summary.sessionCount}，会话任务 ${payload.summary.sessionTaskCount}，告警 ${payload.summary.warningCount}`,
  );
}

main().catch((error) => {
  console.error("导出失败：", error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
