import { randomBytes, randomUUID } from "node:crypto";
import { promises as fs } from "node:fs";
import path from "node:path";

import type { DbFocusSessionRow, DbSessionTaskRefRow, DbTodoRow } from "@/lib/domain-mappers";
import { DEFAULT_TODO_CATEGORY, normalizeTodoCategory, normalizeTodoTags } from "@/lib/validation";

export interface SupabaseErrorPayload {
  code?: string;
  message: string;
  details?: string;
  hint?: string;
}

export interface SupabaseResult<T> {
  data: T | null;
  error: SupabaseErrorPayload | null;
  status: number;
}

export interface SupabaseAuthUser {
  id: string;
  email?: string | null;
}

export interface SupabaseAuthPayload {
  access_token?: string;
  refresh_token?: string;
  expires_in?: number;
  token_type?: string;
  user?: SupabaseAuthUser;
}

export interface SupabaseUserPayload {
  user?: SupabaseAuthUser;
}

interface SupabaseClientConfig {
  url?: string;
  apiKey?: string;
  accessToken?: string;
}

interface SupabaseRestRequest {
  table: string;
  method?: "GET" | "POST" | "PATCH" | "DELETE";
  query?: Record<string, string | number | boolean | undefined>;
  body?: unknown;
  prefer?: string;
}

interface SupabaseRpcRequest {
  fn: string;
  query?: Record<string, string | number | boolean | undefined>;
  body?: unknown;
}

interface SupabaseEnv {
  url: string;
  anonKey: string;
  serviceRoleKey?: string;
}

interface LocalUserRow {
  id: string;
  email: string;
  created_at: string;
  updated_at: string;
}

interface LocalAccessTokenRow {
  token: string;
  user_id: string;
  created_at: string;
  expires_at: string;
}

interface LocalAuthState {
  passcode: string | null;
  updated_at: string | null;
}

interface LocalDatabaseState {
  version: number;
  users: LocalUserRow[];
  tokens: LocalAccessTokenRow[];
  auth: LocalAuthState;
  todos: DbTodoRow[];
  focus_sessions: DbFocusSessionRow[];
  session_task_refs: DbSessionTaskRefRow[];
}

type LocalTable = "todos" | "focus_sessions" | "session_task_refs";
type LocalTableRow = DbTodoRow | DbFocusSessionRow | DbSessionTaskRefRow;

const DATABASE_VERSION = 1;
const TOKEN_TTL_SECONDS = 60 * 60 * 24 * 30;
const OWNER_USER_ID = "owner-user";
const OWNER_USER_EMAIL = "owner@pomlist.local";
const PASSCODE_LENGTH = 4;
const DEFAULT_PASSCODE = "0xbp";

let operationQueue: Promise<unknown> = Promise.resolve();

function emptyState(): LocalDatabaseState {
  return {
    version: DATABASE_VERSION,
    users: [],
    tokens: [],
    auth: {
      passcode: null,
      updated_at: null,
    },
    todos: [],
    focus_sessions: [],
    session_task_refs: [],
  };
}

function nowIso(): string {
  return new Date().toISOString();
}

