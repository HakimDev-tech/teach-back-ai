import { NextResponse } from "next/server";
import { z } from "zod";
import { InstructionRepository } from "@/features/instructions/infrastructure/instruction-repository";
import { InstructionService } from "@/features/instructions/application/instruction-service";
import { apiRoute, requireAuthenticatedClient } from "@/lib/http/api";

const paramsSchema = z.object({ id: z.string().uuid() });
const bodySchema = z.object({ organizationId: z.string().uuid() });

export async function POST(request: Request, context: { params: Promise<{ id: string }> }) {
  return apiRoute(async () => {
    const { supabase } = await requireAuthenticatedClient();
    const { id } = paramsSchema.parse(await context.params);
    const body = bodySchema.parse(await request.json());
    const itemId = await new InstructionService(new InstructionRepository(supabase))
      .createInstructionItem(body.organizationId, id);
    return NextResponse.json({ data: { instructionItemId: itemId } }, { status: 201 });
  });
}
