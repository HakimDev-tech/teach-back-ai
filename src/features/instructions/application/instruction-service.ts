import { InstructionRepository } from "@/features/instructions/infrastructure/instruction-repository";

export class InstructionService {
  constructor(private readonly instructions: InstructionRepository) {}

  createCarePlan(input: { organizationId: string; patientId: string; title: string; userId: string }) {
    return this.instructions.createCarePlan(input);
  }

  createInstructionItem(organizationId: string, carePlanId: string) {
    return this.instructions.createInstructionItem(organizationId, carePlanId);
  }

  createVersion(instructionItemId: string, content: string) {
    return this.instructions.createVersion(instructionItemId, content);
  }

  approveVersion(versionId: string) {
    return this.instructions.approveVersion(versionId);
  }
}
