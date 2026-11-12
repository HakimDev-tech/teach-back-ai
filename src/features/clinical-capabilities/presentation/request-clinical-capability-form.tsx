"use client";

import { useRouter } from "next/navigation";
import { useState, type FormEvent } from "react";

import { Button } from "@/components/ui/button";
import { InputField } from "@/components/ui/input-field";
import { useI18n } from "@/i18n/provider";

type OrganizationOption = {
  id: string;
  name: string;
  professionalType?: string;
};

export function RequestClinicalCapabilityForm({
  organizations,
}: {
  organizations: OrganizationOption[];
}) {
  const router = useRouter();
  const { t } = useI18n();
  const [organizationId, setOrganizationId] = useState(organizations[0]?.id ?? "");
  const [professionalType, setProfessionalType] = useState(
    organizations[0]?.professionalType ?? "",
  );
  const [pending, setPending] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    setSuccess(false);

    if (!organizationId || professionalType.trim().length < 2) {
      setError(t("clinicalAccess.validation"));
      return;
    }

    setPending(true);
    try {
      const response = await fetch("/api/clinical-capabilities", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          organizationId,
          professionalType: professionalType.trim(),
        }),
      });

      if (!response.ok) {
        setError(t("clinicalAccess.requestFailed"));
        return;
      }

      setSuccess(true);
      router.refresh();
    } catch {
      setError(t("clinicalAccess.requestFailed"));
    } finally {
      setPending(false);
    }
  }

  return (
    <form className="space-y-4" onSubmit={handleSubmit}>
      <div>
        <label className="mb-1.5 block text-sm font-semibold text-ink" htmlFor="capability-organization">
          {t("clinicalAccess.organization")}
        </label>
        <select
          className="min-h-11 w-full rounded-xl border border-line bg-surface px-3.5 text-sm text-ink shadow-sm focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
          id="capability-organization"
          onChange={(event) => setOrganizationId(event.target.value)}
          required
          value={organizationId}
        >
          {organizations.map((organization) => (
            <option key={organization.id} value={organization.id}>
              {organization.name}
            </option>
          ))}
        </select>
      </div>

      <InputField
        autoComplete="organization-title"
        hint={t("clinicalAccess.professionalTypeHint")}
        label={t("clinicalAccess.professionalType")}
        maxLength={80}
        onChange={(event) => setProfessionalType(event.target.value)}
        placeholder={t("clinicalAccess.professionalTypePlaceholder")}
        required
        value={professionalType}
      />

      {error ? <p className="text-sm text-danger" role="alert">{error}</p> : null}
      {success ? <p className="text-sm text-success" role="status">{t("clinicalAccess.requestSuccess")}</p> : null}

      <Button className="w-full sm:w-auto" disabled={pending || organizations.length === 0} type="submit">
        {pending ? t("clinicalAccess.requesting") : t("clinicalAccess.request")}
      </Button>
    </form>
  );
}
