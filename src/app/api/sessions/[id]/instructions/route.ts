import { NextResponse } from "next/server";
import { z } from "zod";
import { SessionRepository } from "@/features/sessions/infrastructure/session-repository";
import { SessionService } from "@/features/sessions/application/session-service";
import { apiRoute, requireAuthenticatedClient } from "@/lib/http/api";

const paramsSchema = z.object({ id: z.string().uuid() });
const bodySchema = z.object({
  organizationId: z.string().uuid(),
  instructionItemId: z.string().uuid(),
  instructionVersionId: z.string().uuid(),
});

export async function POST(
  request: Request,
  context: { params: Promise<{ id: string }> },
) {
  return apiRoute(async () => {
    const { supabase } = await requireAuthenticatedClient();
    const { id } = paramsSchema.parse(await context.params);
    const body = bodySchema.parse(await request.json());
    const snapshot = await new SessionService(
      new SessionRepository(supabase),
    ).addInstructionSnapshot({
      organizationId: body.organizationId,
      sessionId: id,
      instructionItemId: body.instructionItemId,
      instructionVersionId: body.instructionVersionId,
    });
    return NextResponse.json({ data: snapshot }, { status: 201 });
  });
}
