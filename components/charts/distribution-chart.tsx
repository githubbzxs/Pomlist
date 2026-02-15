import type { DistributionBucket } from "@/lib/client/types";

function toMinutes(seconds: number): number {
  return Math.round(seconds / 60);
}

export function DistributionChart({ buckets }: { buckets: DistributionBucket[] }) {
  if (buckets.length === 0) {
    return (
      <div className="glass-chart-wrap chart-empty">
        <p>暂无 30 天分布数据</p>
      </div>
    );
  }

  const max = Math.max(1, ...buckets.map((item) => item.totalDurationSeconds));

  return (
    <div className="glass-chart-wrap space-y-3 p-4">
      {buckets.map((bucket) => {
        const ratio = Math.min(100, (bucket.totalDurationSeconds / max) * 100);
        const minutes = toMinutes(bucket.totalDurationSeconds);
        return (
          <div key={bucket.bucketLabel}>
            <div className="mb-1 flex items-center justify-between text-sm">
              <span className="text-subtle">{bucket.bucketLabel}</span>
              <span className="font-semibold text-main">
                {bucket.sessionCount} 次 · {minutes} 分钟
              </span>
            </div>
            <div className="h-3 rounded-full bg-[rgba(15,23,42,0.08)]">
              <div
                className="h-full rounded-full"
                style={{ width: `${ratio}%`, backgroundColor: "var(--accent)" }}
              />
            </div>
          </div>
        );
      })}
    </div>
  );
}