function createAccessTokenValue(): string {
  return randomBytes(32).toString("base64url");
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function toNullableString(value: unknown): string | null {
  if (value === null || value === undefined || value === "") {
    return null;
  }
  return typeof value === "string" ? value : null;
}

function toFiniteNumber(value: unknown, fallback: number): number {
  const parsed = typeof value === "number" ? value : Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function toBoolean(value: unknown, fallback = false): boolean {
  if (typeof value === "boolean") {
    return value;
  }
  return fallback;
}

function isTodoStatus(value: unknown): value is DbTodoRow["status"] {
  return value === "pending" || value === "completed" || value === "archived";
}

function normalizeLocalAuth(value: unknown): LocalAuthState {
  if (!isObject(value)) {
    return {
      passcode: null,
      updated_at: null,
    };
  }

  const passcodeCandidate = typeof value.passcode === "string" ? value.passcode.trim() : null;
  const passcode = passcodeCandidate && passcodeCandidate.length === PASSCODE_LENGTH ? passcodeCandidate : null;
  const updatedAt = typeof value.updated_at === "string" ? value.updated_at : null;

  return {
    passcode,
    updated_at: updatedAt,
  };
}

function normalizeTodoRow(value: unknown): DbTodoRow | null {
  if (!isObject(value)) {
    return null;
  }

  const id = typeof value.id === "string" ? value.id : "";
  const userId = typeof value.user_id === "string" ? value.user_id : "";
  if (id === "" || userId === "") {
    return null;
  }

  const createdAt = typeof value.created_at === "string" ? value.created_at : nowIso();
  const updatedAt = typeof value.updated_at === "string" ? value.updated_at : createdAt;
  const category = normalizeTodoCategory(value.category) ?? DEFAULT_TODO_CATEGORY;
  const tags = normalizeTodoTags(value.tags) ?? [];

  return {
    id,
    user_id: userId,
    title: typeof value.title === "string" ? value.title : "",
    subject: toNullableString(value.subject),
    notes: toNullableString(value.notes),
    category,
    tags,
    priority: Math.max(1, Math.min(3, Math.round(toFiniteNumber(value.priority, 2)))) as 1 | 2 | 3,
    due_at: toNullableString(value.due_at),
    status: isTodoStatus(value.status) ? value.status : "pending",
    completed_at: toNullableString(value.completed_at),
    created_at: createdAt,
    updated_at: updatedAt,
  };
}

function resolveDatabasePath(): string {
  const configuredPath = process.env.POMLIST_DB_PATH?.trim();
  const relativePath = configuredPath && configuredPath.length > 0 ? configuredPath : "data/pomlist-db.json";
  return path.isAbsolute(relativePath) ? relativePath : path.resolve(process.cwd(), relativePath);
}

async function ensureDirectoryForDatabaseFile(filePath: string): Promise<void> {
  await fs.mkdir(path.dirname(filePath), { recursive: true });
}

function hydrateState(value: unknown): LocalDatabaseState {
  if (!isObject(value)) {
    return emptyState();
  }

  const todos = Array.isArray(value.todos)
    ? value.todos.map(normalizeTodoRow).filter((row): row is DbTodoRow => row !== null)
    : [];

  return {
    version: DATABASE_VERSION,
    users: Array.isArray(value.users) ? (value.users as LocalUserRow[]) : [],
    tokens: Array.isArray(value.tokens) ? (value.tokens as LocalAccessTokenRow[]) : [],
    auth: normalizeLocalAuth(value.auth),
    todos,
    focus_sessions: Array.isArray(value.focus_sessions) ? (value.focus_sessions as DbFocusSessionRow[]) : [],
    session_task_refs: Array.isArray(value.session_task_refs)
      ? (value.session_task_refs as DbSessionTaskRefRow[])
      : [],
  };
}

async function writeState(state: LocalDatabaseState): Promise<void> {
  const filePath = resolveDatabasePath();
  await ensureDirectoryForDatabaseFile(filePath);

  const tempPath = `${filePath}.tmp`;
  const payload = JSON.stringify(state, null, 2);
  await fs.writeFile(tempPath, payload, "utf8");
  await fs.rename(tempPath, filePath);
}

async function readState(): Promise<LocalDatabaseState> {
  const filePath = resolveDatabasePath();
  await ensureDirectoryForDatabaseFile(filePath);

  try {
    const text = await fs.readFile(filePath, "utf8");
    const parsed = JSON.parse(text) as unknown;
    return hydrateState(parsed);
  } catch (error) {
    const maybeNodeError = error as NodeJS.ErrnoException;
    if (maybeNodeError.code !== "ENOENT") {
      throw error;
    }

    const initial = emptyState();
    await writeState(initial);
    return initial;
  }
}

async function runSerialized<T>(task: () => Promise<T>): Promise<T> {
  const scheduled = operationQueue.then(task, task) as Promise<T>;
  operationQueue = scheduled.then(
    () => undefined,
    () => undefined,
  );
  return scheduled;
}

async function withState<T>(write: boolean, task: (state: LocalDatabaseState) => Promise<T> | T): Promise<T> {
  return runSerialized(async () => {
    const state = await readState();
    const result = await task(state);
    if (write) {
      await writeState(state);
    }
    return result;
  });
}

function isTokenExpired(token: LocalAccessTokenRow): boolean {
  return Date.parse(token.expires_at) <= Date.now();
}

function findUserByToken(state: LocalDatabaseState, tokenValue: string | undefined): LocalUserRow | null {
  if (!tokenValue) {
    return null;
  }

  const token = state.tokens.find((item) => item.token === tokenValue);
  if (!token || isTokenExpired(token)) {
    return null;
  }

  return state.users.find((item) => item.id === token.user_id) ?? null;
}

function resolveConfiguredPasscode(): string {
  const candidate = process.env.POMLIST_PASSCODE?.trim() || DEFAULT_PASSCODE;
  if (candidate.length !== PASSCODE_LENGTH) {
    throw new Error(`POMLIST_PASSCODE 必须是 ${PASSCODE_LENGTH} 个字符`);
  }

  return candidate;
}

function resolvePasscodeFromState(state: LocalDatabaseState): string {
  const localPasscode = state.auth.passcode?.trim();
  if (localPasscode && localPasscode.length === PASSCODE_LENGTH) {
    return localPasscode;
  }
  return resolveConfiguredPasscode();
}

function ensureOwnerUser(state: LocalDatabaseState): LocalUserRow {
  const ownerById = state.users.find((item) => item.id === OWNER_USER_ID);
  if (ownerById) {
    return ownerById;
  }

  // 兼容历史数据，优先复用已有首个用户，避免“换账号”导致旧数据不可见。
  if (state.users.length > 0) {
    return state.users[0];
  }

  const timestamp = nowIso();
  const owner: LocalUserRow = {
    id: OWNER_USER_ID,
    email: OWNER_USER_EMAIL,
    created_at: timestamp,
    updated_at: timestamp,
  };
  state.users.push(owner);
  return owner;
}

function createUserSession(state: LocalDatabaseState, user: LocalUserRow): SupabaseAuthPayload {
  const createdAt = nowIso();
  const expiresAt = new Date(Date.now() + TOKEN_TTL_SECONDS * 1000).toISOString();
  const token = createAccessTokenValue();

  state.tokens.push({
    token,
    user_id: user.id,
    created_at: createdAt,
    expires_at: expiresAt,
  });

  return {
    access_token: token,
    refresh_token: undefined,
    expires_in: TOKEN_TTL_SECONDS,
    token_type: "bearer",
    user: {
      id: user.id,
      email: user.email,
    },
  };
}

function success<T>(data: T, status = 200): SupabaseResult<T> {
  return {
    data,
    error: null,
    status,
  };
}

function failure<T>(
  status: number,
  message: string,
  code?: string,
  details?: string,
  hint?: string,
): SupabaseResult<T> {
  return {
    data: null,
    error: {
      ...(code ? { code } : {}),
      message,
      ...(details ? { details } : {}),
      ...(hint ? { hint } : {}),
    },
    status,
  };
}

function parseLiteral(value: string): unknown {
  if (value === "null") {
    return null;
  }
  if (value === "true") {
    return true;
  }
  if (value === "false") {
    return false;
  }

  const parsed = Number(value);
  if (!Number.isNaN(parsed) && value.trim() !== "") {
    return parsed;
  }

  return value;
}

function valuesEqual(left: unknown, right: unknown): boolean {
  if (left === right) {
    return true;
  }

  if (typeof left === "number" && typeof right === "string") {
    return Number.isFinite(Number(right)) && left === Number(right);
  }
  if (typeof left === "string" && typeof right === "number") {
    return Number.isFinite(Number(left)) && Number(left) === right;
  }

  return false;
}

function toComparable(value: unknown): string | number | null {
  if (typeof value === "number") {
    return value;
  }
  if (typeof value === "string") {
    const timestamp = Date.parse(value);
    if (!Number.isNaN(timestamp) && value.includes("T")) {
      return timestamp;
    }
    return value;
  }
  if (typeof value === "boolean") {
    return value ? 1 : 0;
  }
  return null;
}

function compareWithOperator(left: unknown, operator: "gte" | "gt" | "lte" | "lt", right: unknown): boolean {
  const comparableLeft = toComparable(left);
  const comparableRight = toComparable(right);
  if (comparableLeft === null || comparableRight === null) {
    return false;
  }

  if (operator === "gte") {
    return comparableLeft >= comparableRight;
  }
  if (operator === "gt") {
    return comparableLeft > comparableRight;
  }
  if (operator === "lte") {
    return comparableLeft <= comparableRight;
  }
  return comparableLeft < comparableRight;
}

function matchesFilterValue(rowValue: unknown, rawFilter: string): boolean {
  if (rawFilter.startsWith("eq.")) {
    return valuesEqual(rowValue, parseLiteral(rawFilter.slice(3)));
  }

  if (rawFilter.startsWith("in.(") && rawFilter.endsWith(")")) {
    const inner = rawFilter.slice(4, -1);
    if (inner.trim() === "") {
      return false;
    }

    const candidates = inner.split(",").map((item) => parseLiteral(item.trim()));
    return candidates.some((candidate) => valuesEqual(rowValue, candidate));
  }

  for (const operator of ["gte", "gt", "lte", "lt"] as const) {
    const prefix = `${operator}.`;
    if (!rawFilter.startsWith(prefix)) {
      continue;
    }

    return compareWithOperator(rowValue, operator, parseLiteral(rawFilter.slice(prefix.length)));
  }

  return valuesEqual(rowValue, parseLiteral(rawFilter));
}

function matchesAndClause(row: Record<string, unknown>, rawClause: string): boolean {
  const trimmed = rawClause.trim();
  if (trimmed === "") {
    return true;
  }

  const normalized = trimmed.startsWith("(") && trimmed.endsWith(")") ? trimmed.slice(1, -1) : trimmed;
  const segments = normalized
    .split(",")
    .map((item) => item.trim())
    .filter((item) => item !== "");

  return segments.every((segment) => {
    const firstDot = segment.indexOf(".");
    const secondDot = segment.indexOf(".", firstDot + 1);
    if (firstDot <= 0 || secondDot <= firstDot + 1) {
      return false;
    }

    const fieldName = segment.slice(0, firstDot);
    const operator = segment.slice(firstDot + 1, secondDot);
    const value = segment.slice(secondDot + 1);
    return matchesFilterValue(row[fieldName], `${operator}.${value}`);
  });
}

function matchesQuery(row: Record<string, unknown>, query?: Record<string, string | number | boolean | undefined>): boolean {
  if (!query) {
    return true;
  }

  for (const [key, value] of Object.entries(query)) {
    if (value === undefined) {
      continue;
    }

    if (key === "select" || key === "order" || key === "limit" || key === "offset" || key === "and") {
      continue;
    }

    const raw = typeof value === "string" ? value : String(value);
    if (!matchesFilterValue(row[key], raw)) {
      return false;
    }
  }

  if (typeof query.and === "string" && !matchesAndClause(row, query.and)) {
    return false;
  }

  return true;
}

function applyQuery(rows: LocalTableRow[], query?: Record<string, string | number | boolean | undefined>): LocalTableRow[] {
  let output = rows.filter((row) => matchesQuery(row as unknown as Record<string, unknown>, query));

  const order = typeof query?.order === "string" ? query.order : null;
  if (order) {
    const [field, direction = "asc"] = order.split(".");
    const descending = direction.toLowerCase() === "desc";

    output = [...output].sort((left, right) => {
      const leftValue = toComparable((left as unknown as Record<string, unknown>)[field]);
      const rightValue = toComparable((right as unknown as Record<string, unknown>)[field]);

      if (leftValue === rightValue) {
        return 0;
      }
      if (leftValue === null) {
        return descending ? 1 : -1;
      }
      if (rightValue === null) {
        return descending ? -1 : 1;
      }
      if (leftValue > rightValue) {
        return descending ? -1 : 1;
      }
      return descending ? 1 : -1;
    });
  }

  const limitRaw = query?.limit;
  if (limitRaw !== undefined) {
    const limitValue = Number(limitRaw);
    if (Number.isFinite(limitValue) && limitValue >= 0) {
      output = output.slice(0, Math.floor(limitValue));
    }
  }

  return output;
}

function projectRows(rows: LocalTableRow[], select: string | number | boolean | undefined): unknown[] {
  if (typeof select !== "string" || select.trim() === "" || select === "*") {
    return rows.map((row) => ({ ...row }));
  }

  const columns = select
    .split(",")
    .map((item) => item.trim())
    .filter((item) => item.length > 0);
  if (columns.length === 0 || columns.includes("*")) {
    return rows.map((row) => ({ ...row }));
  }

  return rows.map((row) => {
    const source = row as unknown as Record<string, unknown>;
    const projected: Record<string, unknown> = {};
    for (const column of columns) {
      if (Object.prototype.hasOwnProperty.call(source, column)) {
        projected[column] = source[column];
      }
    }
    return projected;
  });
}

function isSupportedTable(table: string): table is LocalTable {
  return table === "todos" || table === "focus_sessions" || table === "session_task_refs";
}

function getTableRows(state: LocalDatabaseState, table: LocalTable): LocalTableRow[] {
  if (table === "todos") {
    return state.todos;
  }
  if (table === "focus_sessions") {
    return state.focus_sessions;
  }
  return state.session_task_refs;
}

function replaceTableRows(state: LocalDatabaseState, table: LocalTable, rows: LocalTableRow[]): void {
  if (table === "todos") {
    state.todos = rows as DbTodoRow[];
    return;
  }
  if (table === "focus_sessions") {
    state.focus_sessions = rows as DbFocusSessionRow[];
    return;
  }
  state.session_task_refs = rows as DbSessionTaskRefRow[];
}

function normalizeUpdatePayload(value: unknown): Record<string, unknown> | null {
  if (!isObject(value)) {
    return null;
  }

  const updates: Record<string, unknown> = { ...value };
  delete updates.id;
  delete updates.user_id;
  delete updates.created_at;
  return updates;
}

function normalizeTodoPatch(updates: Record<string, unknown>): Record<string, unknown> {
  const normalized = { ...updates };

  if (Object.prototype.hasOwnProperty.call(normalized, "priority")) {
    normalized.priority = Math.max(1, Math.min(3, Math.round(toFiniteNumber(normalized.priority, 2))));
  }

  if (Object.prototype.hasOwnProperty.call(normalized, "due_at")) {
    normalized.due_at = toNullableString(normalized.due_at);
  }

  if (Object.prototype.hasOwnProperty.call(normalized, "subject")) {
    normalized.subject = toNullableString(normalized.subject);
  }

  if (Object.prototype.hasOwnProperty.call(normalized, "notes")) {
    normalized.notes = toNullableString(normalized.notes);
  }

  if (Object.prototype.hasOwnProperty.call(normalized, "completed_at")) {
    normalized.completed_at = toNullableString(normalized.completed_at);
  }

  if (Object.prototype.hasOwnProperty.call(normalized, "status") && !isTodoStatus(normalized.status)) {
    delete normalized.status;
  }

  if (Object.prototype.hasOwnProperty.call(normalized, "category")) {
    normalized.category = normalizeTodoCategory(normalized.category) ?? DEFAULT_TODO_CATEGORY;
  }

  if (Object.prototype.hasOwnProperty.call(normalized, "tags")) {
    normalized.tags = normalizeTodoTags(normalized.tags) ?? [];
  }

  return normalized;
}

function normalizeUpdatesByTable(table: LocalTable, updates: Record<string, unknown>): Record<string, unknown> {
  if (table === "todos") {
    return normalizeTodoPatch(updates);
  }
  return updates;
}

function toRecordArray(value: unknown): Record<string, unknown>[] | null {
  if (Array.isArray(value)) {
    const rows = value.filter((item): item is Record<string, unknown> => isObject(item));
    return rows.length === value.length ? rows : null;
  }

  if (isObject(value)) {
    return [value];
  }

  return null;
}

function buildTodoRow(userId: string, payload: Record<string, unknown>, timestamp: string): DbTodoRow {
  const priority = Math.max(1, Math.min(3, Math.round(toFiniteNumber(payload.priority, 2))));
  const dueAt = toNullableString(payload.due_at);
  const status = isTodoStatus(payload.status) ? payload.status : "pending";
  const completedAt = toNullableString(payload.completed_at);
  const category = normalizeTodoCategory(payload.category) ?? DEFAULT_TODO_CATEGORY;
  const tags = normalizeTodoTags(payload.tags) ?? [];

  return {
    id: randomUUID(),
    user_id: userId,
    title: typeof payload.title === "string" ? payload.title : "",
    subject: toNullableString(payload.subject),
    notes: toNullableString(payload.notes),
    category,
    tags,
    priority: priority as 1 | 2 | 3,
    due_at: dueAt,
    status,
    completed_at: completedAt,
    created_at: timestamp,
    updated_at: timestamp,
  };
}

function buildFocusSessionRow(userId: string, payload: Record<string, unknown>, timestamp: string): DbFocusSessionRow {
  return {
    id: randomUUID(),
    user_id: userId,
    state: payload.state === "ended" ? "ended" : "active",
    started_at: typeof payload.started_at === "string" ? payload.started_at : timestamp,
    ended_at: toNullableString(payload.ended_at),
    elapsed_seconds: Math.max(0, Math.floor(toFiniteNumber(payload.elapsed_seconds, 0))),
    total_task_count: Math.max(0, Math.floor(toFiniteNumber(payload.total_task_count, 0))),
    completed_task_count: Math.max(0, Math.floor(toFiniteNumber(payload.completed_task_count, 0))),
    created_at: timestamp,
    updated_at: timestamp,
  };
}

function buildSessionTaskRefRow(userId: string, payload: Record<string, unknown>, timestamp: string): DbSessionTaskRefRow {
  return {
    id: randomUUID(),
    user_id: userId,
    session_id: typeof payload.session_id === "string" ? payload.session_id : "",
    todo_id: typeof payload.todo_id === "string" ? payload.todo_id : "",
    title_snapshot: typeof payload.title_snapshot === "string" ? payload.title_snapshot : "",
    order_index: Math.max(0, Math.floor(toFiniteNumber(payload.order_index, 0))),
    is_completed_in_session: toBoolean(payload.is_completed_in_session),
    completed_at: toNullableString(payload.completed_at),
    created_at: timestamp,
    updated_at: timestamp,
  };
}

export function getSupabaseEnv(options?: { requireServiceRole?: boolean }): SupabaseEnv {
  void options;
  return {
    url: "local://pomlist",
    anonKey: "local",
    serviceRoleKey: "local",
  };
}

export class SupabaseHttpClient {
  private readonly accessToken?: string;

  constructor(config: SupabaseClientConfig = {}) {
    this.accessToken = config.accessToken;
  }

  auth = {
    signUp: async (): Promise<SupabaseResult<SupabaseAuthPayload>> =>
      Promise.resolve(failure<SupabaseAuthPayload>(410, "注册入口已关闭，请使用口令登录", "SIGN_UP_DISABLED")),

    signIn: async (passcode: string): Promise<SupabaseResult<SupabaseAuthPayload>> =>
      withState(true, async (state) => {
        if (passcode.trim().length !== PASSCODE_LENGTH) {
          return failure<SupabaseAuthPayload>(400, `口令必须是 ${PASSCODE_LENGTH} 个字符`, "BAD_PASSCODE_FORMAT");
        }

        let configuredPasscode: string;
        try {
          configuredPasscode = resolvePasscodeFromState(state);
        } catch (error) {
          return failure<SupabaseAuthPayload>(
            500,
            error instanceof Error ? error.message : "服务器口令配置无效",
            "PASSCODE_CONFIG_INVALID",
          );
        }

        if (passcode !== configuredPasscode) {
          return failure<SupabaseAuthPayload>(401, "口令错误", "INVALID_PASSCODE");
        }

        const user = ensureOwnerUser(state);
        const payload = createUserSession(state, user);
        return success(payload, 200);
      }),

    changePasscode: async (oldPasscode: string, newPasscode: string): Promise<SupabaseResult<{ updated: true }>> =>
      withState(true, async (state) => {
        if (!this.accessToken) {
          return failure<{ updated: true }>(401, "登录状态已失效", "UNAUTHORIZED");
        }
        if (oldPasscode.trim().length !== PASSCODE_LENGTH || newPasscode.trim().length !== PASSCODE_LENGTH) {
          return failure<{ updated: true }>(400, `口令必须是 ${PASSCODE_LENGTH} 个字符`, "BAD_PASSCODE_FORMAT");
        }

        const user = findUserByToken(state, this.accessToken);
        if (!user) {
          return failure<{ updated: true }>(401, "登录状态已失效", "UNAUTHORIZED");
        }

        let configuredPasscode: string;
        try {
          configuredPasscode = resolvePasscodeFromState(state);
        } catch (error) {
          return failure<{ updated: true }>(
            500,
            error instanceof Error ? error.message : "服务器口令配置无效",
            "PASSCODE_CONFIG_INVALID",
          );
        }

        if (configuredPasscode !== oldPasscode) {
          return failure<{ updated: true }>(401, "旧口令不正确", "INVALID_PASSCODE");
        }

        state.auth.passcode = newPasscode;
        state.auth.updated_at = nowIso();
        return success<{ updated: true }>({ updated: true }, 200);
      }),

    signOut: async (): Promise<SupabaseResult<Record<string, never>>> =>
      withState(true, async (state) => {
        if (!this.accessToken) {
          return failure<Record<string, never>>(401, "登录状态已失效", "UNAUTHORIZED");
        }

        state.tokens = state.tokens.filter((item) => item.token !== this.accessToken);
        return success<Record<string, never>>({} as Record<string, never>, 200);
      }),

    getUser: async (): Promise<SupabaseResult<SupabaseUserPayload>> =>
      withState(false, async (state) => {
        const user = findUserByToken(state, this.accessToken);
        if (!user) {
          return failure<SupabaseUserPayload>(401, "登录状态已失效", "UNAUTHORIZED");
        }

        return success<SupabaseUserPayload>(
          {
            user: {
              id: user.id,
              email: user.email,
            },
          },
          200,
        );
      }),
  };

  async rest<T>(request: SupabaseRestRequest): Promise<SupabaseResult<T>> {
    const method = request.method ?? "GET";
    const tableName = request.table;

    if (!isSupportedTable(tableName)) {
      return failure<T>(404, `未找到数据表：${tableName}`, "TABLE_NOT_FOUND");
    }

    if (method === "GET") {
      return withState(false, async (state) => {
        const user = findUserByToken(state, this.accessToken);
        if (!user) {
          return failure<T>(401, "登录状态已失效", "UNAUTHORIZED");
        }

        const allRows = getTableRows(state, tableName).filter((row) => row.user_id === user.id);
        const selectedRows = applyQuery(allRows, request.query);
        return success(projectRows(selectedRows, request.query?.select) as T, 200);
      });
    }

    if (method === "POST") {
      return withState(true, async (state) => {
        const user = findUserByToken(state, this.accessToken);
        if (!user) {
          return failure<T>(401, "登录状态已失效", "UNAUTHORIZED");
        }

        const payloadList = toRecordArray(request.body);
        if (!payloadList || payloadList.length === 0) {
          return failure<T>(400, "请求体必须是对象或对象数组", "BAD_REQUEST");
        }

        const timestamp = nowIso();
        let insertedRows: LocalTableRow[] = [];

        if (tableName === "todos") {
          const [payload] = payloadList;
          insertedRows = [buildTodoRow(user.id, payload, timestamp)];
          state.todos.push(insertedRows[0] as DbTodoRow);
        } else if (tableName === "focus_sessions") {
          const [payload] = payloadList;
          const isActive = payload.state === "active" || payload.state === undefined;
          if (isActive) {
            const activeExists = state.focus_sessions.some((row) => row.user_id === user.id && row.state === "active");
            if (activeExists) {
              return failure<T>(
                409,
                "duplicate key value violates unique constraint",
                "23505",
                "focus_sessions_one_active_per_user_idx",
              );
            }
          }

          insertedRows = [buildFocusSessionRow(user.id, payload, timestamp)];
          state.focus_sessions.push(insertedRows[0] as DbFocusSessionRow);
        } else {
          const refRows = payloadList.map((payload) => buildSessionTaskRefRow(user.id, payload, timestamp));
          if (refRows.some((row) => row.session_id === "" || row.todo_id === "")) {
            return failure<T>(400, "session_task_refs 缺少 session_id 或 todo_id", "BAD_REQUEST");
          }
          insertedRows = refRows;
          state.session_task_refs.push(...refRows);
        }

        return success(projectRows(insertedRows, request.query?.select) as T, 201);
      });
    }

    if (method === "PATCH") {
      return withState(true, async (state) => {
        const user = findUserByToken(state, this.accessToken);
        if (!user) {
          return failure<T>(401, "登录状态已失效", "UNAUTHORIZED");
        }

        const rawUpdates = normalizeUpdatePayload(request.body);
        if (!rawUpdates || Object.keys(rawUpdates).length === 0) {
          return failure<T>(400, "更新内容不能为空", "BAD_REQUEST");
        }
        const updates = normalizeUpdatesByTable(tableName, rawUpdates);

        const rows = getTableRows(state, tableName);
        const timestamp = nowIso();
        const matchedRows: LocalTableRow[] = [];

        for (const row of rows) {
          if (row.user_id !== user.id) {
            continue;
          }
          if (!matchesQuery(row as unknown as Record<string, unknown>, request.query)) {
            continue;
          }

          Object.assign(row as unknown as Record<string, unknown>, updates);
          row.updated_at = timestamp;
          matchedRows.push({ ...row });
        }

        return success(projectRows(matchedRows, request.query?.select) as T, 200);
      });
    }

    if (method === "DELETE") {
      return withState(true, async (state) => {
        const user = findUserByToken(state, this.accessToken);
        if (!user) {
          return failure<T>(401, "登录状态已失效", "UNAUTHORIZED");
        }

        const rows = getTableRows(state, tableName);
        const keptRows: LocalTableRow[] = [];
        const deletedRows: LocalTableRow[] = [];

        for (const row of rows) {
          if (row.user_id !== user.id) {
            keptRows.push(row);
            continue;
          }

          if (matchesQuery(row as unknown as Record<string, unknown>, request.query)) {
            deletedRows.push({ ...row });
          } else {
            keptRows.push(row);
          }
        }

        replaceTableRows(state, tableName, keptRows);
        return success(projectRows(deletedRows, request.query?.select) as T, 200);
      });
    }

    return failure<T>(405, `不支持的方法：${method}`, "METHOD_NOT_ALLOWED");
  }

  rpc<T>(request: SupabaseRpcRequest): Promise<SupabaseResult<T>> {
    void request;
    return Promise.resolve(failure<T>(501, "本地模式暂不支持 RPC 调用", "RPC_NOT_IMPLEMENTED"));
  }
}


