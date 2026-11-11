import { NextResponse } from "next/server";
import { z } from "zod";
import { SessionRepository } from "@/features/sessions/infrastructure/session-repository";
import { SessionService } from "@/features/sessions/application/session-service";
import { apiRoute, requireAuthenticatedClient } from "@/lib/http/api";

const paramsSchema = z.object({ id: z.string().uuid() });
const bodySchema = z.object({
  expectedVersion: z.number().int().positive(),
  targetStatus: z.enum(["draft", "ready", "in_progress", "awaiting_review", "review_in_progress", "completed", "cancelled", "expired"]),
});

export async function POST(request: Request, context: { params: Promise<{ id: string }> }) {
  return apiRoute(async () => {
    const { supabase } = await requireAuthenticatedClient();
    const { id } = paramsSchema.parse(await context.params);
    const body = bodySchema.parse(await request.json());
    const version = await new SessionService(new SessionRepository(supabase))
      .transition(id, body.expectedVersion, body.targetStatus);
    return NextResponse.json({ data: { version } });
  });
}
