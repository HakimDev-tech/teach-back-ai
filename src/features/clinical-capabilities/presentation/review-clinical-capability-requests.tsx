"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { InputField } from "@/components/ui/input-field";
import { useI18n } from "@/i18n/provider";

export type ClinicalCapabilityReviewRequest = {
  capabilityId: string;
  userId: string;
  displayName: string;
  professionalType: string;
  organizationName: string;
  requestedAt: string;
};

export function ReviewClinicalCapabilityRequests({
  currentUserId,
  requests,
}: {
  currentUserId: string;
  requests: ClinicalCapabilityReviewRequest[];
}) {
  const router = useRouter();
  const { t } = useI18n();
  const [reasons, setReasons] = useState<Record<string, string>>({});
  const [busyId, setBusyId] = useState<string | null>(null);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");

  async function review(capabilityId: string, action: "approve" | "reject") {
    setError("");
    setSuccess("");
    const reason = reasons[capabilityId]?.trim() ?? "";

    if (action === "reject" && reason.length < 2) {
      setError(t("clinicalAccess.rejectionReasonRequired"));
      return;
    }

    setBusyId(capabilityId);
    try {
      const response = await fetch(
        `/api/clinical-capabilities/${capabilityId}/${action}`,
        {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify(action === "reject" ? { reason } : {}),
        },
      );

      if (!response.ok) {
        setError(t("clinicalAccess.reviewFailed"));
        return;
      }

      setSuccess(
        action === "approve"
          ? t("clinicalAccess.reviewApproved")
          : t("clinicalAccess.reviewRejected"),
      );
      router.refresh();
    } catch {
      setError(t("clinicalAccess.reviewFailed"));
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div className="space-y-4">
      {error ? <p className="text-sm text-danger" role="alert">{error}</p> : null}
      {success ? <p className="text-sm text-success" role="status">{success}</p> : null}

      <ul className="space-y-3">
        {requests.map((request) => {
          const isOwnRequest = request.userId === currentUserId;
          const isBusy = busyId === request.capabilityId;

          return (
            <li className="rounded-xl border border-line bg-canvas p-4" key={request.capabilityId}>
              <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                <div className="min-w-0">
                  <p className="text-sm font-semibold text-ink">{request.displayName}</p>
                  <p className="mt-1 text-xs text-ink-muted">
                    {request.professionalType} · {request.organizationName}
                  </p>
                  <p className="mt-1 text-xs tabular-nums text-ink-muted">
                    {t("clinicalAccess.requestedOn")} {request.requestedAt}
                  </p>
                </div>
                <Badge variant="warning">{t("clinicalAccess.statusPending")}</Badge>
              </div>

              {isOwnRequest ? (
                <p className="mt-4 rounded-lg bg-surface-muted px-3 py-2 text-xs leading-5 text-warning">
                  {t("clinicalAccess.selfApprovalBlocked")}
                </p>
              ) : (
                <div className="mt-4 grid gap-3 sm:grid-cols-[minmax(0,1fr)_auto_auto] sm:items-end">
                  <InputField
                    label={t("clinicalAccess.rejectionReason")}
                    maxLength={500}
                    onChange={(event) =>
                      setReasons((current) => ({
                        ...current,
                        [request.capabilityId]: event.target.value,
                      }))
                    }
                    placeholder={t("clinicalAccess.rejectionReasonPlaceholder")}
                    value={reasons[request.capabilityId] ?? ""}
                  />
                  <Button
                    disabled={isBusy}
                    onClick={() => review(request.capabilityId, "approve")}
                    type="button"
                  >
                    {t("clinicalAccess.approve")}
                  </Button>
                  <Button
                    disabled={isBusy || (reasons[request.capabilityId]?.trim().length ?? 0) < 2}
                    onClick={() => review(request.capabilityId, "reject")}
                    type="button"
                    variant="danger"
                  >
                    {t("clinicalAccess.reject")}
                  </Button>
                </div>
              )}
            </li>
          );
        })}
      </ul>
    </div>
  );
}
