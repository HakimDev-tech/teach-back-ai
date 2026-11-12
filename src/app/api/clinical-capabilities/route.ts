import { NextResponse } from "next/server";
import { z } from "zod";

import { ClinicalCapabilityService } from "@/features/clinical-capabilities/application/clinical-capability-service";
import { ClinicalCapabilityRepository } from "@/features/clinical-capabilities/infrastructure/clinical-capability-repository";
import { apiRoute, readJsonBody, requireAuthenticatedClient } from "@/lib/http/api";

const requestSchema = z.object({
  organizationId: z.string().uuid(),
  professionalType: z.string().trim().min(2).max(80),
});

export const POST = (request: Request) =>
  apiRoute(async () => {
    const { supabase } = await requireAuthenticatedClient();
    const body = requestSchema.parse(await readJsonBody(request));
    const capabilityId = await new ClinicalCapabilityService(
      new ClinicalCapabilityRepository(supabase),
    ).request(body);

    return NextResponse.json({ data: { capabilityId } }, { status: 201 });
  });
