import type { ReactNode } from "react";

type PageHeaderProps = {
  actions?: ReactNode;
  description?: string;
  eyebrow?: string;
  title: string;
};

export function PageHeader({ actions, description, eyebrow, title }: PageHeaderProps) {
  return (
    <div className="mb-8 flex flex-col gap-5 sm:flex-row sm:items-end sm:justify-between">
      <div className="max-w-3xl">
        {eyebrow ? (
          <p className="mb-2 text-[11px] font-bold uppercase tracking-[0.18em] text-brand">
            {eyebrow}
          </p>
        ) : null}
        <h1 className="font-display text-3xl leading-tight tracking-tight text-ink sm:text-4xl">
          {title}
        </h1>
        {description ? (
          <p className="mt-3 max-w-2xl text-sm leading-6 text-ink-muted sm:text-base">
            {description}
          </p>
        ) : null}
      </div>
      {actions ? <div className="flex shrink-0 items-center gap-2">{actions}</div> : null}
    </div>
  );
}
