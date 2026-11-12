import { z } from "zod";

export const clinicalCapabilityReviewRequestSchema = z.object({
  capability_id: z.string().uuid(),
  user_id: z.string().uuid(),
  display_name: z.string().min(1),
  professional_type: z.string().min(2),
  status: z.literal("pending"),
  verification_status: z.string(),
  requested_at: z.string(),
  expires_at: z.string().nullable(),
  verification_method: z.string().nullable(),
});

export const clinicalCapabilityReviewRequestsSchema = z.array(
  clinicalCapabilityReviewRequestSchema,
);

export const myClinicalCapabilitySchema = z.object({
  id: z.string().uuid(),
  organization_id: z.string().uuid(),
  professional_type: z.string().min(2),
  status: z.enum(["pending", "active", "suspended", "revoked"]),
  verification_status: z.enum(["pending", "verified", "rejected", "expired"]),
  expires_at: z.string().nullable(),
  created_at: z.string(),
  is_expired: z.boolean(),
});

export const myClinicalCapabilitiesSchema = z.array(myClinicalCapabilitySchema);

export type ClinicalCapabilityReviewRequestRecord = z.infer<
  typeof clinicalCapabilityReviewRequestSchema
>;
export type MyClinicalCapabilityRecord = z.infer<typeof myClinicalCapabilitySchema>;
