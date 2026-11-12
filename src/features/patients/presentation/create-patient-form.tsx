"use client";

import { useRouter } from "next/navigation";
import { useState, type FormEvent } from "react";

import { Button } from "@/components/ui/button";
import { InputField } from "@/components/ui/input-field";
import { useI18n } from "@/i18n/provider";

type OrganizationOption = { id: string; name: string };

export function CreatePatientForm({
  organizations,
}: {
  organizations: OrganizationOption[];
}) {
  const router = useRouter();
  const { t } = useI18n();
  const [organizationId, setOrganizationId] = useState(organizations[0]?.id ?? "");
  const [fullName, setFullName] = useState("");
  const [preferredLanguage, setPreferredLanguage] = useState("en");
  const [pending, setPending] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    setSuccess(false);

    if (!organizationId || fullName.trim().length < 2) {
      setError(t("patients.validation"));
      return;
    }

    setPending(true);
    try {
      const response = await fetch("/api/patients", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          organizationId,
          fullName: fullName.trim(),
          preferredLanguage,
        }),
      });

      if (!response.ok) {
        setError(response.status === 403 ? t("patients.notAuthorized") : t("patients.createFailed"));
        return;
      }

      setFullName("");
      setSuccess(true);
      router.refresh();
    } catch {
      setError(t("patients.createFailed"));
    } finally {
      setPending(false);
    }
  }

  return (
    <form className="space-y-4" onSubmit={handleSubmit}>
      <div>
        <label className="mb-1.5 block text-sm font-semibold text-ink" htmlFor="patient-organization">
          {t("patients.organization")}
        </label>
        <select
          className="min-h-11 w-full rounded-xl border border-line bg-surface px-3.5 text-sm text-ink shadow-sm focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
          id="patient-organization"
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
        autoComplete="off"
        label={t("patients.fullName")}
        maxLength={160}
        onChange={(event) => setFullName(event.target.value)}
        required
        value={fullName}
      />

      <div>
        <label className="mb-1.5 block text-sm font-semibold text-ink" htmlFor="patient-language">
          {t("patients.preferredLanguage")}
        </label>
        <select
          className="min-h-11 w-full rounded-xl border border-line bg-surface px-3.5 text-sm text-ink shadow-sm focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
          id="patient-language"
          onChange={(event) => setPreferredLanguage(event.target.value)}
          value={preferredLanguage}
        >
          <option value="en">{t("patients.languageEnglish")}</option>
          <option value="fr">{t("patients.languageFrench")}</option>
          <option value="ar">{t("patients.languageArabic")}</option>
        </select>
      </div>

      {error ? <p className="text-sm text-danger" role="alert">{error}</p> : null}
      {success ? <p className="text-sm text-success" role="status">{t("patients.created")}</p> : null}

      <Button className="w-full sm:w-auto" disabled={pending || organizations.length === 0} type="submit">
        {pending ? t("patients.creating") : t("patients.create")}
      </Button>
    </form>
  );
}
