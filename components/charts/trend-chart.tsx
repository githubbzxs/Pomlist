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
      <div className="glass-chart-wrap chart-empty">
        <p>暂无 7 天趋势数据</p>
      </div>
    );
  }

  const layout = formatPoints(points);
  const polyline = layout.map((point) => `${point.x},${point.y}`).join(" ");
  const area = `30,230 ${polyline} 650,230`;
  const gridLines = [60, 95, 130, 165, 200];

  return (
    <div className="glass-chart-wrap p-4">
      <svg viewBox="0 0 680 260" className="h-60 w-full" role="img" aria-label="7天专注时长趋势图">
        {gridLines.map((y) => (
          <line
            key={y}
            x1="30"
            y1={y}
            x2="650"
            y2={y}
            stroke="rgba(148,163,184,0.36)"
            strokeWidth="1"
            strokeDasharray="4 8"
          />
        ))}

        <line x1="30" y1="230" x2="650" y2="230" stroke="rgba(148,163,184,0.44)" strokeWidth="2" />
        <polyline points={area} fill="rgba(10,132,255,0.14)" stroke="none" />
        <polyline
          points={polyline}
          fill="none"
          stroke="#0a84ff"
          strokeWidth="4"
          strokeLinejoin="round"
          strokeLinecap="round"
        />
        {layout.map((point) => (
          <g key={point.date}>
            <circle cx={point.x} cy={point.y} r="9" fill="rgba(10,132,255,0.16)" />
            <circle cx={point.x} cy={point.y} r="5.5" fill="#0a84ff" />
            <text x={point.x} y="250" textAnchor="middle" className="fill-[rgba(107,114,128,0.9)] text-[11px]">
              {shortDate(point.date)}
            </text>
          </g>
        ))}
      </svg>
    </div>
  );
}
