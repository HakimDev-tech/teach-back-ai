import { NextResponse } from "next/server";
import { ZodError } from "zod";
import { createClient } from "@/lib/supabase/server";

export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

export async function requireAuthenticatedClient() {
  const supabase = await createClient();
  const { data, error } = await supabase.auth.getUser();
  if (error || !data.user) {
    throw new ApiError(401, "UNAUTHENTICATED", "Authentication is required.");
  }
  return { supabase, user: data.user };
}

export async function apiRoute(
  action: () => Promise<NextResponse>,
): Promise<NextResponse> {
  try {
    return await action();
  } catch (error) {
    if (error instanceof ApiError) {
      return NextResponse.json(
        { error: { code: error.code, message: error.message } },
        { status: error.status },
      );
    }
    if (error instanceof ZodError) {
      return NextResponse.json(
        {
          error: {
            code: "VALIDATION_ERROR",
            message: "The request payload is invalid.",
            issues: error.issues.map((issue) => ({
              path: issue.path,
              message: issue.message,
            })),
          },
        },
        { status: 422 },
      );
    }
    const dbCode =
      typeof error === "object" && error !== null && "code" in error
        ? String(error.code)
        : "";
    const mapped: Record<string, { status: number; code: string; message: string }> = {
      "42501": { status: 403, code: "FORBIDDEN", message: "This operation is not permitted." },
      P0002: { status: 404, code: "RESOURCE_NOT_FOUND", message: "The requested resource was not found." },
      "40001": { status: 409, code: "SESSION_VERSION_CONFLICT", message: "The resource changed. Reload and retry." },
      "23505": { status: 409, code: "DUPLICATE_SUBMISSION", message: "A conflicting record already exists." },
      "23503": { status: 422, code: "VALIDATION_ERROR", message: "A referenced resource is invalid." },
      "23514": { status: 422, code: "INVALID_DOMAIN_TRANSITION", message: "The requested domain operation is not valid." },
      "22023": { status: 422, code: "VALIDATION_ERROR", message: "The supplied value is invalid." },
    };
    const result = mapped[dbCode] ?? {
      status: 500,
      code: "INTERNAL_ERROR",
      message: "An unexpected error occurred.",
    };
    return NextResponse.json({ error: { code: result.code, message: result.message } }, { status: result.status });
  }
}
