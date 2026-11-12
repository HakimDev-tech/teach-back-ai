import type { Locale } from "@/i18n/config";

export function formatDate(
  value: Date | string | number,
  locale: Locale,
  options: Intl.DateTimeFormatOptions = { dateStyle: "medium" },
) {
  const date = value instanceof Date ? value : new Date(value);
  return new Intl.DateTimeFormat(locale, options).format(date);
}

export function formatNumber(
  value: number,
  locale: Locale,
  options?: Intl.NumberFormatOptions,
) {
  return new Intl.NumberFormat(locale, options).format(value);
}
