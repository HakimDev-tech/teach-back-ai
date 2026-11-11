"use client";
import { useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { z } from "zod";
import { createClient } from "@/lib/supabase/client";
const schema = z.object({ email: z.string().email(), password: z.string().min(1) });
export function SignInForm() {
  const router = useRouter(); const [error, setError] = useState<string | null>(null); const [pending, setPending] = useState(false);
  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setError(null);
    const data = new FormData(event.currentTarget);
    const parsed = schema.safeParse({ email: data.get("email"), password: data.get("password") });
    if (!parsed.success) { setError("Enter a valid email and password."); return; }
    setPending(true); const supabase = createClient();
    const { error: authError } = await supabase.auth.signInWithPassword(parsed.data); setPending(false);
    if (authError) { setError("Unable to sign in with those credentials."); return; }
    router.replace("/clinician"); router.refresh();
  }
  return <form className="space-y-4" onSubmit={handleSubmit}>
    <label className="block text-sm font-medium">Email<input className="mt-1 w-full rounded-md border border-slate-300 bg-white p-3" name="email" type="email" autoComplete="email" required /></label>
    <label className="block text-sm font-medium">Password<input className="mt-1 w-full rounded-md border border-slate-300 bg-white p-3" name="password" type="password" autoComplete="current-password" required /></label>
    {error ? <p role="alert" className="text-sm text-red-700">{error}</p> : null}
    <button className="w-full rounded-md bg-emerald-900 p-3 font-medium text-white disabled:opacity-60" disabled={pending}>{pending ? "Signing in…" : "Sign in"}</button>
  </form>;
}
