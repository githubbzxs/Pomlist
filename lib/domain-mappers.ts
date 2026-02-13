import type {
  ActiveSession,
  DurationDistributionItem,
  FocusSession,
  SessionTaskRef,
  Todo,
  TodoStatus,
  TrendAnalyticsPoint,
} from "@/types/domain";

export interface DbTodoRow {
  id: string;
  user_id: string;
  title: string;
  subject: string | null;
  notes: string | null;
  priority: number;
  due_at: string | null;
  status: TodoStatus;
  completed_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface DbFocusSessionRow {
  id: string;
  user_id: string;
  state: "active" | "ended";
  started_at: string;
  ended_at: string | null;
  elapsed_seconds: number;
  total_task_count: number;
  completed_task_count: number;
  created_at: string;
  updated_at: string;
}

export interface DbSessionTaskRefRow {
  id: string;
  user_id: string;
  session_id: string;
  todo_id: string;
  title_snapshot: string;
  order_index: number;
  is_completed_in_session: boolean;
  completed_at: string | null;
  created_at: string;
  updated_at: string;
}

export function completionRate(completedTaskCount: number, totalTaskCount: number): number {
  if (totalTaskCount <= 0) {
    return 0;
  }

  return Number(((completedTaskCount / totalTaskCount) * 100).toFixed(2));
}

export function mapTodoRow(row: DbTodoRow): Todo {
  const priority = Number.isFinite(row.priority) ? row.priority : 2;
  const safePriority = priority >= 3 ? 3 : priority <= 1 ? 1 : 2;

  return {
    id: row.id,
    userId: row.user_id,
    title: row.title,
    subject: row.subject,
    notes: row.notes,
    priority: safePriority as 1 | 2 | 3,
    dueAt: row.due_at,
    status: row.status,
    completedAt: row.completed_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export function mapFocusSessionRow(row: DbFocusSessionRow): FocusSession {
  return {
    id: row.id,
    userId: row.user_id,
    state: row.state,
    startedAt: row.started_at,
    endedAt: row.ended_at,
    elapsedSeconds: row.elapsed_seconds,
    totalTaskCount: row.total_task_count,
    completedTaskCount: row.completed_task_count,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    completionRate: completionRate(row.completed_task_count, row.total_task_count),
  };
}

export function mapSessionTaskRefRow(row: DbSessionTaskRefRow): SessionTaskRef {
  return {
    id: row.id,
    userId: row.user_id,
    sessionId: row.session_id,
    todoId: row.todo_id,
    titleSnapshot: row.title_snapshot,
    orderIndex: row.order_index,
    isCompletedInSession: row.is_completed_in_session,
    completedAt: row.completed_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export function mapActiveSession(
  sessionRow: DbFocusSessionRow,
  refRows: DbSessionTaskRefRow[],
  todoRows: DbTodoRow[],
): ActiveSession {
  const todoMap = new Map(todoRows.map((todo) => [todo.id, mapTodoRow(todo)]));
  const tasks = refRows
    .sort((left, right) => left.order_index - right.order_index)
    .map((ref) => {
      const mappedRef = mapSessionTaskRefRow(ref);
      const todo = todoMap.get(ref.todo_id) ?? null;
      return {
        ref: mappedRef,
        todo,
        displayTitle: todo?.title ?? ref.title_snapshot,
      };
    });

  return {
    session: mapFocusSessionRow(sessionRow),
    tasks,
  };
}

export function buildTrendSeries(days: number, now: Date = new Date()): TrendAnalyticsPoint[] {
  const safeDays = Math.max(1, Math.min(60, Math.floor(days)));
  const today = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
  const points: TrendAnalyticsPoint[] = [];

  for (let index = safeDays - 1; index >= 0; index -= 1) {
    const date = new Date(today.getTime() - index * 24 * 60 * 60 * 1000);
    points.push({
      date: date.toISOString().slice(0, 10),
      sessionCount: 0,
      totalDurationSeconds: 0,
      completionRate: 0,
    });
  }

  return points;
}

export function emptyDistribution(): DurationDistributionItem[] {
  return [
    { bucketLabel: "0-15 分钟", sessionCount: 0, totalDurationSeconds: 0 },
    { bucketLabel: "15-30 分钟", sessionCount: 0, totalDurationSeconds: 0 },
    { bucketLabel: "30-45 分钟", sessionCount: 0, totalDurationSeconds: 0 },
    { bucketLabel: "45+ 分钟", sessionCount: 0, totalDurationSeconds: 0 },
  ];
}

export function resolveDurationBucketLabel(elapsedSeconds: number): DurationDistributionItem["bucketLabel"] {
  const minutes = elapsedSeconds / 60;
  if (minutes < 15) {
    return "0-15 分钟";
  }
  if (minutes < 30) {
    return "15-30 分钟";
  }
  if (minutes < 45) {
    return "30-45 分钟";
  }
  return "45+ 分钟";
}

