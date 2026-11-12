import { describe, expect, it } from "vitest";

import { locales } from "@/i18n/config";
import { messages } from "@/i18n/messages";

describe("translation dictionaries", () => {
  it("contains the same non-empty message keys in every supported locale", () => {
    const expectedKeys = Object.keys(messages.en).sort();

    for (const locale of locales) {
      expect(Object.keys(messages[locale]).sort()).toEqual(expectedKeys);
      for (const value of Object.values(messages[locale])) {
        expect(value.trim().length).toBeGreaterThan(0);
      }
    }
  });
});
