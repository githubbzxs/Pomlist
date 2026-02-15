export type TodoStatus = "pending" | "completed" | "archived";

export type TodoItem = {
  id: string;
  title: string;
  subject: string | null;
  notes: string | null;
  category: string;
  tags: string[];
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

export type SessionHistoryItem = {
  id: string;
  startedAt: string;
  endedAt: string | null;
  elapsedSeconds: number;
  totalTaskCount: number;
  completedTaskCount: number;
  completionRate: number;
  tasks: SessionTask[];
};

export type CategoryStatsItem = {
  category: string;
  taskCount: number;
  completedCount: number;
  completionRate: number;
  totalDurationSeconds: number;
};

export type HourlyStatsItem = {
  hour: number;
  sessionCount: number;
  totalDurationSeconds: number;
  completedTaskCount: number;
};

export type PeriodMetrics = {
  sessionCount: number;
  totalDurationSeconds: number;
  completedTaskCount: number;
  completionRate: number;
};

export type EfficiencyDelta = {
  sessionCount: number;
  totalDurationSeconds: number;
  completionRate: number;
};

export type EfficiencyMetrics = {
  tasksPerHour: number;
  avgCompletionRate: number;
  avgSessionDurationSeconds: number;
  periodDelta: EfficiencyDelta;
};

export type DashboardMetrics = {
  date: string;
  sessionCount: number;
  totalDurationSeconds: number;
  completionRate: number;
  streakDays: number;
  completedTaskCount: number;
  period?: {
    today: PeriodMetrics;
    last7: PeriodMetrics;
    last30: PeriodMetrics;
  };
  categoryStats?: CategoryStatsItem[];
  hourlyDistribution?: HourlyStatsItem[];
  efficiency?: EfficiencyMetrics;
};

export type TrendPoint = {
  date: string;
  sessionCount: number;
  totalDurationSeconds: number;
  completionRate: number;
};

export type DistributionBucket = {
  bucketLabel: string;
  sessionCount: number;
  totalDurationSeconds: number;
};

export type AuthCredentials = {
  passcode: string;
};

