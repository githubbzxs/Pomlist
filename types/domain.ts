export type TodoStatus = "pending" | "completed" | "archived";

export type SessionState = "active" | "ended";

export type TodoPriority = 1 | 2 | 3;

export interface Todo {
  id: string;
  userId: string;
  title: string;
  subject: string | null;
  notes: string | null;
  category: string;
  tags: string[];
  priority: TodoPriority;
  dueAt: string | null;
  status: TodoStatus;
  completedAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface FocusSession {
  id: string;
  userId: string;
  state: SessionState;
  startedAt: string;
  endedAt: string | null;
  elapsedSeconds: number;
  totalTaskCount: number;
  completedTaskCount: number;
  createdAt: string;
  updatedAt: string;
  completionRate: number;
}

export interface SessionTaskRef {
  id: string;
  userId: string;
  sessionId: string;
  todoId: string;
  titleSnapshot: string;
  orderIndex: number;
  isCompletedInSession: boolean;
  completedAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface ActiveSessionTask {
  ref: SessionTaskRef;
  todo: Todo | null;
  displayTitle: string;
}

export interface ActiveSession {
  session: FocusSession;
  tasks: ActiveSessionTask[];
}

export interface CategoryAnalyticsPoint {
  category: string;
  taskCount: number;
  completedCount: number;
  completionRate: number;
  totalDurationSeconds: number;
}

export interface HourlyAnalyticsPoint {
  hour: number;
  sessionCount: number;
  totalDurationSeconds: number;
  completedTaskCount: number;
}

export interface PeriodAnalytics {
  sessionCount: number;
  totalDurationSeconds: number;
  completedTaskCount: number;
  completionRate: number;
}

export interface EfficiencyDeltaAnalytics {
  sessionCount: number;
  totalDurationSeconds: number;
  completionRate: number;
}

export interface EfficiencyAnalytics {
  tasksPerHour: number;
  avgCompletionRate: number;
  avgSessionDurationSeconds: number;
  periodDelta: EfficiencyDeltaAnalytics;
}

export interface DashboardAnalytics {
  date: string;
  sessionCount: number;
  totalDurationSeconds: number;
  completionRate: number;
  streakDays: number;
  completedTaskCount: number;
  period: {
    today: PeriodAnalytics;
    last7: PeriodAnalytics;
    last30: PeriodAnalytics;
  };
  categoryStats: CategoryAnalyticsPoint[];
  hourlyDistribution: HourlyAnalyticsPoint[];
  efficiency: EfficiencyAnalytics;
}

export interface TrendAnalyticsPoint {
  date: string;
  sessionCount: number;
  totalDurationSeconds: number;
  completionRate: number;
}

export interface DurationDistributionItem {
  bucketLabel: "0-15 分钟" | "15-30 分钟" | "30-45 分钟" | "45+ 分钟";
  sessionCount: number;
  totalDurationSeconds: number;
}

