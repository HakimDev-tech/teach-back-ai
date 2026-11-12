import { redirect } from "next/navigation";

import { ClinicianShell } from "@/components/layout/clinician-shell";
import { createClient } from "@/lib/supabase/server";

export default async function ClinicianLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const supabase = await createClient();
  const {
    data: { user },
    error,
  } = await supabase.auth.getUser();

  if (error || !user) {
    redirect("/sign-in");
  }

  return <ClinicianShell userEmail={user.email ?? "Signed in"}>{children}</ClinicianShell>;
}
