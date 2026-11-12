import type { Metadata } from "next";

import { getDirection } from "@/i18n/config";
import { I18nProvider } from "@/i18n/provider";
import { getServerI18n } from "@/i18n/server";

import "./globals.css";

export async function generateMetadata(): Promise<Metadata> {
  const { t } = await getServerI18n();

  return {
    title: t("meta.title"),
    description: t("meta.description"),
  };
}

export default async function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const { locale, dictionary } = await getServerI18n();

  return (
    <html dir={getDirection(locale)} lang={locale}>
      <body>
        <I18nProvider dictionary={dictionary} locale={locale}>
          {children}
        </I18nProvider>
      </body>
    </html>
  );
}
