import { redirect } from "next/navigation";

import { Badge } from "@/components/ui/badge";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";
import { PageHeader } from "@/components/ui/page-header";
import { CreatePatientForm } from "@/features/patients/presentation/create-patient-form";
import { formatDate } from "@/i18n/format";
import { getServerI18n } from "@/i18n/server";
import { createClient } from "@/lib/supabase/server";

export default async function ClinicianPatientsPage() {
  const [{ locale, t }, supabase] = await Promise.all([getServerI18n(), createClient()]);
  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser();

  if (authError || !user) redirect("/sign-in");

  const { data: capabilities, error: capabilityError } = await supabase
    .from("organization_clinical_capabilities")
    .select("organization_id")
    .eq("user_id", user.id)
    .eq("status", "active")
    .eq("verification_status", "verified")
    .or(`expires_at.is.null,expires_at.gt.${new Date().toISOString()}`);

  if (capabilityError) {
    return (
      <Card>
        <Badge variant="warning">{t("patients.unavailable")}</Badge>
        <p className="mt-3 text-sm text-ink-muted">{t("patients.loadFailed")}</p>
      </Card>
    );
  }

  const organizationIds = [
    ...new Set((capabilities ?? []).map((capability) => capability.organization_id)),
  ];

  if (organizationIds.length === 0) {
    return (
      <div className="space-y-8">
        <PageHeader description={t("patients.description")} eyebrow={t("clinician.workspaceEyebrow")} title={t("patients.title")} />
        <EmptyState description={t("patients.noClinicalMembership")} title={t("patients.emptyTitle")} />
      </div>
    );
  }

  const [organizationsResult, patientsResult] = await Promise.all([
    supabase.from("organizations").select("id,name").in("id", organizationIds).order("name"),
    supabase
      .from("patients")
      .select("id,organization_id,full_name,preferred_language,status,created_at")
      .in("organization_id", organizationIds)
      .order("created_at", { ascending: false })
      .limit(100),
  ]);

  if (organizationsResult.error || patientsResult.error) {
    return (
      <Card>
        <Badge variant="warning">{t("patients.unavailable")}</Badge>
        <p className="mt-3 text-sm text-ink-muted">{t("patients.loadFailed")}</p>
      </Card>
    );
  }

  const organizations = organizationsResult.data ?? [];
  const patients = patientsResult.data ?? [];

  return (
    <div className="space-y-8">
      <PageHeader
        description={t("patients.description")}
        eyebrow={t("clinician.workspaceEyebrow")}
        title={t("patients.title")}
      />

      <div className="grid gap-6 xl:grid-cols-[minmax(0,1.35fr)_minmax(19rem,0.65fr)]">
        <section aria-labelledby="patient-list-heading" className="min-w-0">
          <div className="mb-4 flex items-end justify-between gap-4">
            <div>
              <p className="text-xs font-bold uppercase tracking-[0.16em] text-brand">{t("patients.directoryEyebrow")}</p>
              <h2 className="mt-2 font-display text-2xl text-ink" id="patient-list-heading">{t("patients.directoryTitle")}</h2>
            </div>
            <span className="text-sm tabular-nums text-ink-muted">{patients.length}</span>
          </div>

          {patients.length === 0 ? (
            <EmptyState description={t("patients.emptyDescription")} title={t("patients.emptyTitle")} />
          ) : (
            <div className="overflow-hidden rounded-2xl border border-line bg-surface shadow-[0_8px_28px_rgba(32,52,45,0.04)]">
              <ul className="space-y-3 p-4 sm:hidden">
                {patients.map((patient) => {
                  const organization = organizations.find((item) => item.id === patient.organization_id);
                  const languageKey =
                    patient.preferred_language === "fr"
                      ? "patients.languageFrench"
                      : patient.preferred_language === "ar"
                        ? "patients.languageArabic"
                        : "patients.languageEnglish";

                  return (
                    <li className="rounded-xl border border-line bg-canvas p-4" key={patient.id}>
                      <div className="flex items-start justify-between gap-3">
                        <p className="text-sm font-semibold text-ink">{patient.full_name}</p>
                        <Badge variant={patient.status === "active" ? "success" : "neutral"}>
                          {patient.status === "active" ? t("patients.statusActive") : t("patients.statusArchived")}
                        </Badge>
                      </div>
                      <dl className="mt-3 grid grid-cols-2 gap-x-3 gap-y-2 text-xs">
                        <div>
                          <dt className="text-ink-muted">{t("patients.organization")}</dt>
                          <dd className="mt-0.5 font-medium text-ink">{organization?.name ?? "—"}</dd>
                        </div>
                        <div>
                          <dt className="text-ink-muted">{t("patients.preferredLanguage")}</dt>
                          <dd className="mt-0.5 font-medium text-ink">{t(languageKey)}</dd>
                        </div>
                        <div className="col-span-2">
                          <dt className="text-ink-muted">{t("patients.createdAt")}</dt>
                          <dd className="mt-0.5 font-medium tabular-nums text-ink">{formatDate(patient.created_at, locale)}</dd>
                        </div>
                      </dl>
                    </li>
                  );
                })}
              </ul>
              <div className="hidden overflow-x-auto sm:block">
                <table className="w-full min-w-[38rem] border-collapse text-start">
                  <thead className="bg-surface-muted text-xs font-semibold text-ink-muted">
                    <tr>
                      <th className="px-5 py-3 text-start">{t("patients.fullName")}</th>
                      <th className="px-5 py-3 text-start">{t("patients.organization")}</th>
                      <th className="px-5 py-3 text-start">{t("patients.preferredLanguage")}</th>
                      <th className="px-5 py-3 text-start">{t("patients.createdAt")}</th>
                      <th className="px-5 py-3 text-start">{t("patients.status")}</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-line">
                    {patients.map((patient) => {
                      const organization = organizations.find((item) => item.id === patient.organization_id);
                      const languageKey =
                        patient.preferred_language === "fr"
                          ? "patients.languageFrench"
                          : patient.preferred_language === "ar"
                            ? "patients.languageArabic"
                            : "patients.languageEnglish";

                      return (
                        <tr key={patient.id}>
                          <th className="px-5 py-4 text-start text-sm font-semibold text-ink">{patient.full_name}</th>
                          <td className="px-5 py-4 text-sm text-ink-muted">{organization?.name ?? "—"}</td>
                          <td className="px-5 py-4 text-sm text-ink-muted">{t(languageKey)}</td>
                          <td className="px-5 py-4 text-sm tabular-nums text-ink-muted">{formatDate(patient.created_at, locale)}</td>
                          <td className="px-5 py-4">
                            <Badge variant={patient.status === "active" ? "success" : "neutral"}>
                              {patient.status === "active" ? t("patients.statusActive") : t("patients.statusArchived")}
                            </Badge>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
              <p className="border-t border-line px-5 py-3 text-xs text-ink-muted">{t("patients.listLimit")}</p>
            </div>
          )}
        </section>

        <Card>
          <p className="text-xs font-bold uppercase tracking-[0.16em] text-brand">{t("patients.createEyebrow")}</p>
          <h2 className="mt-2 font-display text-2xl text-ink">{t("patients.createTitle")}</h2>
          <p className="mb-5 mt-2 text-sm leading-6 text-ink-muted">{t("patients.createDescription")}</p>
          <CreatePatientForm organizations={organizations} />
        </Card>
      </div>
    </div>
  );
}
