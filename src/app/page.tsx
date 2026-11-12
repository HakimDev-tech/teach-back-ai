import Link from "next/link";

import { LocaleSwitcher } from "@/components/layout/locale-switcher";
import { Badge } from "@/components/ui/badge";
import { getServerI18n } from "@/i18n/server";

export default async function HomePage() {
  const { t } = await getServerI18n();
  const steps = [
    {
      number: "01",
      title: t("landing.step1.title"),
      description: t("landing.step1.description"),
    },
    {
      number: "02",
      title: t("landing.step2.title"),
      description: t("landing.step2.description"),
    },
    {
      number: "03",
      title: t("landing.step3.title"),
      description: t("landing.step3.description"),
    },
  ];

  return (
    <div className="min-h-screen bg-canvas">
      <header className="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-4 px-5 py-5 sm:px-8">
        <Link
          className="inline-flex items-center gap-3 text-sm font-bold tracking-tight text-ink"
          href="/"
        >
          <span
            className="grid size-10 place-items-center rounded-2xl bg-brand text-xs text-white"
            dir="ltr"
          >
            tb
          </span>
          Teach-back <span className="text-accent">AI</span>
        </Link>
        <nav aria-label={t("nav.account")} className="flex flex-wrap items-center gap-2 sm:gap-3">
          <LocaleSwitcher />
          <Link
            className="rounded-xl px-3 py-2 text-sm font-semibold text-ink-muted transition-colors hover:bg-surface-muted hover:text-ink"
            href="/sign-in"
          >
            {t("nav.signIn")}
          </Link>
          <Link
            className="inline-flex min-h-10 items-center rounded-xl bg-brand px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-brand-hover"
            href="/sign-up"
          >
            {t("nav.professionals")}
          </Link>
        </nav>
      </header>

      <a
        className="sr-only z-50 rounded-xl bg-surface px-4 py-3 font-semibold text-brand focus:fixed focus:start-4 focus:top-4 focus:not-sr-only"
        href="#main-content"
      >
        {t("common.skipMain")}
      </a>
      <main id="main-content">
        <section className="mx-auto grid max-w-7xl items-center gap-14 px-5 py-16 sm:px-8 lg:grid-cols-[1.12fr_0.88fr] lg:py-24">
          <div>
            <Badge variant="success">{t("landing.badge")}</Badge>
            <h1 className="mt-7 max-w-3xl font-display text-5xl leading-[1.04] tracking-tight text-ink sm:text-6xl lg:text-7xl">
              {t("landing.headline")}
            </h1>
            <p className="mt-7 max-w-2xl text-lg leading-8 text-ink-muted">
              {t("landing.description")}
            </p>
            <div className="mt-9 flex flex-wrap items-center gap-3">
              <Link
                className="inline-flex min-h-12 items-center rounded-xl bg-brand px-5 py-3 text-sm font-semibold text-white shadow-sm transition-colors hover:bg-brand-hover"
                href="/sign-up"
              >
                {t("landing.createAccount")}
              </Link>
              <Link
                className="inline-flex min-h-12 items-center rounded-xl border border-line bg-surface px-5 py-3 text-sm font-semibold text-ink transition-colors hover:bg-surface-muted"
                href="/sign-in"
              >
                {t("landing.signIn")}
              </Link>
            </div>
            <p className="mt-6 max-w-xl text-xs leading-5 text-ink-muted">
              {t("landing.disclaimer")}
            </p>
          </div>

          <div className="rounded-[2rem] border border-line bg-surface p-7 shadow-[0_24px_70px_rgba(32,52,45,0.08)] sm:p-9">
            <p className="text-[11px] font-bold uppercase tracking-[0.18em] text-brand">
              {t("landing.loopEyebrow")}
            </p>
            <ol className="mt-8 space-y-7">
              {steps.map((step) => (
                <li className="flex gap-4" key={step.number}>
                  <span
                    className="grid size-11 shrink-0 place-items-center rounded-2xl bg-brand-soft text-sm font-bold tabular-nums text-brand"
                    dir="ltr"
                  >
                    {step.number}
                  </span>
                  <div className="pt-0.5">
                    <h2 className="font-display text-xl text-ink">{step.title}</h2>
                    <p className="mt-1.5 text-sm leading-6 text-ink-muted">{step.description}</p>
                  </div>
                </li>
              ))}
            </ol>
            <div className="mt-8 border-t border-line pt-5">
              <p className="text-sm font-semibold text-ink">{t("landing.humanReviewTitle")}</p>
              <p className="mt-1 text-xs leading-5 text-ink-muted">
                {t("landing.humanReviewDescription")}
              </p>
            </div>
          </div>
        </section>
      </main>

      <footer className="border-t border-line px-5 py-6 sm:px-8">
        <div className="mx-auto flex max-w-7xl flex-col gap-2 text-xs text-ink-muted sm:flex-row sm:items-center sm:justify-between">
          <span>Teach-back AI</span>
          <span>{t("landing.footerTagline")}</span>
        </div>
      </footer>
    </div>
  );
}
