import { afterEach, describe, expect, it, vi } from "vitest";
import { getPublicEnv } from "./public";
describe("getPublicEnv", () => {
  afterEach(() => vi.unstubAllEnvs());
  it("rejects missing configuration", () => { vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", ""); vi.stubEnv("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY", ""); expect(() => getPublicEnv()).toThrow(); });
  it("accepts valid public settings", () => { vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "http://127.0.0.1:54321"); vi.stubEnv("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY", "local-test-key"); expect(getPublicEnv().NEXT_PUBLIC_SUPABASE_URL).toBe("http://127.0.0.1:54321"); });
});
