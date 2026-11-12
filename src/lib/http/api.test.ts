import { NextResponse } from "next/server";
import { afterEach, describe, expect, it, vi } from "vitest";
import { z } from "zod";
import { ApiError, apiRoute, requireAuthenticatedClient } from "./api";
import { createClient } from "@/lib/supabase/server";

vi.mock("@/lib/supabase/server", () => ({
  createClient: vi.fn(),
}));

const mockedCreateClient = vi.mocked(createClient);

afterEach(() => {
  vi.resetAllMocks();
});

describe("apiRoute", () => {
  it("returns a successful response without changing its status or body", async () => {
    const response = await apiRoute(async () =>
      NextResponse.json({ data: { id: "patient-1" } }, { status: 201 }),
    );

    expect(response.status).toBe(201);
    await expect(response.json()).resolves.toEqual({
      data: { id: "patient-1" },
    });
  });

  it("serializes application errors using their public status and code", async () => {
    const response = await apiRoute(async () => {
      throw new ApiError(409, "CONFLICT", "The resource has changed.");
    });

    expect(response.status).toBe(409);
    await expect(response.json()).resolves.toEqual({
      error: {
        code: "CONFLICT",
        message: "The resource has changed.",
      },
    });
  });

  it("converts Zod failures to 422 without exposing the submitted payload", async () => {
    const schema = z.object({ fullName: z.string().min(2) });
    const response = await apiRoute(async () => {
      schema.parse({ fullName: "x", secret: "must-not-leak" });
      return NextResponse.json({});
    });

    expect(response.status).toBe(422);
    const body = await response.json();
    expect(body.error.code).toBe("VALIDATION_ERROR");
    expect(body.error.issues).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ path: ["fullName"] }),
      ]),
    );
    expect(JSON.stringify(body)).not.toContain("must-not-leak");
  });

  it.each([
    ["42501", 403, "FORBIDDEN"],
    ["PGRST116", 404, "RESOURCE_NOT_FOUND"],
    ["P0002", 404, "RESOURCE_NOT_FOUND"],
    ["40001", 409, "SESSION_VERSION_CONFLICT"],
    ["23505", 409, "DUPLICATE_SUBMISSION"],
    ["23503", 422, "VALIDATION_ERROR"],
    ["23514", 422, "INVALID_DOMAIN_TRANSITION"],
    ["22023", 422, "VALIDATION_ERROR"],
  ])("maps database code %s to HTTP %i (%s)", async (code, status, publicCode) => {
    const response = await apiRoute(async () => {
      throw Object.assign(new Error("internal database detail"), { code });
    });

    expect(response.status).toBe(status);
    await expect(response.json()).resolves.toMatchObject({
      error: { code: publicCode },
    });
  });

  it("does not expose unexpected internal error messages", async () => {
    const response = await apiRoute(async () => {
      throw new Error("postgres password or SQL detail");
    });

    expect(response.status).toBe(500);
    const body = await response.json();
    expect(body.error.code).toBe("INTERNAL_ERROR");
    expect(JSON.stringify(body)).not.toContain("postgres password");
  });
});

describe("requireAuthenticatedClient", () => {
  it("returns the authenticated user and the request-scoped Supabase client", async () => {
    const user = { id: "user-123" };
    const supabase = {
      auth: { getUser: vi.fn().mockResolvedValue({ data: { user }, error: null }) },
    };
    mockedCreateClient.mockResolvedValue(supabase as never);

    await expect(requireAuthenticatedClient()).resolves.toEqual({
      supabase,
      user,
    });
  });

  it("rejects missing or invalid authentication with a stable 401 error", async () => {
    const supabase = {
      auth: {
        getUser: vi.fn().mockResolvedValue({
          data: { user: null },
          error: { message: "invalid session" },
        }),
      },
    };
    mockedCreateClient.mockResolvedValue(supabase as never);

    await expect(requireAuthenticatedClient()).rejects.toMatchObject({
      status: 401,
      code: "UNAUTHENTICATED",
    });
  });
});
