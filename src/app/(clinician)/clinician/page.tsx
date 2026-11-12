import { redirect } from "next/navigation";

import { Badge } from "@/components/ui/badge";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";
import { PageHeader } from "@/components/ui/page-header";
import { createClient } from "@/lib/supabase/server";

export default async function ClinicianHomePage() {
  const supabase = await createClient();
  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser();

  if (authError || !user) {
    redirect("/sign-in");
  }

  const { data: memberships, error } = await supabase
    .from("organization_memberships")
    .select("id, role, status")
    .eq("user_id", user.id)
    .eq("status", "active");

  const activeMemberships = memberships ?? [];

  return (
    <div className="space-y-8">
      <PageHeader
        description="A secure starting point for authorized care workflows. Access is scoped to your organization membership, clinical capability, and active patient assignments."
        eyebrow="CLINICIAN WORKSPACE"
        title="Overview"
      />

      {error ? (
        <Card>
          <Badge variant="warning">Access check unavailable</Badge>
          <h2 className="mt-4 font-display text-xl text-ink">Workspace access could not be loaded</h2>
          <p className="mt-2 text-sm leading-6 text-ink-muted">
            Refresh the page or try again later. No clinical records are displayed while access
            cannot be verified.
          </p>
        </Card>
      ) : activeMemberships.length === 0 ? (
        <EmptyState
          description="Your account is authenticated, but no active organization membership is linked to it. An authorized organization owner or administrator must grant access before clinical records become available."
          title="Organization access is required"
        />
      ) : (
        <div className="grid gap-5 lg:grid-cols-[minmax(0,1fr)_minmax(18rem,0.8fr)]">
          <Card>
            <p className="text-xs font-bold uppercase tracking-[0.16em] text-ink-muted">
              Organization access
            </p>
            <p className="mt-4 font-display text-5xl tabular-nums text-ink">
              {activeMemberships.length}
            </p>
            <p className="mt-2 text-sm text-ink-muted">
              Active organization membership{activeMemberships.length === 1 ? "" : "s"}.
            </p>
            <ul className="mt-6 space-y-3 border-t border-line pt-5">
              {activeMemberships.map((membership) => (
                <li className="flex items-center justify-between gap-3" key={membership.id}>
                  <span className="text-sm font-medium text-ink">Organization membership</span>
                  <Badge variant={membership.role === "clinician" ? "success" : "neutral"}>
                    {membership.role}
                  </Badge>
                </li>
              ))}
            </ul>
          </Card>
          <Card>
            <p className="text-xs font-bold uppercase tracking-[0.16em] text-brand">
              Clinical access
            </p>
            <h2 className="mt-4 font-display text-2xl text-ink">Scoped by responsibility</h2>
            <p className="mt-3 text-sm leading-6 text-ink-muted">
              Organization membership does not automatically grant access to patient records.
              Clinical access requires the appropriate clinical capability and an active
              patient-clinician assignment.
            </p>
          </Card>
        </div>
      )}
    </div>
  );
}
