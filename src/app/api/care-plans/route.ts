import { NextResponse } from "next/server";
import { z } from "zod";
import { InstructionRepository } from "@/features/instructions/infrastructure/instruction-repository";
import { InstructionService } from "@/features/instructions/application/instruction-service";
import { apiRoute, requireAuthenticatedClient } from "@/lib/http/api";

const schema = z.object({
  organizationId: z.string().uuid(),
  patientId: z.string().uuid(),
  title: z.string().trim().min(2).max(160),
});

export async function POST(request: Request) {
  return apiRoute(async () => {
    const { supabase, user } = await requireAuthenticatedClient();
    const body = schema.parse(await request.json());
    const id = await new InstructionService(new InstructionRepository(supabase)).createCarePlan({
      organizationId: body.organizationId,
      patientId: body.patientId,
      title: body.title,
      userId: user.id,
    });
    return NextResponse.json({ data: { id } }, { status: 201 });
  });
}
