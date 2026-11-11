import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
export default async function ClinicianHomePage() {
  const supabase = await createClient(); const { data: { user }, error } = await supabase.auth.getUser();
  if (error || !user) redirect("/sign-in");
  return <main className="mx-auto max-w-4xl px-6 py-16"><h1 className="text-2xl font-semibold">Professional workspace</h1><p className="mt-3 text-slate-600">Signed in as {user.email}. Organization membership is required for tenant-scoped access.</p><form action="/auth/sign-out" method="post" className="mt-8"><button className="rounded-md border border-slate-300 px-4 py-2">Sign out</button></form></main>;
}
