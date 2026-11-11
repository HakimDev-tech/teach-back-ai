import { NextResponse } from "next/server";
import { z } from "zod";
import { PatientRepository } from "@/features/patients/infrastructure/patient-repository";
import { PatientService } from "@/features/patients/application/patient-service";
import { apiRoute, requireAuthenticatedClient } from "@/lib/http/api";

const createSchema = z.object({
  organizationId: z.string().uuid(),
  fullName: z.string().trim().min(2).max(160),
  preferredLanguage: z.enum(["en", "fr", "ar"]).nullable().optional(),
});
const listSchema = z.string().uuid();

export const GET = (request: Request) =>
  apiRoute(async () => {
    const { supabase } = await requireAuthenticatedClient();
    const organizationId = listSchema.parse(new URL(request.url).searchParams.get("organizationId"));
    const service = new PatientService(new PatientRepository(supabase));
    return NextResponse.json({ data: await service.list(organizationId) });
  });

export const POST = (request: Request) =>
  apiRoute(async () => {
    const { supabase } = await requireAuthenticatedClient();
    const body = createSchema.parse(await request.json());
    const service = new PatientService(new PatientRepository(supabase));
    const id = await service.create({
      organizationId: body.organizationId,
      fullName: body.fullName,
      preferredLanguage: body.preferredLanguage ?? null,
    });
    return NextResponse.json({ data: { id } }, { status: 201 });
  });
