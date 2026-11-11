import { NextResponse } from "next/server";

import { createClient } from "@/lib/supabase/server";

export async function GET(request: Request) {
  const url = new URL(request.url);
  const code = url.searchParams.get("code");
  const requestedNext = url.searchParams.get("next");
  let destination = "/clinician";

  if (requestedNext?.startsWith("/") && !requestedNext.startsWith("//")) {
    try {
      const candidate = new URL(requestedNext, url.origin);
      if (candidate.origin === url.origin) {
        destination = `${candidate.pathname}${candidate.search}${candidate.hash}`;
      }
    } catch {
      // Keep the safe default for malformed redirect values.
    }
  }

  if (code) {
    const supabase = await createClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) return NextResponse.redirect(new URL(destination, url.origin));
  }

  return NextResponse.redirect(new URL("/sign-in?error=auth_callback", url.origin));
}
