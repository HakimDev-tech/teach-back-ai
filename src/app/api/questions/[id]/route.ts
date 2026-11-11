import { NextResponse } from "next/server";
import { z } from "zod";
import { SessionRepository } from "@/features/sessions/infrastructure/session-repository";
import { SessionService } from "@/features/sessions/application/session-service";
import { apiRoute, requireAuthenticatedClient } from "@/lib/http/api";

const paramsSchema = z.object({ id: z.string().uuid() });
const bodySchema = z.object({
  questionText: z.string().trim().min(8).max(2000),
  position: z.number().int().positive(),
});

export async function PATCH(request: Request, context: { params: Promise<{ id: string }> }) {
  return apiRoute(async () => {
    const { supabase } = await requireAuthenticatedClient();
    const { id } = paramsSchema.parse(await context.params);
    const body = bodySchema.parse(await request.json());
    const question = await new SessionService(new SessionRepository(supabase))
      .updateQuestion(id, body);
    return NextResponse.json({ data: question });
  });
}
