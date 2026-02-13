export type TodoStatus = "pending" | "completed" | "archived";

export type TodoItem = {
  id: string;
  title: string;
  subject: string | null;
  notes: string | null;
  priority: 1 | 2 | 3;
  dueAt: string | null;
  status: TodoStatus;
  completedAt: string | null;
};

export type SessionTask = {
  todoId: string;
  title: string;
  completed: boolean;
};

export type ActiveSession = {
  id: string;
  state: "active" | "ended";
  startedAt: string;
  endedAt: string | null;
  elapsedSeconds: number;
  totalTaskCount: number;
  completedTaskCount: number;
  completionRate: number;
  tasks: SessionTask[];
};

export type DashboardMetrics = {
  date: string;
  sessionCount: number;
  totalDurationSeconds: number;
  completionRate: number;
  streakDays: number;
  completedTaskCount: number;
};

export type TrendPoint = {
  date: string;
  sessionCount: number;
  totalDurationSeconds: number;
  completionRate: number;
};

export type DistributionBucket = {
  bucketLabel: "0-15 分钟" | "15-30 分钟" | "30-45 分钟" | "45+ 分钟";
  sessionCount: number;
  totalDurationSeconds: number;
};

export type AuthCredentials = {
  email: string;
  password: string;
};

