import { NextResponse } from "next/server";
import { z } from "zod";
import { PatientRepository } from "@/features/patients/infrastructure/patient-repository";
import { PatientService } from "@/features/patients/application/patient-service";
import { ApiError, apiRoute, requireAuthenticatedClient } from "@/lib/http/api";

const paramsSchema = z.object({ id: z.string().uuid() });
const querySchema = z.string().uuid();

export async function GET(request: Request, context: { params: Promise<{ id: string }> }) {
  return apiRoute(async () => {
    const { supabase } = await requireAuthenticatedClient();
    const { id } = paramsSchema.parse(await context.params);
    const organizationId = querySchema.parse(new URL(request.url).searchParams.get("organizationId"));
    const patient = await new PatientService(new PatientRepository(supabase)).get(organizationId, id);
    if (!patient) throw new ApiError(404, "RESOURCE_NOT_FOUND", "The requested resource was not found.");
    return NextResponse.json({ data: patient });
  });
}
