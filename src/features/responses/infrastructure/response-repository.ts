import type { SupabaseClient } from "@supabase/supabase-js";

export class ResponseRepository {
  constructor(private readonly db: SupabaseClient) {}

  async saveDraft(input: {
    sessionId: string;
    questionId: string;
    idempotencyKey: string;
    responseText: string;
    attemptNumber: number;
  }) {
    const { data, error } = await this.db.rpc("save_response_draft", {
      target_session: input.sessionId,
      target_question: input.questionId,
      target_idempotency_key: input.idempotencyKey,
      response_content: input.responseText,
      target_attempt: input.attemptNumber,
    });
    if (error) throw error;
    return data;
  }

  async submit(responseId: string) {
    const { data, error } = await this.db.rpc("submit_response", {
      target_response: responseId,
    });
    if (error) throw error;
    return data;
  }
}
