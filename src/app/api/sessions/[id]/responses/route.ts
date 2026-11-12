import { NextResponse } from "next/server";
import { z } from "zod";
import { ResponseRepository } from "@/features/responses/infrastructure/response-repository";
import { ResponseService } from "@/features/responses/application/response-service";
import { apiRoute, readJsonBody, requireAuthenticatedClient } from "@/lib/http/api";

const paramsSchema = z.object({ id: z.string().uuid() });
const bodySchema = z.object({
  questionId: z.string().uuid(),
  idempotencyKey: z.string().uuid(),
  responseText: z.string().trim().min(1).max(10000),
  attemptNumber: z.number().int().positive().default(1),
});

export async function POST(request: Request, context: { params: Promise<{ id: string }> }) {
  return apiRoute(async () => {
    const { supabase } = await requireAuthenticatedClient();
    const { id } = paramsSchema.parse(await context.params);
    const body = bodySchema.parse(await readJsonBody(request));
    const responseId = await new ResponseService(new ResponseRepository(supabase)).saveDraft({
      sessionId: id,
      questionId: body.questionId,
      idempotencyKey: body.idempotencyKey,
      responseText: body.responseText,
      attemptNumber: body.attemptNumber,
    });
    return NextResponse.json({ data: { responseId } }, { status: 201 });
  });
}
