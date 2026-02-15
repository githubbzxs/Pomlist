import { ApiClientError, apiRequest } from "@/lib/client/api-client";
import { clearAccessToken, setAccessToken } from "@/lib/client/session";
import type {
  ActiveSession,
  AuthCredentials,
  DashboardMetrics,
  DistributionBucket,
  SessionHistoryItem,
  TodoItem,
  TrendPoint,
} from "@/lib/client/types";
import {
  DEFAULT_TODO_CATEGORY,
  mergeTodoTagsWithCategory,
  normalizeTodoCategory,
  resolveLegacyCategoryAsPrimaryTag,
} from "@/lib/validation";

interface AuthPayload {
  user: { id: string; email: string | null } | null;
  session: {
    accessToken: string;
    refreshToken: string | null;
    expiresIn: number | null;
    tokenType: string | null;
  } | null;
}

interface ActiveSessionPayload {
  session: {
    id: string;
    state: "active" | "ended";
    startedAt: string;
    endedAt: string | null;
    elapsedSeconds: number;
    totalTaskCount: number;
    completedTaskCount: number;
    completionRate: number;
  };
  tasks: Array<{
    ref: {
      todoId: string;
      isCompletedInSession: boolean;
    };
    displayTitle: string;
  }>;
}

type SessionHistoryPayload = Array<{
  session: {
    id: string;
    state: "ended";
    startedAt: string;
    endedAt: string | null;
    elapsedSeconds: number;
    totalTaskCount: number;
    completedTaskCount: number;
    completionRate: number;
  };
  tasks: Array<{
    ref: {
      todoId: string;
      isCompletedInSession: boolean;
    };
    displayTitle: string;
  }>;
}>;

function normalizeTodo(item: TodoItem): TodoItem {
  const category = normalizeTodoCategory((item as TodoItem & { category?: unknown }).category) ?? DEFAULT_TODO_CATEGORY;
  const tags =
    mergeTodoTagsWithCategory(
      (item as TodoItem & { tags?: unknown }).tags,
      (item as TodoItem & { category?: unknown }).category,
    ) ?? [];
  const legacyPrimary = resolveLegacyCategoryAsPrimaryTag((item as TodoItem & { category?: unknown }).category);
  const mappedCategory = tags[0] ?? legacyPrimary ?? category;

  return {
    id: item.id,
    title: item.title,
    subject: item.subject ?? null,
    notes: item.notes ?? null,
    category: mappedCategory,
    tags,
    priority: item.priority,
    dueAt: item.dueAt ?? null,
    status: item.status,
    completedAt: item.completedAt ?? null,
  };
}

function mapActiveSession(payload: ActiveSessionPayload): ActiveSession {
  return {
    id: payload.session.id,
    state: payload.session.state,
    startedAt: payload.session.startedAt,
    endedAt: payload.session.endedAt,
    elapsedSeconds: payload.session.elapsedSeconds,
    totalTaskCount: payload.session.totalTaskCount,
    completedTaskCount: payload.session.completedTaskCount,
    completionRate: payload.session.completionRate,
    tasks: payload.tasks.map((item) => ({
      todoId: item.ref.todoId,
      title: item.displayTitle,
      completed: item.ref.isCompletedInSession,
    })),
  };
}

function mapSessionHistoryItem(payload: SessionHistoryPayload[number]): SessionHistoryItem {
  return {
    id: payload.session.id,
    startedAt: payload.session.startedAt,
    endedAt: payload.session.endedAt,
    elapsedSeconds: payload.session.elapsedSeconds,
    totalTaskCount: payload.session.totalTaskCount,
    completedTaskCount: payload.session.completedTaskCount,
    completionRate: payload.session.completionRate,
    tasks: payload.tasks.map((item) => ({
      todoId: item.ref.todoId,
      title: item.displayTitle,
      completed: item.ref.isCompletedInSession,
    })),
  };
}

export async function signIn(credentials: AuthCredentials): Promise<void> {
  const payload = await apiRequest<AuthPayload>("/api/auth/sign-in", {
    method: "POST",
    body: JSON.stringify(credentials),
    auth: false,
  });
  if (payload.session?.accessToken) {
    setAccessToken(payload.session.accessToken);
  }
}

