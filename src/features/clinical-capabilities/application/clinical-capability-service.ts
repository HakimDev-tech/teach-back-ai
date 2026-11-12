import { ClinicalCapabilityRepository } from "@/features/clinical-capabilities/infrastructure/clinical-capability-repository";

export class ClinicalCapabilityService {
  constructor(private readonly repository: ClinicalCapabilityRepository) {}

  listForOrganization(organizationId: string) {
    return this.repository.listForOrganization(organizationId);
  }

  request(input: { organizationId: string; professionalType: string }) {
    return this.repository.request(input.organizationId, input.professionalType);
  }

  approve(capabilityId: string, expiresAt: string | null) {
    return this.repository.approve(capabilityId, expiresAt);
  }

  reject(capabilityId: string, reason: string) {
    return this.repository.reject(capabilityId, reason);
  }

  suspend(capabilityId: string, reason: string | null) {
    return this.repository.suspend(capabilityId, reason);
  }

  revoke(capabilityId: string, reason: string | null) {
    return this.repository.revoke(capabilityId, reason);
  }
}
