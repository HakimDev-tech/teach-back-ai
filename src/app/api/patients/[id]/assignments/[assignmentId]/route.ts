import { NextResponse } from "next/server";
import { z } from "zod";
import { PatientRepository } from "@/features/patients/infrastructure/patient-repository";
import { PatientService } from "@/features/patients/application/patient-service";
import { apiRoute, requireAuthenticatedClient } from "@/lib/http/api";

const paramsSchema = z.object({ id: z.string().uuid(), assignmentId: z.string().uuid() });

export async function DELETE(_request: Request, context: { params: Promise<{ id: string; assignmentId: string }> }) {
  return apiRoute(async () => {
    const { supabase } = await requireAuthenticatedClient();
    const { assignmentId } = paramsSchema.parse(await context.params);
    await new PatientService(new PatientRepository(supabase)).revoke(assignmentId);
    return new NextResponse(null, { status: 204 });
  });
}
