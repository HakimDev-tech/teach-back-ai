import { PatientRepository } from "@/features/patients/infrastructure/patient-repository";

export class PatientService {
  constructor(private readonly patients: PatientRepository) {}

  list(organizationId: string) {
    return this.patients.list(organizationId);
  }

  get(organizationId: string, patientId: string) {
    return this.patients.get(organizationId, patientId);
  }

  create(input: { organizationId: string; fullName: string; preferredLanguage: string | null }) {
    return this.patients.create(input);
  }

  assign(input: { organizationId: string; patientId: string; clinicianUserId: string }) {
    return this.patients.assign(input);
  }

  revoke(assignmentId: string, patientId: string) {
    return this.patients.revoke(assignmentId, patientId);
  }
}
