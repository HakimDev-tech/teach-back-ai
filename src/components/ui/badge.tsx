import type { HTMLAttributes } from "react";

import { cn } from "@/components/ui/cn";

type BadgeVariant = "neutral" | "success" | "warning" | "danger" | "accent";

type BadgeProps = HTMLAttributes<HTMLSpanElement> & {
  variant?: BadgeVariant;
};

const variants: Record<BadgeVariant, string> = {
  neutral: "bg-surface-muted text-ink-muted",
  success: "bg-success-soft text-success",
  warning: "bg-warning-soft text-warning",
  danger: "bg-danger-soft text-danger",
  accent: "bg-accent-soft text-accent",
};

export function Badge({ children, className, variant = "neutral", ...props }: BadgeProps) {
  return (
    <span
      className={cn(
        "inline-flex min-h-6 items-center rounded-full px-2.5 py-1 text-[11px] font-semibold tracking-wide",
        variants[variant],
        className,
      )}
      {...props}
    >
      {children}
    </span>
  );
}
