import { redirect } from "next/navigation";

import { Badge } from "@/components/ui/badge";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";
import { PageHeader } from "@/components/ui/page-header";
import { RequestClinicalCapabilityForm } from "@/features/clinical-capabilities/presentation/request-clinical-capability-form";
import { formatDate } from "@/i18n/format";
import { getServerI18n } from "@/i18n/server";
import { createClient } from "@/lib/supabase/server";

type CapabilityStatus = "active" | "pending" | "suspended" | "revoked" | "expired" | "not_requested";

export default async function ClinicianAccessPage() {
  const [{ locale, t }, supabase] = await Promise.all([getServerI18n(), createClient()]);
  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser();

  if (authError || !user) redirect("/sign-in");

  const [membershipsResult, capabilitiesResult] = await Promise.all([
    supabase
      .from("organization_memberships")
      .select("organization_id,role")
      .eq("user_id", user.id)
      .eq("status", "active"),
    supabase
      .from("organization_clinical_capabilities")
      .select("id,organization_id,professional_type,status,verification_status,expires_at,created_at")
      .eq("user_id", user.id)
      .order("created_at", { ascending: false }),
  ]);

  if (membershipsResult.error || capabilitiesResult.error) {
    return (
      <Card>
        <Badge variant="warning">{t("clinicalAccess.unavailable")}</Badge>
        <p className="mt-3 text-sm text-ink-muted">{t("clinicalAccess.loadFailed")}</p>
      </Card>
    );
  }

  const memberships = membershipsResult.data ?? [];
  const organizationIds = [...new Set(memberships.map((membership) => membership.organization_id))];

  if (organizationIds.length === 0) {
    return (
      <div className="space-y-8">
        <PageHeader
          description={t("clinicalAccess.description")}
          eyebrow={t("clinician.workspaceEyebrow")}
          title={t("clinicalAccess.title")}
        />
        <EmptyState
          description={t("clinicalAccess.noMembership")}
          title={t("clinicalAccess.noMembershipTitle")}
        />
      </div>
    );
  }

  const { data: organizations, error: organizationsError } = await supabase
    .from("organizations")
    .select("id,name")
    .in("id", organizationIds)
    .order("name");

  if (organizationsError) {
    return (
      <Card>
        <Badge variant="warning">{t("clinicalAccess.unavailable")}</Badge>
        <p className="mt-3 text-sm text-ink-muted">{t("clinicalAccess.loadFailed")}</p>
      </Card>
    );
  }

  const now = Date.now();
  const latestCapabilityByOrganization = new Map(
    (capabilitiesResult.data ?? []).map((capability) => [capability.organization_id, capability]),
  );
  const organizationStatuses = (organizations ?? []).map((organization) => {
    const capability = latestCapabilityByOrganization.get(organization.id);
    let status: CapabilityStatus = "not_requested";

    if (capability?.status === "active") {
      status =
        capability.expires_at && Date.parse(capability.expires_at) <= now ? "expired" : "active";
    } else if (
      capability?.status === "pending" ||
      capability?.status === "suspended" ||
      capability?.status === "revoked"
    ) {
      status = capability.status;
    }

    return { ...organization, capability, status };
  });

  const requestableOrganizations = organizationStatuses
    .filter(({ status }) => status === "not_requested" || status === "revoked" || status === "expired")
    .map(({ id, name, capability }) => ({
      id,
      name,
      professionalType: capability?.professional_type ?? "",
    }));

  const statusLabels: Record<CapabilityStatus, string> = {
    active: t("clinicalAccess.statusActive"),
    pending: t("clinicalAccess.statusPending"),
    suspended: t("clinicalAccess.statusSuspended"),
    revoked: t("clinicalAccess.statusRevoked"),
    expired: t("clinicalAccess.statusExpired"),
    not_requested: t("clinicalAccess.statusNotRequested"),
  };
  const statusVariants: Record<CapabilityStatus, "success" | "warning" | "danger" | "neutral"> = {
    active: "success",
    pending: "warning",
    suspended: "danger",
    revoked: "neutral",
    expired: "warning",
    not_requested: "neutral",
  };

  return (
    <div className="space-y-8">
      <PageHeader
        description={t("clinicalAccess.description")}
        eyebrow={t("clinician.workspaceEyebrow")}
        title={t("clinicalAccess.title")}
      />

      <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_minmax(19rem,0.8fr)]">
        <Card>
          <p className="text-xs font-bold uppercase tracking-[0.16em] text-brand">
            {t("clinicalAccess.statusEyebrow")}
          </p>
          <h2 className="mt-2 font-display text-2xl text-ink">{t("clinicalAccess.statusTitle")}</h2>
          <ul className="mt-5 space-y-3">
            {organizationStatuses.map((organization) => (
              <li
                className="flex flex-col gap-2 rounded-xl border border-line bg-canvas p-4 sm:flex-row sm:items-center sm:justify-between"
                key={organization.id}
              >
                <div>
                  <p className="text-sm font-semibold text-ink">{organization.name}</p>
                  <p className="mt-1 text-xs text-ink-muted">
                    {organization.capability
                      ? t("clinicalAccess.requestedOn", {
                          date: formatDate(organization.capability.created_at, locale),
                        })
                      : t("clinicalAccess.noRequestYet")}
                  </p>
                </div>
                <Badge variant={statusVariants[organization.status]}>
                  {statusLabels[organization.status]}
                </Badge>
              </li>
            ))}
          </ul>
        </Card>

        <Card>
          <p className="text-xs font-bold uppercase tracking-[0.16em] text-brand">
            {t("clinicalAccess.requestEyebrow")}
          </p>
          <h2 className="mt-2 font-display text-2xl text-ink">{t("clinicalAccess.requestTitle")}</h2>
          <p className="mb-5 mt-2 text-sm leading-6 text-ink-muted">
            {t("clinicalAccess.requestDescription")}
          </p>
          {requestableOrganizations.length > 0 ? (
            <RequestClinicalCapabilityForm organizations={requestableOrganizations} />
          ) : (
            <p className="rounded-xl bg-surface-muted p-4 text-sm leading-6 text-ink-muted">
              {t("clinicalAccess.noRequestAvailable")}
            </p>
          )}
          <p className="mt-5 border-t border-line pt-4 text-xs leading-5 text-ink-muted">
            {t("clinicalAccess.manualReviewDisclaimer")}
          </p>
        </Card>
      </div>
    </div>
  );
}
