"use client";

import { useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { z } from "zod";

import { Button } from "@/components/ui/button";
import { InputField } from "@/components/ui/input-field";
import { createClient } from "@/lib/supabase/client";

const schema = z.object({
  fullName: z.string().trim().min(2).max(120),
  email: z.string().email(),
  password: z.string().min(12).max(128),
});

export function SignUpForm() {
  const router = useRouter();
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
      setError("Check your name, email, and password (minimum 12 characters).");
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
        setError("Unable to create the account. Check the details or try again later.");
        return;
      }

      router.replace("/sign-in?registered=1");
      router.refresh();
    } catch {
      setError("The registration service is temporarily unavailable. Try again.");
    } finally {
      setPending(false);
    }
  }

  return (
    <form className="space-y-5" onSubmit={handleSubmit}>
      <InputField autoComplete="name" label="Full name" maxLength={120} name="fullName" required />
      <InputField autoComplete="email" label="Email address" name="email" required type="email" />
      <InputField
        autoComplete="new-password"
        hint="Use at least 12 characters."
        label="Password"
        maxLength={128}
        minLength={12}
        name="password"
        required
        type="password"
      />
      {error ? (
        <p className="rounded-xl bg-danger-soft px-3.5 py-3 text-sm leading-5 text-danger" role="alert">
          {error}
        </p>
      ) : null}
      <Button className="w-full" disabled={pending} type="submit">
        {pending ? "Creating account…" : "Create account"}
      </Button>
    </form>
  );
}
