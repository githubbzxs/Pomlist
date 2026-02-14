"use client";

import { useCallback, useEffect, useState } from "react";
import { DistributionChart } from "@/components/charts/distribution-chart";
import { TrendChart } from "@/components/charts/trend-chart";
import { FeedbackState } from "@/components/feedback-state";
import { ApiClientError } from "@/lib/client/api-client";
import {
  getDashboardMetrics,
  getDistributionData,
  getTrendData,
} from "@/lib/client/pomlist-api";
import type { DashboardMetrics, DistributionBucket, TrendPoint } from "@/lib/client/types";

function formatDuration(seconds: number): string {
  const minute = Math.floor(seconds / 60);
  if (minute < 60) {
    return `${minute} 分钟`;
  }
  const hour = Math.floor(minute / 60);
  const remain = minute % 60;
  return `${hour} 小时 ${remain} 分`;
}

function errorToText(error: unknown): string {
  if (error instanceof ApiClientError) {
    return error.message;
  }
  return "加载复盘数据失败，请稍后重试。";
}

export default function AnalyticsPage() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [metrics, setMetrics] = useState<DashboardMetrics>({
    date: "",
    sessionCount: 0,
    totalDurationSeconds: 0,
    completionRate: 0,
    streakDays: 0,
    completedTaskCount: 0,
  });
  const [trend, setTrend] = useState<TrendPoint[]>([]);
  const [distribution, setDistribution] = useState<DistributionBucket[]>([]);

  const loadAnalytics = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [dashboardData, trendData, distributionData] = await Promise.all([
        getDashboardMetrics(),
        getTrendData(7),
        getDistributionData(30),
      ]);
      setMetrics(dashboardData);
      setTrend(trendData);
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
    <div className="staggered-reveal space-y-4 pb-20">
      <section className="grid grid-cols-2 gap-3 md:grid-cols-4">
        <article className="panel p-4">
          <p className="text-xs text-subtle">今日任务钟</p>
          <p className="page-title mt-2 text-2xl font-bold text-main">{metrics.sessionCount}</p>
        </article>
        <article className="panel p-4">
          <p className="text-xs text-subtle">今日完成任务</p>
          <p className="page-title mt-2 text-2xl font-bold text-main">{metrics.completedTaskCount}</p>
        </article>
        <article className="panel p-4">
          <p className="text-xs text-subtle">完成率</p>
          <p className="page-title mt-2 text-2xl font-bold text-main">{Math.round(metrics.completionRate)}%</p>
        </article>
        <article className="panel p-4">
          <p className="text-xs text-subtle">连续天数</p>
          <p className="page-title mt-2 text-2xl font-bold text-main">{metrics.streakDays} 天</p>
        </article>
      </section>

      <section className="panel p-4">
        <div className="flex items-center justify-between">
          <h2 className="page-title text-xl font-bold text-main">今日专注时长</h2>
          <button type="button" className="btn-muted h-9 px-3 text-sm" onClick={() => void loadAnalytics()}>
            刷新
          </button>
        </div>
        <p className="mt-3 text-lg font-semibold text-main">{formatDuration(metrics.totalDurationSeconds)}</p>
      </section>

      <section className="panel p-4">
        <h2 className="page-title text-xl font-bold text-main">近 7 天趋势</h2>
        <p className="mt-1 text-sm text-subtle">按每日任务钟统计总时长</p>
        <div className="mt-3">
          <TrendChart points={trend} />
        </div>
      </section>

      <section className="panel p-4">
        <h2 className="page-title text-xl font-bold text-main">近 30 天时长分布</h2>
        <p className="mt-1 text-sm text-subtle">按任务钟时长分桶统计</p>
        <div className="mt-3">
          <DistributionChart buckets={distribution} />
        </div>
      </section>
    </div>
  );
}

