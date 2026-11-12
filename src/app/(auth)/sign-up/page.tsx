import Link from "next/link";

import { Card } from "@/components/ui/card";
import { SignUpForm } from "@/features/auth/presentation/sign-up-form";

export default function SignUpPage() {
  return (
    <Card className="rounded-[1.75rem] p-7 sm:p-9">
      <p className="text-[11px] font-bold uppercase tracking-[0.18em] text-brand">
        Professional registration
      </p>
      <h1 className="mt-3 font-display text-3xl tracking-tight text-ink">
        Create your account
      </h1>
      <p className="mt-2 text-sm leading-6 text-ink-muted">
        Registration does not grant clinical or organization permissions. An authorized
        organization member must grant access.
      </p>
      <div className="mt-8">
        <SignUpForm />
      </div>
      <p className="mt-7 text-sm text-ink-muted">
        Already registered?{" "}
        <Link className="font-semibold text-brand underline decoration-brand/30 underline-offset-4 hover:decoration-brand" href="/sign-in">
          Sign in
        </Link>
      </p>
    </Card>
  );
}
