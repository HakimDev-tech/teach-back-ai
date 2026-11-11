import type { SupabaseClient } from "@supabase/supabase-js";

export class SessionRepository {
  constructor(private readonly db: SupabaseClient) {}

  async create(input: { organizationId: string; patientId: string; carePlanId: string | null; userId: string; expiresAt: string | null }) {
    const { data, error } = await this.db
      .from("teachback_sessions")
      .insert({
        organization_id: input.organizationId,
        patient_id: input.patientId,
        care_plan_id: input.carePlanId,
        created_by: input.userId,
        expires_at: input.expiresAt,
      })
      .select("id,organization_id,patient_id,status,version,created_at")
      .single();
    if (error) throw error;
    return data;
  }

  async addQuestion(input: {
    organizationId: string;
    sessionId: string;
    instructionItemId: string;
    instructionVersionId: string;
    questionText: string;
    position: number;
    userId: string;
  }) {
    const { data, error } = await this.db
      .from("questions")
      .insert({
        organization_id: input.organizationId,
        session_id: input.sessionId,
        instruction_item_id: input.instructionItemId,
        instruction_version_id: input.instructionVersionId,
        question_text: input.questionText,
        position: input.position,
        created_by: input.userId,
      })
      .select("id,session_id,position,status,question_text")
      .single();
    if (error) throw error;
    return data;
  }

  async updateQuestion(questionId: string, input: { questionText: string; position: number }) {
    const { data, error } = await this.db
      .from("questions")
      .update({ question_text: input.questionText, position: input.position })
      .eq("id", questionId)
      .eq("status", "draft")
      .select("id,session_id,position,status,question_text")
      .single();
    if (error) throw error;
    return data;
  }

  async approveQuestion(questionId: string) {
    const { error } = await this.db.rpc("approve_question", { target_question: questionId });
    if (error) throw error;
  }

  async transition(sessionId: string, expectedVersion: number, targetStatus: string) {
    const { data, error } = await this.db.rpc("transition_session", {
      target_session: sessionId,
      expected_version: expectedVersion,
      target_status: targetStatus,
    });
    if (error) throw error;
    return data;
  }
  async addInstructionSnapshot(input: {
    organizationId: string;
    sessionId: string;
    instructionItemId: string;
    instructionVersionId: string;
  }) {
    const { data, error } = await this.db
      .from("session_instructions")
      .insert({
        organization_id: input.organizationId,
        session_id: input.sessionId,
        instruction_item_id: input.instructionItemId,
        instruction_version_id: input.instructionVersionId,
      })
      .select("id,session_id,instruction_item_id,instruction_version_id,created_at")
      .single();
    if (error) throw error;
    return data;
  }

}
