type EndSessionDialogProps = {
  open: boolean;
  completed: number;
  total: number;
  onCancel: () => void;
  onConfirm: () => void;
  confirming: boolean;
};

export function EndSessionDialog({
  open,
  completed,
  total,
  onCancel,
  onConfirm,
  confirming,
}: EndSessionDialogProps) {
  if (!open) {
    return null;
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/45 p-4">
      <section className="panel w-full max-w-sm p-5">
        <h2 className="page-title text-xl font-bold text-slate-900">确认结束任务钟？</h2>
        <p className="mt-2 text-sm text-subtle">
          你当前完成了 <span className="font-bold text-slate-900">{completed}</span>/
          <span className="font-bold text-slate-900">{total}</span> 项任务。
        </p>
        <p className="mt-1 text-sm text-subtle">结束后会立即写入复盘统计。</p>
        <div className="mt-5 grid grid-cols-2 gap-3">
          <button type="button" onClick={onCancel} className="btn-muted h-11">
            继续专注
          </button>
          <button
            type="button"
            onClick={onConfirm}
            disabled={confirming}
            className="btn-primary h-11"
          >
            {confirming ? "正在结束..." : "确认结束"}
          </button>
        </div>
      </section>
    </div>
  );
}
