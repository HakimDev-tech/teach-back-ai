import { NextResponse } from "next/server";
import { z } from "zod";
import { SessionRepository } from "@/features/sessions/infrastructure/session-repository";
import { SessionService } from "@/features/sessions/application/session-service";
import { apiRoute, requireAuthenticatedClient } from "@/lib/http/api";

const schema = z.object({
  organizationId: z.string().uuid(),
  patientId: z.string().uuid(),
  carePlanId: z.string().uuid().nullable().optional(),
  expiresAt: z.string().datetime({ offset: true }).nullable().optional(),
});

export async function POST(request: Request) {
  return apiRoute(async () => {
    const { supabase, user } = await requireAuthenticatedClient();
    const body = schema.parse(await request.json());
    const session = await new SessionService(new SessionRepository(supabase)).create({
      organizationId: body.organizationId,
      patientId: body.patientId,
      carePlanId: body.carePlanId ?? null,
      userId: user.id,
      expiresAt: body.expiresAt ?? null,
    });
    return NextResponse.json({ data: session }, { status: 201 });
  });
}