export async function signOut(): Promise<void> {
  try {
    await apiRequest<{ signedOut: boolean }>("/api/auth/sign-out", { method: "POST" });
  } finally {
    clearAccessToken();
  }
}

export async function changePasscode(oldPasscode: string, newPasscode: string): Promise<void> {
  await apiRequest<{ updated: true }>("/api/auth/passcode", {
    method: "PATCH",
    body: JSON.stringify({ oldPasscode, newPasscode }),
  });
}

export async function listTodos(status?: "pending" | "completed" | "archived"): Promise<TodoItem[]> {
  const query = status ? `?status=${status}` : "";
  const payload = await apiRequest<TodoItem[]>(`/api/todos${query}`);
  return payload.map(normalizeTodo);
}

export async function createTodo(input: {
  title: string;
  subject?: string | null;
  notes?: string | null;
  category?: string;
  tags?: string[];
  priority?: 1 | 2 | 3;
  dueAt?: string | null;
}): Promise<TodoItem> {
  const payload = await apiRequest<TodoItem>("/api/todos", {
    method: "POST",
    body: JSON.stringify(input),
  });
  return normalizeTodo(payload);
}

export async function updateTodo(
  id: string,
  input: {
    title?: string;
    subject?: string | null;
    notes?: string | null;
    category?: string;
    tags?: string[];
    priority?: 1 | 2 | 3;
    dueAt?: string | null;
    status?: "pending" | "completed" | "archived";
    completed?: boolean;
  },
): Promise<TodoItem> {
  const payload = await apiRequest<TodoItem>(`/api/todos/${id}`, {
    method: "PATCH",
    body: JSON.stringify(input),
  });
  return normalizeTodo(payload);
}

export async function deleteTodo(id: string): Promise<void> {
  await apiRequest<{ deleted: boolean }>(`/api/todos/${id}`, {
    method: "DELETE",
  });
}

export async function startSession(todoIds: string[]): Promise<ActiveSession> {
  const payload = await apiRequest<ActiveSessionPayload>("/api/sessions/start", {
    method: "POST",
    body: JSON.stringify({ todoIds }),
  });
  return mapActiveSession(payload);
}

export async function addTasksToSession(sessionId: string, todoIds: string[]): Promise<ActiveSession> {
  const payload = await apiRequest<ActiveSessionPayload>(`/api/sessions/${sessionId}/tasks`, {
    method: "POST",
    body: JSON.stringify({ todoIds }),
  });
  return mapActiveSession(payload);
}

export async function getActiveSession(): Promise<ActiveSession | null> {
  try {
    const payload = await apiRequest<ActiveSessionPayload>("/api/sessions/active");
    return mapActiveSession(payload);
  } catch (error) {
    if (error instanceof ApiClientError && error.status === 404) {
      return null;
    }
    throw error;
  }
}

export async function toggleSessionTask(
  sessionId: string,
  todoId: string,
  isCompleted?: boolean,
): Promise<ActiveSession> {
  const payload = await apiRequest<ActiveSessionPayload>(`/api/sessions/${sessionId}/toggle-task`, {
    method: "PATCH",
    body: JSON.stringify({ todoId, isCompleted }),
  });
  return mapActiveSession(payload);
}

export async function endSession(sessionId: string): Promise<void> {
  await apiRequest(`/api/sessions/${sessionId}/end`, {
    method: "POST",
    body: JSON.stringify({}),
  });
}

export async function getSessionHistory(limit = 30): Promise<SessionHistoryItem[]> {
  const numericLimit = Number.isFinite(limit) ? limit : 30;
  const safeLimit = Math.min(120, Math.max(1, Math.floor(numericLimit)));
  const payload = await apiRequest<SessionHistoryPayload>(`/api/sessions/history?limit=${safeLimit}`);
  return payload.map(mapSessionHistoryItem);
}

export async function getDashboardMetrics(): Promise<DashboardMetrics> {
  return apiRequest<DashboardMetrics>("/api/analytics/dashboard");
}

export async function getTrendData(days = 7): Promise<TrendPoint[]> {
  return apiRequest<TrendPoint[]>(`/api/analytics/trend?days=${days}`);
}

export async function getDistributionData(days = 30): Promise<DistributionBucket[]> {
  return apiRequest<DistributionBucket[]>(`/api/analytics/distribution?days=${days}`);
}
