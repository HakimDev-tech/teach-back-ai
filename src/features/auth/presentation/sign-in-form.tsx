"use client";

import { useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { z } from "zod";

import { Button } from "@/components/ui/button";
import { InputField } from "@/components/ui/input-field";
import { createClient } from "@/lib/supabase/client";

const schema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

export function SignInForm() {
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);

    const data = new FormData(event.currentTarget);
    const parsed = schema.safeParse({
      email: data.get("email"),
      password: data.get("password"),
    });

    if (!parsed.success) {
      setError("Enter a valid email address and password.");
      return;
    }

    setPending(true);
    try {
      const supabase = createClient();
      const { error: authError } = await supabase.auth.signInWithPassword(parsed.data);
      if (authError) {
        setError("Unable to sign in with those credentials.");
        return;
      }
      router.replace("/clinician");
      router.refresh();
    } catch {
      setError("The sign-in service is temporarily unavailable. Try again.");
    } finally {
      setPending(false);
    }
  }

  return (
    <form className="space-y-5" onSubmit={handleSubmit}>
      <InputField
        autoComplete="email"
        label="Email address"
        name="email"
        required
        type="email"
      />
      <InputField
        autoComplete="current-password"
        label="Password"
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
        {pending ? "Signing in…" : "Sign in"}
      </Button>
    </form>
  );
}
