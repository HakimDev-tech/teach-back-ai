import { redirect } from "next/navigation";

import { Badge } from "@/components/ui/badge";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";
import { PageHeader } from "@/components/ui/page-header";
import { formatNumber } from "@/i18n/format";
import { getServerI18n } from "@/i18n/server";
import type { MessageKey } from "@/i18n/messages";
import { createClient } from "@/lib/supabase/server";

const roleMessageKeys: Record<string, MessageKey> = {
  owner: "role.owner",
  admin: "role.admin",
  clinician: "role.clinician",
};

export default async function ClinicianHomePage() {
  const [{ locale, t }, supabase] = await Promise.all([getServerI18n(), createClient()]);
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
        description={t("clinician.description")}
        eyebrow={t("clinician.workspaceEyebrow")}
        title={t("clinician.overview")}
      />

      {error ? (
        <Card>
          <Badge variant="warning">{t("clinician.accessUnavailable")}</Badge>
          <h2 className="mt-4 font-display text-xl text-ink">
            {t("clinician.loadFailedTitle")}
          </h2>
          <p className="mt-2 text-sm leading-6 text-ink-muted">
            {t("clinician.loadFailedDescription")}
          </p>
        </Card>
      ) : activeMemberships.length === 0 ? (
        <EmptyState
          description={t("clinician.organizationRequiredDescription")}
          title={t("clinician.organizationRequiredTitle")}
        />
      ) : (
        <div className="grid gap-5 lg:grid-cols-[minmax(0,1fr)_minmax(18rem,0.8fr)]">
          <Card>
            <p className="text-xs font-bold uppercase tracking-[0.16em] text-ink-muted">
              {t("clinician.organizationAccess")}
            </p>
            <p className="mt-4 font-display text-5xl tabular-nums text-ink">
              {formatNumber(activeMemberships.length, locale)}
            </p>
            <p className="mt-2 text-sm text-ink-muted">
              {activeMemberships.length === 1
                ? t("clinician.activeMembershipSingular")
                : t("clinician.activeMembershipPlural")}
            </p>
            <ul className="mt-6 space-y-3 border-t border-line pt-5">
              {activeMemberships.map((membership) => (
                <li className="flex items-center justify-between gap-3" key={membership.id}>
                  <span className="text-sm font-medium text-ink">
                    {t("clinician.organizationAccess")}
                  </span>
                  <Badge variant="neutral">
                    {roleMessageKeys[membership.role]
                      ? t(roleMessageKeys[membership.role])
                      : membership.role}
                  </Badge>
                </li>
              ))}
            </ul>
          </Card>
          <Card>
            <p className="text-xs font-bold uppercase tracking-[0.16em] text-brand">
              {t("clinician.clinicalAccess")}
            </p>
            <h2 className="mt-4 font-display text-2xl text-ink">
              {t("clinician.scopedResponsibility")}
            </h2>
            <p className="mt-3 text-sm leading-6 text-ink-muted">
              {t("clinician.clinicalAccessDescription")}
            </p>
          </Card>
        </div>
      )}
    </div>
  );
}
