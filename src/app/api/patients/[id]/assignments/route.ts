import { NextResponse } from "next/server";
import { z } from "zod";
import { PatientRepository } from "@/features/patients/infrastructure/patient-repository";
import { PatientService } from "@/features/patients/application/patient-service";
import { apiRoute, readJsonBody, requireAuthenticatedClient } from "@/lib/http/api";

const paramsSchema = z.object({ id: z.string().uuid() });
const bodySchema = z.object({
  organizationId: z.string().uuid(),
  clinicianUserId: z.string().uuid(),
});

export async function POST(request: Request, context: { params: Promise<{ id: string }> }) {
  return apiRoute(async () => {
    const { supabase } = await requireAuthenticatedClient();
    const { id } = paramsSchema.parse(await context.params);
    const body = bodySchema.parse(await readJsonBody(request));
    const assignmentId = await new PatientService(new PatientRepository(supabase)).assign({
      organizationId: body.organizationId,
      patientId: id,
      clinicianUserId: body.clinicianUserId,
    });
    return NextResponse.json({ data: { assignmentId } }, { status: 201 });
  });
}
