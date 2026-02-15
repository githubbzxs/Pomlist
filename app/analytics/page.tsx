"use client";

import { useCallback, useEffect, useState } from "react";
import { DistributionChart } from "@/components/charts/distribution-chart";
import { FeedbackState } from "@/components/feedback-state";
import { ApiClientError } from "@/lib/client/api-client";
import {
  getDashboardMetrics,
  getDistributionData,
} from "@/lib/client/pomlist-api";
import type { DashboardMetrics, DistributionBucket } from "@/lib/client/types";

function formatDuration(seconds: number): string {
  const minute = Math.floor(seconds / 60);
  if (minute < 60) {
    return `${minute} 分钟`;
  }
  const hour = Math.floor(minute / 60);
  const remain = minute % 60;
  return `${hour} 小时 ${remain} 分钟`;
}

function errorToText(error: unknown): string {
  if (error instanceof ApiClientError) {
    return error.message;
  }
  return "加载复盘数据失败，请稍后重试。";
}

const EMPTY_METRICS: DashboardMetrics = {
  date: "",
  sessionCount: 0,
  totalDurationSeconds: 0,
  completionRate: 0,
  streakDays: 0,
  completedTaskCount: 0,
};

export default function AnalyticsPage() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [metrics, setMetrics] = useState<DashboardMetrics>(EMPTY_METRICS);
  const [distribution, setDistribution] = useState<DistributionBucket[]>([]);

  const loadAnalytics = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [dashboardData, distributionData] = await Promise.all([
        getDashboardMetrics(),
        getDistributionData(30),
      ]);
      setMetrics(dashboardData);
      setDistribution(distributionData);
    } catch (loadError) {
      setError(errorToText(loadError));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadAnalytics();
  }, [loadAnalytics]);

  if (loading) {
    return <FeedbackState variant="loading" title="加载复盘中" description="正在统计你的任务钟表现" />;
  }

  if (error) {
    return (
      <FeedbackState
        variant="error"
        title="复盘加载失败"
        description={error}
        action={
          <button type="button" className="btn-primary h-10 px-4 text-sm" onClick={() => void loadAnalytics()}>
            重新加载
          </button>
        }
      />
    );
  }

  return (
    <div className="analytics-layout staggered-reveal">
      <section className="stats-overview-grid">
        <article className="glass-metric p-4">
          <p className="metric-label">今日任务钟</p>
          <p className="metric-value page-title mt-2">{metrics.sessionCount}</p>
        </article>
        <article className="glass-metric p-4">
          <p className="metric-label">今日完成任务</p>
          <p className="metric-value page-title mt-2">{metrics.completedTaskCount}</p>
        </article>
        <article className="glass-metric p-4">
          <p className="metric-label">完成率</p>
          <p className="metric-value page-title mt-2">{Math.round(metrics.completionRate)}%</p>
        </article>
        <article className="glass-metric p-4">
          <p className="metric-label">连续天数</p>
          <p className="metric-value page-title mt-2">{metrics.streakDays} 天</p>
        </article>
      </section>

      <section className="glass-card-panel mt-4">
        <div className="todo-section-title">
          <h2 className="page-title text-xl font-bold text-main">今日专注时长</h2>
          <button type="button" className="btn-muted h-9 px-3 text-sm" onClick={() => void loadAnalytics()}>
            刷新
          </button>
        </div>
        <p className="metric-value page-title mt-3 text-2xl">{formatDuration(metrics.totalDurationSeconds)}</p>
      </section>

      <section className="glass-card-panel mt-4">
        <h2 className="page-title text-xl font-bold text-main">近 30 天分布</h2>
        <p className="stats-section-subtitle">按任务钟时长分桶统计</p>
        <div className="mt-3">
          <DistributionChart buckets={distribution} />
        </div>
      </section>
    </div>
  );
}
