import type { ReactNode } from "react";

type FeedbackStateProps = {
  variant: "loading" | "empty" | "error";
  title: string;
  description?: string;
  action?: ReactNode;
};

const ICON_MAP: Record<FeedbackStateProps["variant"], string> = {
  loading: "⟳",
  empty: "◌",
  error: "!",
};

export function FeedbackState({
  variant,
  title,
  description,
  action,
}: FeedbackStateProps) {
  return (
    <section className="panel mx-auto w-full max-w-xl p-6 text-center">
      <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-full border border-slate-200 bg-white text-xl text-slate-700">
        {ICON_MAP[variant]}
      </div>
      <h2 className="page-title mt-3 text-xl font-bold text-slate-900">{title}</h2>
      {description ? <p className="mt-2 text-sm text-subtle">{description}</p> : null}
      {action ? <div className="mt-4 flex justify-center">{action}</div> : null}
    </section>
  );
}
