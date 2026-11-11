import { SessionRepository } from "@/features/sessions/infrastructure/session-repository";

export class SessionService {
  constructor(private readonly sessions: SessionRepository) {}

  create(input: { organizationId: string; patientId: string; carePlanId: string | null; userId: string; expiresAt: string | null }) {
    return this.sessions.create(input);
  }

  addQuestion(input: {
    organizationId: string;
    sessionId: string;
    instructionItemId: string;
    instructionVersionId: string;
    questionText: string;
    position: number;
    userId: string;
  }) {
    return this.sessions.addQuestion(input);
  }

  updateQuestion(questionId: string, input: { questionText: string; position: number }) {
    return this.sessions.updateQuestion(questionId, input);
  }

  approveQuestion(questionId: string) {
    return this.sessions.approveQuestion(questionId);
  }

  transition(sessionId: string, expectedVersion: number, targetStatus: string) {
    return this.sessions.transition(sessionId, expectedVersion, targetStatus);
  }
  addInstructionSnapshot(input: {
    organizationId: string;
    sessionId: string;
    instructionItemId: string;
    instructionVersionId: string;
  }) {
    return this.sessions.addInstructionSnapshot(input);
  }

}
