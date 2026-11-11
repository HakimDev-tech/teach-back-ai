import type { SupabaseClient } from "@supabase/supabase-js";

export class InstructionRepository {
  constructor(private readonly db: SupabaseClient) {}

  async createCarePlan(input: { organizationId: string; patientId: string; title: string; userId: string }) {
    const { data, error } = await this.db
      .from("care_plans")
      .insert({
        organization_id: input.organizationId,
        patient_id: input.patientId,
        title: input.title,
        created_by: input.userId,
      })
      .select("id")
      .single();
    if (error) throw error;
    return data.id;
  }

  async createInstructionItem(organizationId: string, carePlanId: string) {
    const { data, error } = await this.db
      .from("instruction_items")
      .insert({ organization_id: organizationId, care_plan_id: carePlanId })
      .select("id")
      .single();
    if (error) throw error;
    return data.id;
  }

  async createVersion(instructionItemId: string, content: string) {
    const { data, error } = await this.db.rpc("create_instruction_version", {
      target_item: instructionItemId,
      instruction_content: content,
    });
    if (error) throw error;
    return data;
  }

  async approveVersion(versionId: string) {
    const { error } = await this.db.rpc("approve_instruction_version", {
      target_version: versionId,
    });
    if (error) throw error;
  }
}
