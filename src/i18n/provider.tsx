"use client";

import { createContext, useContext, type ReactNode } from "react";

import type { Locale } from "@/i18n/config";
import type { Dictionary, MessageKey } from "@/i18n/messages";

type I18nContextValue = {
  locale: Locale;
  dictionary: Dictionary;
};

const I18nContext = createContext<I18nContextValue | null>(null);

export function I18nProvider({
  children,
  dictionary,
  locale,
}: {
  children: ReactNode;
  dictionary: Dictionary;
  locale: Locale;
}) {
  return (
    <I18nContext.Provider value={{ locale, dictionary }}>
      {children}
    </I18nContext.Provider>
  );
}

export function useI18n() {
  const context = useContext(I18nContext);

  if (!context) {
    throw new Error("useI18n must be used within I18nProvider.");
  }

  return {
    locale: context.locale,
    t: (key: MessageKey) => context.dictionary[key],
  };
}
