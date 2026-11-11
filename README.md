# Teach-back AI

A clinician-guided platform for verifying whether patients understand their care instructions through the Teach-Back method.

> Understanding care is part of receiving care.

## Safety boundaries
- AI must not diagnose, prescribe, modify treatment, or make clinical safety decisions.
- Clinicians remain responsible for approving medical instructions and clarifications.
- Use synthetic data only in development, tests, and demonstrations.
- Phase A establishes identity and tenant foundations.
- Phase B adds organization-scoped patient records, clinician assignments, care plans, immutable instruction versions, session-specific approved questions, session state transitions, and internal response persistence.
- AI workflows and patient self-service access are not implemented.

## Prerequisites
- Node.js 20.9 or newer.
- npm 10 or newer.
- Docker Desktop or compatible Docker Engine.
- Supabase CLI (install using the official Supabase CLI instructions).

## Setup
1. Install dependencies: `npm install`.
2. Copy `.env.example` to `.env.local`.
3. Start Supabase: `npx supabase start`.
4. Copy the local API URL and publishable key printed by the CLI into `.env.local`.
5. Apply migrations: `npx supabase db reset`.
6. Start Next.js: `npm run dev`.

Local email confirmation is disabled only for local development. Hosted environments must configure email confirmation, SMTP, redirect allowlists, and production auth policy explicitly.

## Database commands
- Start: `npm run db:start`
- Stop: `npm run db:stop`
- Reset and reapply migrations: `npm run db:reset`
- Run pgTAP tests: `npm run test:db`
- Generate TypeScript types: `npm run db:types`
- Lint database: `npm run db:lint`

Generated types are written to `src/types/database.types.ts`. Regenerate after every migration change; do not hand-edit generated output.

## Application checks
- `npm run lint`
- `npm run format`
- `npm run typecheck`
- `npm test`
- `npm run build`

## Authentication foundation
Sign-up creates an Auth identity; a database trigger provisions a minimal profile. Registration does not grant an organization membership or professional role. Organization creation and owner transfer are controlled PostgreSQL functions.

## Architecture documents
- [Overview](docs/architecture/overview.md)
- [Database foundations](docs/architecture/database-foundations.md)
- [Security model](docs/architecture/security-model.md)

## Verification status
The remote foundation commit is not yet locally executed against Supabase or built with npm. The committed CI workflow is intended to perform those checks. A generated npm lockfile and generated database types must be produced and committed from a provisioned development environment before reproducible installation can be claimed. Do not use real patient data.
