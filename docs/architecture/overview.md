# Architecture overview — Phase A

## Scope
This document describes the technical foundation only. Clinical workflows, patient records, AI orchestration, and clinical review are deferred.

## Architecture
Teach-back AI is a modular monolith built with Next.js App Router. React Server Components are the default; Client Components are limited to interactive forms. PostgreSQL is the source of truth for authorization. Supabase Auth owns identity and sessions.

## Technology
Next.js, React, strict TypeScript, Tailwind CSS, Supabase PostgreSQL/Auth, `@supabase/ssr`, Zod, Vitest, pgTAP, and GitHub Actions.

## Boundaries
- `src/app`: routing, layouts, and HTTP endpoints.
- `src/features`: feature-owned application and presentation logic.
- `src/lib/supabase`: browser/server clients and session refresh.
- `src/lib/env`: validated public environment variables.
- `src/types`: generated database types.

No service-role client is implemented. Privileged operations are restricted to narrowly scoped SQL functions.

## Environments
Local development uses Next.js plus Supabase CLI. CI should start a clean Supabase stack, apply migrations, run pgTAP, and run application checks. Preview and production must use separate Supabase projects and environment variables.

## Limitations
This foundation is not a regulatory compliance assessment or production-readiness certification. No patient workflows, monitoring, backup policy, or audit trail is implemented.
