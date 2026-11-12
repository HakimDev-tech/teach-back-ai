"use server";

import { revalidatePath } from "next/cache";
import { cookies } from "next/headers";

import { isLocale } from "@/i18n/config";

export async function setLocaleAction(formData: FormData) {
  const value = formData.get("locale");
  if (!isLocale(value)) return;

  const cookieStore = await cookies();
  cookieStore.set("tb_locale", value, {
    httpOnly: true,
    maxAge: 60 * 60 * 24 * 365,
    path: "/",
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
  });

  revalidatePath("/", "layout");
}
