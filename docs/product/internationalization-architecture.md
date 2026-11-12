# Internationalization and RTL architecture

**Status:** implementation baseline for Phase C  
**Supported locales:** English (en), French (fr), Arabic (ar)  
**Fallback locale:** English

## 1. Locale resolution

The product is primarily an authenticated clinical workspace rather than a search-indexed content site. Use a persistent locale preference without adding locale prefixes to every route in the first release.

Resolution order:

1. A valid explicit user preference cookie (server-readable, HttpOnly).
2. The best supported language in the browser's Accept-Language header.
3. English fallback.

The locale preference must be validated against the supported locale allowlist. Unsupported or malformed values are ignored. The language selector updates the cookie through a server action and refreshes the current route without changing its URL.

This keeps Supabase auth callback paths, API paths, and patient invitation routes stable. If public multi-language SEO becomes a product requirement, introduce locale-prefixed marketing routes as a separate change; do not mix that concern into authenticated workflow URLs.

## 2. Translation architecture

- Keep all user-visible text in typed dictionaries under src/i18n/messages.
- Use the same key set for en, fr, and ar; enforce key parity at compile time and in tests.
- Provide a server translation helper for Server Components and a small client context/provider for interactive components.
- Do not call a translation API at runtime.
- Do not scatter language conditionals through page components.
- API responses use stable machine-readable error codes; the interface maps those codes to localized messages.
- Validation errors, empty states, loading states, confirmation dialogs, toast messages, accessible names, placeholders, helper text, and metadata are all translatable.
- Use parameterized messages for counts and names; do not concatenate translated sentence fragments.

No new i18n dependency is required for the current scope. If ICU plural rules or complex message formatting outgrow the small dictionary helper, reassess a maintained library such as next-intl with a migration plan.

## 3. Document language and direction

The root layout resolves the locale on the server and sets:

- html lang to the resolved BCP-47 language tag;
- html dir to rtl for Arabic and ltr for English/French;
- the same locale in the translation provider.

The Arabic layout must be genuinely RTL, not merely right-aligned text.

Implementation rules:

- Prefer CSS logical properties and Tailwind logical utilities over left/right positioning.
- Review navigation order, breadcrumbs, drawers, dialog placement, icons, progress indicators, tables, and form alignment in RTL.
- Keep email addresses, URLs, phone numbers, UUIDs, and other technical identifiers explicitly LTR where needed.
- Do not put translatable words inside static SVG paths. Use HTML text alongside SVG artwork or render labels from the translation dictionary.
- Avoid mirroring icons whose meaning is not directional; mirror only directional affordances such as back/forward arrows.
- Use a font stack with Arabic glyph coverage and test line height/diacritics on mobile.

## 4. Locale-aware formatting

Use Intl.DateTimeFormat, Intl.NumberFormat, and Intl.RelativeTimeFormat with the active locale. Store timestamps in UTC and format at the presentation boundary. Do not persist localized date strings or use localized strings in database comparisons.

API and database enums remain locale-neutral. Only presentation labels are translated.

## 5. Accessibility requirements

- The language selector has a visible label and keyboard-operable controls.
- Changing language updates lang/dir and does not silently discard a patient response draft.
- Every locale has equivalent accessible names, field errors, status announcements, and instructions.
- Verify keyboard navigation, focus order, contrast, text resizing, and screen-reader output in Arabic RTL and French/English LTR.
- Do not use color alone to communicate status.
- Respect reduced-motion preferences independently of locale.

## 6. Verification

Required automated checks:

- All three dictionaries expose exactly the same key set.
- Locale parsing accepts en/fr/ar and rejects unsupported tags.
- Accept-Language negotiation respects quality values and regional tags (for example fr-DZ, ar-DZ, en-GB).
- Invalid cookies fall back safely.
- Root html lang/dir match the selected locale.
- API error codes resolve to localized UI messages.
- No missing translation key silently renders as an undefined value.

Required manual/browser checks:

- Sign-up, sign-in, callback, and sign-out in all three languages.
- Clinician shell and patient portal in all three languages.
- Arabic RTL at 320px, 375px, tablet, and desktop widths.
- Long French labels and Arabic text wrapping in forms, tables, and dialogs.
- Language change while a form is dirty; preserve data or require an explicit save/discard decision.
