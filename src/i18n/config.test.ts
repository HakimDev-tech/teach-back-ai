import { describe, expect, it } from "vitest";

import { defaultLocale, getDirection, isLocale, negotiateLocale } from "@/i18n/config";

describe("locale configuration", () => {
  it("accepts only supported locale identifiers", () => {
    expect(isLocale("en")).toBe(true);
    expect(isLocale("fr")).toBe(true);
    expect(isLocale("ar")).toBe(true);
    expect(isLocale("es")).toBe(false);
    expect(isLocale(null)).toBe(false);
  });

  it("uses English as the fallback", () => {
    expect(defaultLocale).toBe("en");
    expect(negotiateLocale(null)).toBe("en");
    expect(negotiateLocale("es-ES, de;q=0.8")).toBe("en");
  });

  it("negotiates supported regional language tags by quality", () => {
    expect(negotiateLocale("fr-DZ, ar-DZ;q=0.9, en-GB;q=0.8")).toBe("fr");
    expect(negotiateLocale("es-ES;q=1, ar-DZ;q=0.9, fr-FR;q=0.8")).toBe("ar");
    expect(negotiateLocale("fr-FR;q=0, ar-DZ;q=0.7")).toBe("ar");
  });

  it("uses the correct text direction", () => {
    expect(getDirection("en")).toBe("ltr");
    expect(getDirection("fr")).toBe("ltr");
    expect(getDirection("ar")).toBe("rtl");
  });
});
