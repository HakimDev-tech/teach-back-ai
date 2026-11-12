import Link from "next/link";
import type { ReactNode } from "react";

import { LocaleSwitcher } from "@/components/layout/locale-switcher";
import { getServerI18n } from "@/i18n/server";

type AuthLayoutProps = {
  children: ReactNode;
};

export default async function AuthLayout({ children }: AuthLayoutProps) {
  const { t } = await getServerI18n();

  return (
    <div className="min-h-screen bg-canvas lg:grid lg:grid-cols-[minmax(0,1.1fr)_minmax(28rem,0.9fr)]">
      <aside className="hidden flex-col justify-between bg-brand px-12 py-10 text-white lg:flex">
        <Link className="inline-flex items-center gap-3 text-sm font-bold tracking-tight" href="/">
          <span
            className="grid size-10 place-items-center rounded-2xl bg-white/12 text-xs text-white"
            dir="ltr"
          >
            tb
          </span>
          <span>
            Teach-back <span className="text-white/70">AI</span>
          </span>
        </Link>
        <div className="max-w-xl">
          <p className="text-[11px] font-bold uppercase tracking-[0.2em] text-white/70">
            {t("auth.sidebarEyebrow")}
          </p>
          <h2 className="mt-6 font-display text-5xl leading-[1.06] tracking-tight">
            {t("auth.sidebarTitle")}
          </h2>
          <p className="mt-6 max-w-md text-base leading-7 text-white/80">
            {t("auth.sidebarDescription")}
          </p>
        </div>
        <p className="text-xs leading-5 text-white/65">{t("auth.sidebarNote")}</p>
      </aside>
      <a
        className="sr-only z-50 rounded-xl bg-surface px-4 py-3 font-semibold text-brand focus:fixed focus:start-4 focus:top-4 focus:not-sr-only"
        href="#auth-content"
      >
        {t("common.skipForm")}
      </a>
      <section
        className="flex min-h-screen items-center justify-center px-5 py-12 sm:px-8"
        id="auth-content"
        tabIndex={-1}
      >
        <div className="w-full max-w-md">
          <div className="mb-8 flex items-center justify-between gap-3">
            <Link className="inline-flex items-center gap-2 text-sm font-bold text-ink lg:hidden" href="/">
              <span
                className="grid size-9 place-items-center rounded-xl bg-brand text-xs text-white"
                dir="ltr"
              >
                tb
              </span>
              Teach-back <span className="text-accent">AI</span>
            </Link>
            <LocaleSwitcher className="ms-auto" />
          </div>
          {children}
        </div>
      </section>
    </div>
  );
}
