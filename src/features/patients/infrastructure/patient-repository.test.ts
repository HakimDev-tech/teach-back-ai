import { describe, expect, it, vi } from "vitest";
import { PatientRepository } from "./patient-repository";

function createQueryBuilder(result: unknown) {
  const builder = {
    select: vi.fn(),
    eq: vi.fn(),
    order: vi.fn(),
    maybeSingle: vi.fn(),
  };
  builder.select.mockReturnValue(builder);
  builder.eq.mockReturnValue(builder);
  builder.order.mockResolvedValue(result);
  builder.maybeSingle.mockResolvedValue(result);
  return builder;
}

describe("PatientRepository", () => {
  it("scopes patient listing to the requested organization", async () => {
    const rows = [{ id: "patient-1", organization_id: "org-a" }];
    const query = createQueryBuilder({ data: rows, error: null });
    const db = {
      from: vi.fn().mockReturnValue(query),
    };
    const repository = new PatientRepository(db as never);

    await expect(repository.list("org-a")).resolves.toEqual(rows);
    expect(db.from).toHaveBeenCalledWith("patients");
    expect(query.select).toHaveBeenCalledWith(
      "id,organization_id,full_name,preferred_language,status,created_at,updated_at",
    );
    expect(query.eq).toHaveBeenCalledWith("organization_id", "org-a");
    expect(query.order).toHaveBeenCalledWith("created_at", {
      ascending: false,
    });
  });

  it("scopes single-patient lookup by both organization and patient identifiers", async () => {
    const patient = { id: "patient-1", organization_id: "org-a" };
    const query = createQueryBuilder({ data: patient, error: null });
    const db = { from: vi.fn().mockReturnValue(query) };
    const repository = new PatientRepository(db as never);

    await expect(repository.get("org-a", "patient-1")).resolves.toEqual(
      patient,
    );
    expect(query.eq).toHaveBeenNthCalledWith(1, "organization_id", "org-a");
    expect(query.eq).toHaveBeenNthCalledWith(2, "id", "patient-1");
    expect(query.maybeSingle).toHaveBeenCalledOnce();
  });

  it("creates a patient through the atomic database RPC", async () => {
    const db = {
      rpc: vi.fn().mockResolvedValue({ data: "patient-1", error: null }),
    };
    const repository = new PatientRepository(db as never);

    await expect(
      repository.create({
        organizationId: "org-a",
        fullName: "Synthetic Patient",
        preferredLanguage: "fr",
      }),
    ).resolves.toBe("patient-1");

    expect(db.rpc).toHaveBeenCalledWith("create_patient", {
      target_org: "org-a",
      patient_name: "Synthetic Patient",
      patient_language: "fr",
    });
  });

  it("propagates database errors instead of returning partial patient data", async () => {
    const databaseError = { code: "42501", message: "forbidden" };
    const db = {
      rpc: vi.fn().mockResolvedValue({ data: null, error: databaseError }),
    };
    const repository = new PatientRepository(db as never);

    await expect(
      repository.create({
        organizationId: "org-a",
        fullName: "Synthetic Patient",
        preferredLanguage: null,
      }),
    ).rejects.toBe(databaseError);
  });
});
