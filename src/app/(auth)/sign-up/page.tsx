import Link from "next/link";

import { Card } from "@/components/ui/card";
import { SignUpForm } from "@/features/auth/presentation/sign-up-form";
import { getServerI18n } from "@/i18n/server";

export default async function SignUpPage() {
  const { t } = await getServerI18n();

  return (
    <Card className="rounded-[1.75rem] p-7 sm:p-9">
      <p className="text-[11px] font-bold uppercase tracking-[0.18em] text-brand">
        {t("auth.signUpEyebrow")}
      </p>
      <h1 className="mt-3 font-display text-3xl tracking-tight text-ink">
        {t("auth.signUpTitle")}
      </h1>
      <p className="mt-2 text-sm leading-6 text-ink-muted">{t("auth.signUpDescription")}</p>
      <div className="mt-8">
        <SignUpForm />
      </div>
      <p className="mt-7 text-sm text-ink-muted">
        {t("auth.alreadyRegistered")}{" "}
        <Link
          className="font-semibold text-brand underline decoration-brand/30 underline-offset-4 hover:decoration-brand"
          href="/sign-in"
        >
          {t("auth.signInLink")}
        </Link>
      </p>
    </Card>
  );
}
