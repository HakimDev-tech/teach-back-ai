import { describe, expect, it, vi } from "vitest";
import type { SupabaseClient } from "@supabase/supabase-js";

import { ClinicalCapabilityRepository } from "@/features/clinical-capabilities/infrastructure/clinical-capability-repository";

function createRepository(result: { data?: unknown; error: unknown }) {
  const rpc = vi.fn().mockResolvedValue(result);
  const supabase = { rpc } as unknown as SupabaseClient;
  return { repository: new ClinicalCapabilityRepository(supabase), rpc };
}

describe("ClinicalCapabilityRepository", () => {
  it("lists the organization review queue through the admin-only RPC", async () => {
    const request = { capability_id: "capability-id", status: "pending" };
    const { repository, rpc } = createRepository({ data: [request], error: null });

    await expect(repository.listForOrganization("org-id")).resolves.toEqual([request]);
    expect(rpc).toHaveBeenCalledWith("list_clinical_capability_requests", {
      target_org: "org-id",
    });
  });

  it("requests a capability through the atomic RPC", async () => {
    const { repository, rpc } = createRepository({ data: "capability-id", error: null });

    await expect(repository.request("org-id", "physician")).resolves.toBe("capability-id");
    expect(rpc).toHaveBeenCalledWith("request_clinical_capability", {
      target_org: "org-id",
      target_professional_type: "physician",
    });
  });

  it("approves only through the manual-review RPC contract", async () => {
    const { repository, rpc } = createRepository({ data: null, error: null });

    await repository.approve("capability-id", "2027-01-01T00:00:00.000Z");
    expect(rpc).toHaveBeenCalledWith("approve_clinical_capability", {
      target_capability: "capability-id",
      target_verification_method: "manual_review",
      target_expires_at: "2027-01-01T00:00:00.000Z",
    });
  });

  it("rejects with a recorded reason", async () => {
    const { repository, rpc } = createRepository({ data: null, error: null });

    await repository.reject("capability-id", "Evidence could not be verified");
    expect(rpc).toHaveBeenCalledWith("reject_clinical_capability", {
      target_capability: "capability-id",
      target_reason: "Evidence could not be verified",
    });
  });

  it("suspends with an optional reason", async () => {
    const { repository, rpc } = createRepository({ data: null, error: null });

    await repository.suspend("capability-id", null);
    expect(rpc).toHaveBeenCalledWith("suspend_clinical_capability", {
      target_capability: "capability-id",
      target_reason: null,
    });
  });

  it("revokes with a recorded reason", async () => {
    const { repository, rpc } = createRepository({ data: null, error: null });

    await repository.revoke("capability-id", "Access no longer required");
    expect(rpc).toHaveBeenCalledWith("revoke_clinical_capability", {
      target_capability: "capability-id",
      target_reason: "Access no longer required",
    });
  });

  it("propagates database errors without converting them into success", async () => {
    const error = { code: "42501", message: "forbidden" };
    const { repository } = createRepository({ data: null, error });

    await expect(repository.approve("capability-id", null)).rejects.toBe(error);
  });
});
