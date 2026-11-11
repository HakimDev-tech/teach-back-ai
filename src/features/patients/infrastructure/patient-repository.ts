import type { SupabaseClient } from "@supabase/supabase-js";

export class PatientRepository {
  constructor(private readonly db: SupabaseClient) {}

  async list(organizationId: string) {
    const { data, error } = await this.db
      .from("patients")
      .select("id,organization_id,full_name,preferred_language,status,created_at,updated_at")
      .eq("organization_id", organizationId)
      .order("created_at", { ascending: false });
    if (error) throw error;
    return data ?? [];
  }

  async get(organizationId: string, patientId: string) {
    const { data, error } = await this.db
      .from("patients")
      .select("id,organization_id,full_name,preferred_language,status,created_at,updated_at")
      .eq("organization_id", organizationId)
      .eq("id", patientId)
      .maybeSingle();
    if (error) throw error;
    return data;
  }

  async create(input: { organizationId: string; fullName: string; preferredLanguage: string | null }) {
    const { data, error } = await this.db.rpc("create_patient", {
      target_org: input.organizationId,
      patient_name: input.fullName,
      patient_language: input.preferredLanguage,
    });
    if (error) throw error;
    return data;
  }

  async assign(input: { organizationId: string; patientId: string; clinicianUserId: string }) {
    const { data, error } = await this.db.rpc("assign_patient_clinician", {
      target_org: input.organizationId,
      target_patient: input.patientId,
      target_clinician: input.clinicianUserId,
    });
    if (error) throw error;
    return data;
  }

  async revoke(assignmentId: string) {
    const { error } = await this.db.rpc("revoke_patient_assignment", {
      target_assignment: assignmentId,
    });
    if (error) throw error;
  }
}
