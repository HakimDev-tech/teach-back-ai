import Link from "next/link";

import { Card } from "@/components/ui/card";
import { SignInForm } from "@/features/auth/presentation/sign-in-form";
import { getServerI18n } from "@/i18n/server";

type SignInPageProps = {
  searchParams: Promise<{
    error?: string;
    registered?: string;
  }>;
};

export default async function SignInPage({ searchParams }: SignInPageProps) {
  const [{ t }, params] = await Promise.all([getServerI18n(), searchParams]);

  return (
    <Card className="rounded-[1.75rem] p-7 sm:p-9">
      <p className="text-[11px] font-bold uppercase tracking-[0.18em] text-brand">
        {t("auth.signInEyebrow")}
      </p>
      <h1 className="mt-3 font-display text-3xl tracking-tight text-ink">
        {t("auth.signInTitle")}
      </h1>
      <p className="mt-2 text-sm leading-6 text-ink-muted">{t("auth.signInDescription")}</p>
      {params.registered === "1" ? (
        <p className="mt-5 rounded-xl bg-success-soft px-3.5 py-3 text-sm leading-5 text-success" role="status">
          {t("auth.registeredSuccess")}
        </p>
      ) : null}
      {params.error === "auth_callback" ? (
        <p className="mt-5 rounded-xl bg-danger-soft px-3.5 py-3 text-sm leading-5 text-danger" role="alert">
          {t("auth.callbackError")}
        </p>
      ) : null}
      <div className="mt-8">
        <SignInForm />
      </div>
      <p className="mt-7 text-sm text-ink-muted">
        {t("auth.newProfessional")}{" "}
        <Link
          className="font-semibold text-brand underline decoration-brand/30 underline-offset-4 hover:decoration-brand"
          href="/sign-up"
        >
          {t("auth.createAccountLink")}
        </Link>
      </p>
    </Card>
  );
}
