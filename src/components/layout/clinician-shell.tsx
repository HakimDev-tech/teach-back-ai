import Link from "next/link";
import type { ReactNode } from "react";

import { Button } from "@/components/ui/button";

type ClinicianShellProps = {
  children: ReactNode;
  userEmail: string;
};

function Brand() {
  return (
    <Link className="inline-flex items-center gap-3" href="/clinician">
      <span className="grid size-10 place-items-center rounded-2xl bg-brand text-xs font-bold tracking-tight text-white">
        tb
      </span>
      <span className="text-sm font-bold tracking-tight text-ink">
        Teach-back <span className="text-accent">AI</span>
      </span>
    </Link>
  );
}

export function ClinicianShell({ children, userEmail }: ClinicianShellProps) {
  return (
    <div className="min-h-screen bg-canvas text-ink lg:grid lg:grid-cols-[15.5rem_minmax(0,1fr)]">
      <a
        className="sr-only z-50 rounded-xl bg-surface px-4 py-3 font-semibold text-brand focus:fixed focus:start-4 focus:top-4 focus:not-sr-only"
        href="#main-content"
      >
        Skip to main content
      </a>
      <aside className="hidden border-e border-line bg-surface px-5 py-7 lg:flex lg:flex-col">
        <Brand />
        <div className="mt-12">
          <p className="px-3 text-[11px] font-bold uppercase tracking-[0.18em] text-ink-muted">
            Workspace
          </p>
          <nav aria-label="Primary navigation" className="mt-3">
            <Link
              aria-current="page"
              className="flex min-h-11 items-center gap-3 rounded-xl bg-brand-soft px-3 text-sm font-semibold text-brand"
              href="/clinician"
            >
              <span aria-hidden="true" className="size-2 rounded-full bg-brand" />
              Overview
            </Link>
          </nav>
        </div>
        <div className="mt-auto rounded-2xl bg-brand-soft p-4">
          <p className="text-xs font-bold text-brand">The Teach-Back method</p>
          <p className="mt-2 text-xs leading-5 text-ink-muted">
            Understanding care is part of receiving care.
          </p>
        </div>
      </aside>

      <div className="min-w-0">
        <header className="sticky top-0 z-20 flex min-h-16 items-center justify-between border-b border-line bg-surface px-5 sm:px-8">
          <div className="lg:hidden">
            <Brand />
          </div>
          <p className="hidden text-sm font-medium text-ink-muted lg:block">Clinician workspace</p>
          <div className="ms-auto flex items-center gap-3">
            <span className="hidden max-w-56 truncate text-xs text-ink-muted sm:block">
              {userEmail}
            </span>
            <form action="/auth/sign-out" method="post">
              <Button size="sm" type="submit" variant="ghost">
                Sign out
              </Button>
            </form>
          </div>
        </header>
        <main className="mx-auto w-full max-w-7xl px-5 py-8 sm:px-8 lg:px-10 lg:py-10" id="main-content" tabIndex={-1}>
          {children}
        </main>
      </div>
    </div>
  );
}
