export const locales = ["en", "fr", "ar"] as const;

export type Locale = (typeof locales)[number];

export const defaultLocale: Locale = "en";

export function isLocale(value: unknown): value is Locale {
  return typeof value === "string" && (locales as readonly string[]).includes(value);
}

export function getDirection(locale: Locale): "ltr" | "rtl" {
  return locale === "ar" ? "rtl" : "ltr";
}

export function negotiateLocale(acceptLanguage: string | null): Locale {
  if (!acceptLanguage) return defaultLocale;

  const preferences = acceptLanguage
    .split(",")
    .map((entry, index) => {
      const [rawTag, ...parameters] = entry.trim().split(";");
      const qualityParameter = parameters.find((parameter) =>
        parameter.trim().startsWith("q="),
      );
      const quality = qualityParameter
        ? Number(qualityParameter.trim().slice(2))
        : 1;

      return {
        tag: rawTag.trim().toLowerCase(),
        quality: Number.isFinite(quality) && quality >= 0 && quality <= 1 ? quality : 0,
        index,
      };
    })
    .filter((preference) => preference.tag.length > 0 && preference.quality > 0)
    .sort((left, right) => right.quality - left.quality || left.index - right.index);

  for (const preference of preferences) {
    if (preference.tag === "*") continue;
    const language = preference.tag.split("-")[0];
    if (isLocale(language)) return language;
  }

  return defaultLocale;
}
