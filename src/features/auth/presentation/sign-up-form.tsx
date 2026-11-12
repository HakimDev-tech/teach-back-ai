"use client";

import { useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { z } from "zod";

import { Button } from "@/components/ui/button";
import { InputField } from "@/components/ui/input-field";
import { useI18n } from "@/i18n/provider";
import { createClient } from "@/lib/supabase/client";

const schema = z.object({
  fullName: z.string().trim().min(2).max(120),
  email: z.string().email(),
  password: z.string().min(12).max(128),
});

export function SignUpForm() {
  const router = useRouter();
  const { t } = useI18n();
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);

    const data = new FormData(event.currentTarget);
    const parsed = schema.safeParse({
      fullName: data.get("fullName"),
      email: data.get("email"),
      password: data.get("password"),
    });

    if (!parsed.success) {
      setError(t("auth.signUpValidation"));
      return;
    }

    setPending(true);
    try {
      const supabase = createClient();
      const { error: authError } = await supabase.auth.signUp({
        email: parsed.data.email,
        password: parsed.data.password,
        options: {
          data: { full_name: parsed.data.fullName },
          emailRedirectTo: `${window.location.origin}/auth/callback?next=/clinician`,
        },
      });

      if (authError) {
        setError(t("auth.signUpFailed"));
        return;
      }

      router.replace("/sign-in?registered=1");
      router.refresh();
    } catch {
      setError(t("auth.serviceUnavailable"));
    } finally {
      setPending(false);
    }
  }

  return (
    <form className="space-y-5" onSubmit={handleSubmit}>
      <InputField
        autoComplete="name"
        label={t("auth.fullName")}
        maxLength={120}
        name="fullName"
        required
      />
      <InputField
        autoComplete="email"
        label={t("auth.email")}
        name="email"
        required
        type="email"
      />
      <InputField
        autoComplete="new-password"
        hint={t("auth.passwordHint")}
        label={t("auth.password")}
        maxLength={128}
        minLength={12}
        name="password"
        required
        type="password"
      />
      {error ? (
        <p
          className="rounded-xl bg-danger-soft px-3.5 py-3 text-sm leading-5 text-danger"
          role="alert"
        >
          {error}
        </p>
      ) : null}
      <Button className="w-full" disabled={pending} type="submit">
        {pending ? t("auth.creatingAccount") : t("auth.signUpSubmit")}
      </Button>
    </form>
  );
}
