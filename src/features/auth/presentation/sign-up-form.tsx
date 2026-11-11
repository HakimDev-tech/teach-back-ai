"use client";

import { useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { z } from "zod";

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
    const supabase = createClient();
    const { error: authError } = await supabase.auth.signUp({
      email: parsed.data.email,
      password: parsed.data.password,
      options: {
        data: { full_name: parsed.data.fullName },
        emailRedirectTo: `${window.location.origin}/auth/callback?next=/clinician`,
      },
    });
    setPending(false);

    if (authError) {
      setError("Unable to create the account. Check the details or try again later.");
      return;
    }

    router.replace("/sign-in?registered=1");
    router.refresh();
  }

  return (
    <form className="space-y-4" onSubmit={handleSubmit}>
      <label className="block text-sm font-medium">
        Full name
        <input
          className="mt-1 w-full rounded-md border border-slate-300 bg-white p-3"
          name="fullName"
          autoComplete="name"
          required
          maxLength={120}
        />
      </label>
      <label className="block text-sm font-medium">
        Email
        <input
          className="mt-1 w-full rounded-md border border-slate-300 bg-white p-3"
          name="email"
          type="email"
          autoComplete="email"
          required
        />
      </label>
      <label className="block text-sm font-medium">
        Password
        <input
          className="mt-1 w-full rounded-md border border-slate-300 bg-white p-3"
          name="password"
          type="password"
          autoComplete="new-password"
          minLength={12}
          maxLength={128}
          required
        />
      </label>
      {error ? (
        <p role="alert" className="text-sm text-red-700">
          {error}
        </p>
      ) : null}
      <button
        className="w-full rounded-md bg-emerald-900 p-3 font-medium text-white disabled:opacity-60"
        disabled={pending}
      >
        {pending ? "Creating account…" : "Create account"}
      </button>
    </form>
  );
}
