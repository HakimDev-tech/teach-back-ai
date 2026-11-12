import { NextResponse } from "next/server";
import { z } from "zod";
import { SessionRepository } from "@/features/sessions/infrastructure/session-repository";
import { SessionService } from "@/features/sessions/application/session-service";
import { apiRoute, readJsonBody, requireAuthenticatedClient } from "@/lib/http/api";

const paramsSchema = z.object({ id: z.string().uuid() });
const bodySchema = z.object({
  organizationId: z.string().uuid(),
  instructionItemId: z.string().uuid(),
  instructionVersionId: z.string().uuid(),
  questionText: z.string().trim().min(8).max(2000),
  position: z.number().int().positive(),
});

export async function POST(request: Request, context: { params: Promise<{ id: string }> }) {
  return apiRoute(async () => {
    const { supabase, user } = await requireAuthenticatedClient();
    const { id } = paramsSchema.parse(await context.params);
    const body = bodySchema.parse(await readJsonBody(request));
    const question = await new SessionService(new SessionRepository(supabase)).addQuestion({
      organizationId: body.organizationId,
      sessionId: id,
      instructionItemId: body.instructionItemId,
      instructionVersionId: body.instructionVersionId,
      questionText: body.questionText,
      position: body.position,
      userId: user.id,
    });
    return NextResponse.json({ data: question }, { status: 201 });
  });
}
