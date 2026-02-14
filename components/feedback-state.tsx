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
      <div
        className={`mx-auto flex h-12 w-12 items-center justify-center rounded-full border border-[var(--line-soft)] bg-[rgba(15,23,42,0.7)] text-xl text-main ${
          variant === "loading" ? "animate-spin" : ""
        }`}
      >
        {ICON_MAP[variant]}
      </div>
      <h2 className="page-title mt-3 text-xl font-bold text-main">{title}</h2>
      {description ? <p className="mt-2 text-sm text-subtle">{description}</p> : null}
      {action ? <div className="mt-4 flex justify-center">{action}</div> : null}
    </section>
  );
}
