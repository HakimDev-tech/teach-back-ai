import Link from "next/link";

import { Card } from "@/components/ui/card";
import { SignInForm } from "@/features/auth/presentation/sign-in-form";

export default function SignInPage() {
  return (
    <Card className="rounded-[1.75rem] p-7 sm:p-9">
      <p className="text-[11px] font-bold uppercase tracking-[0.18em] text-brand">
        Account access
      </p>
      <h1 className="mt-3 font-display text-3xl tracking-tight text-ink">Welcome back</h1>
      <p className="mt-2 text-sm leading-6 text-ink-muted">
        Sign in to access your authorized professional workspace.
      </p>
      <div className="mt-8">
        <SignInForm />
      </div>
      <p className="mt-7 text-sm text-ink-muted">
        New professional?{" "}
        <Link className="font-semibold text-brand underline decoration-brand/30 underline-offset-4 hover:decoration-brand" href="/sign-up">
          Create an account
        </Link>
      </p>
    </Card>
  );
}
