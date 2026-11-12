"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

import { useI18n } from "@/i18n/provider";

const items = [
  { href: "/clinician", key: "clinician.overview" as const },
  { href: "/clinician/patients", key: "patients.nav" as const },
  { href: "/clinician/access", key: "clinicalAccess.nav" as const },
];

export function ClinicianNavigation({ mobile = false }: { mobile?: boolean }) {
  const pathname = usePathname();
  const { t } = useI18n();

  return (
    <nav
      aria-label={t("clinician.navigation")}
      className={mobile ? "flex gap-2 overflow-x-auto px-5 py-2 sm:px-8" : "mt-3 space-y-1"}
    >
      {items.map((item) => {
        const active =
          item.href === "/clinician"
            ? pathname === item.href
            : pathname === item.href || pathname.startsWith(`${item.href}/`);

        return (
          <Link
            aria-current={active ? "page" : undefined}
            className={
              mobile
                ? `inline-flex min-h-10 shrink-0 items-center rounded-xl px-3 text-sm font-semibold transition-colors ${active ? "bg-brand-soft text-brand" : "text-ink-muted hover:bg-surface-muted hover:text-ink"}`
                : `flex min-h-11 items-center gap-3 rounded-xl px-3 text-sm font-semibold transition-colors ${active ? "bg-brand-soft text-brand" : "text-ink-muted hover:bg-surface-muted hover:text-ink"}`
            }
            href={item.href}
            key={item.href}
          >
            {active ? <span aria-hidden="true" className="size-2 rounded-full bg-brand" /> : null}
            {t(item.key)}
          </Link>
        );
      })}
    </nav>
  );
}
