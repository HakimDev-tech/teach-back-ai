import { NextResponse } from "next/server";
import { z } from "zod";
import { ResponseRepository } from "@/features/responses/infrastructure/response-repository";
import { ResponseService } from "@/features/responses/application/response-service";
import { apiRoute, requireAuthenticatedClient } from "@/lib/http/api";

const paramsSchema = z.object({ id: z.string().uuid() });

export async function POST(_request: Request, context: { params: Promise<{ id: string }> }) {
  return apiRoute(async () => {
    const { supabase } = await requireAuthenticatedClient();
    const { id } = paramsSchema.parse(await context.params);
    const responseId = await new ResponseService(new ResponseRepository(supabase)).submit(id);
    return NextResponse.json({ data: { responseId, submitted: true } });
  });
}
