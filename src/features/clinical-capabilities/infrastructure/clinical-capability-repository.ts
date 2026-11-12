import type { SupabaseClient } from "@supabase/supabase-js";

export class ClinicalCapabilityRepository {
  constructor(private readonly supabase: SupabaseClient) {}

  async request(organizationId: string, professionalType: string): Promise<string> {
    const { data, error } = await this.supabase.rpc("request_clinical_capability", {
      target_org: organizationId,
      target_professional_type: professionalType,
    });
    if (error) throw error;
    return data;
  }

  async approve(capabilityId: string, expiresAt: string | null): Promise<void> {
    const { error } = await this.supabase.rpc("approve_clinical_capability", {
      target_capability: capabilityId,
      target_verification_method: "manual_review",
      target_expires_at: expiresAt,
    });
    if (error) throw error;
  }

  async reject(capabilityId: string, reason: string): Promise<void> {
    const { error } = await this.supabase.rpc("reject_clinical_capability", {
      target_capability: capabilityId,
      target_reason: reason,
    });
    if (error) throw error;
  }

  async suspend(capabilityId: string, reason: string | null): Promise<void> {
    const { error } = await this.supabase.rpc("suspend_clinical_capability", {
      target_capability: capabilityId,
      target_reason: reason,
    });
    if (error) throw error;
  }

  async revoke(capabilityId: string, reason: string | null): Promise<void> {
    const { error } = await this.supabase.rpc("revoke_clinical_capability", {
      target_capability: capabilityId,
      target_reason: reason,
    });
    if (error) throw error;
  }
}
