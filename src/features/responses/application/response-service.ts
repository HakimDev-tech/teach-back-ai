import { ResponseRepository } from "@/features/responses/infrastructure/response-repository";

export class ResponseService {
  constructor(private readonly responses: ResponseRepository) {}

  saveDraft(input: {
    sessionId: string;
    questionId: string;
    idempotencyKey: string;
    responseText: string;
    attemptNumber: number;
  }) {
    return this.responses.saveDraft(input);
  }

  submit(responseId: string) {
    return this.responses.submit(responseId);
  }
}
