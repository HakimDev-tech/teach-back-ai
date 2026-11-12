import type { HTMLAttributes, ReactNode } from "react";

import { cn } from "@/components/ui/cn";

type CardProps = HTMLAttributes<HTMLElement> & {
  children: ReactNode;
};

export function Card({ children, className, ...props }: CardProps) {
  return (
    <section
      className={cn(
        "rounded-2xl border border-line bg-surface p-6 shadow-[0_8px_28px_rgba(32,52,45,0.04)]",
        className,
      )}
      {...props}
    >
      {children}
    </section>
  );
}
