import { NextResponse } from "next/server";
import { z } from "zod";

import { ClinicalCapabilityService } from "@/features/clinical-capabilities/application/clinical-capability-service";
import { ClinicalCapabilityRepository } from "@/features/clinical-capabilities/infrastructure/clinical-capability-repository";
import { apiRoute, readJsonBody, requireAuthenticatedClient } from "@/lib/http/api";

const paramsSchema = z.object({ capabilityId: z.string().uuid() });
const bodySchema = z.object({
  expiresAt: z.string().datetime({ offset: true }).nullable().optional(),
});

export async function POST(
  request: Request,
  context: { params: Promise<{ capabilityId: string }> },
) {
  return apiRoute(async () => {
    const { supabase } = await requireAuthenticatedClient();
    const { capabilityId } = paramsSchema.parse(await context.params);
    const body = bodySchema.parse(await readJsonBody(request));

    await new ClinicalCapabilityService(new ClinicalCapabilityRepository(supabase)).approve(
      capabilityId,
      body.expiresAt ?? null,
    );

    return NextResponse.json({ data: { capabilityId, status: "active" } });
  });
}
