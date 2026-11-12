import "server-only";

import { cookies, headers } from "next/headers";

import { isLocale, negotiateLocale } from "@/i18n/config";
import { messages, type MessageKey } from "@/i18n/messages";

export async function getLocale() {
  const cookieStore = await cookies();
  const preference = cookieStore.get("tb_locale")?.value;
  if (isLocale(preference)) return preference;

  const requestHeaders = await headers();
  return negotiateLocale(requestHeaders.get("accept-language"));
}

export async function getServerI18n() {
  const locale = await getLocale();
  const dictionary = messages[locale];

  return {
    locale,
    dictionary,
    t: (key: MessageKey) => dictionary[key],
  };
}
