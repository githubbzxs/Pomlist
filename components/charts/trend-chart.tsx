import type { TrendPoint } from "@/lib/client/types";

function formatPoints(points: TrendPoint[]) {
  const width = 680;
  const height = 260;
  const padding = 30;
  const maxValue = Math.max(1, ...points.map((point) => point.totalDurationSeconds));
  const stepX = points.length > 1 ? (width - padding * 2) / (points.length - 1) : 0;

  return points.map((point, index) => {
    const x = padding + index * stepX;
    const y =
      height -
      padding -
      (Math.max(0, point.totalDurationSeconds) / maxValue) * (height - padding * 2);
    return { ...point, x, y };
  });
}

function shortDate(dateText: string): string {
  if (dateText.length < 10) {
    return dateText;
  }
  return `${dateText.slice(5, 7)}-${dateText.slice(8, 10)}`;
}

export function TrendChart({ points }: { points: TrendPoint[] }) {
  if (points.length === 0) {
    return (
      <div className="panel-solid flex h-56 items-center justify-center p-4">
        <p className="text-sm text-subtle">暂无 7 天趋势数据</p>
      </div>
    );
  }

  const layout = formatPoints(points);
  const polyline = layout.map((point) => `${point.x},${point.y}`).join(" ");

  return (
    <div className="panel-solid p-4">
      <svg viewBox="0 0 680 260" className="h-60 w-full" role="img" aria-label="7天专注时长趋势图">
        <defs>
          <linearGradient id="trendFill" x1="0" x2="0" y1="0" y2="1">
            <stop offset="0%" stopColor="rgba(76, 221, 255, 0.38)" />
            <stop offset="100%" stopColor="rgba(76, 221, 255, 0.06)" />
          </linearGradient>
        </defs>
        <line x1="30" y1="130" x2="650" y2="130" stroke="rgba(129, 162, 205, 0.2)" strokeWidth="1.5" />
        <line x1="30" y1="230" x2="650" y2="230" stroke="rgba(129, 162, 205, 0.34)" strokeWidth="2" />
        <polyline points={`30,230 ${polyline} 650,230`} fill="url(#trendFill)" stroke="none" />
        <polyline points={polyline} fill="none" stroke="#34d4ff" strokeWidth="4" strokeLinejoin="round" strokeLinecap="round" />
        {layout.map((point) => (
          <g key={point.date}>
            <circle cx={point.x} cy={point.y} r="5" fill="#63ddff" />
            <text x={point.x} y="250" textAnchor="middle" style={{ fill: "#9db3d0", fontSize: "12px" }}>
              {shortDate(point.date)}
            </text>
          </g>
        ))}
      </svg>
    </div>
  );
}

