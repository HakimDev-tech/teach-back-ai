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

## Phase B domain boundary

The authenticated API currently exposes internal clinician operations for patient creation/listing, assignment management, care plans, instruction versioning/approval, session preparation/transitions, question approval, and response draft/submission. PostgreSQL constraints, RPCs, GRANTs, and RLS enforce the critical invariants. Response capture is not patient self-service: do not expose these routes to anonymous users or treat a clinician session as patient authentication.

There is no AI functionality in Phase B. The application does not diagnose, prescribe, change treatment, or make discharge/safety decisions. Instruction and question approval remain clinician actions.

## Authentication foundation
Sign-up creates an Auth identity; a database trigger provisions a minimal profile. Registration does not grant an organization membership or professional role. Organization creation and owner transfer are controlled PostgreSQL functions.

## Current interface scope

The current interface includes the public entry page, sign-in/sign-up, a clinician access overview, and a responsive clinician patient directory. Clinical access requires an active, unexpired, independently approved clinical-capability grant and an active patient assignment; the organization membership role alone is insufficient. Authorized clinicians can create a patient record; the database atomically creates the creator's active assignment. The directory reads only rows permitted by RLS and currently displays at most the 100 most recently added assigned records.

Patient creation does not invite a patient or grant patient-portal access. Patient authentication, invitations, patient self-service, care-plan authoring, instruction approval, session preparation, clinician response review, clarification, retry, and organization administration are not yet exposed as complete UI workflows. The internal response APIs remain clinician-only.

## Architecture and product documents
- [Architecture overview](docs/architecture/overview.md)
- [Database foundations](docs/architecture/database-foundations.md)
- [Security model](docs/architecture/security-model.md)
- [Domain model](docs/architecture/domain-model.md)
- [Domain workflows](docs/architecture/domain-workflows.md)
- [Data integrity](docs/architecture/data-integrity.md)
- [Domain authorization](docs/architecture/domain-authorization.md)
- [Product architecture and route map](docs/product/product-architecture.md)
- [Design system](docs/product/design-system.md)
- [Internationalization architecture](docs/product/internationalization-architecture.md)
- [Phase C domain extension design](docs/product/phase-c-domain-extension-design.md)
- [UI/API/domain traceability](docs/architecture/ui-api-domain-traceability.md)

## Verification status

GitHub Actions has validated the foundation on commit `5d830ead2b630a12f41f9c62b2c78802890681c8` (run `43234578773`) and the patient-directory implementation/documentation on commit `0cdfe5e4b4ef5c918dba9a38355e3226bf4fb2f4` (run `43235563829`). The latter completed clean database reset/migrations, database lint, 105 pgTAP assertions, 26 Vitest tests, ESLint, TypeScript, dependency audit, and production build successfully. Later commits require their own CI result before they can be considered verified.

**Reproducibility limitation:** CI currently uses `npm install`, generates `package-lock.json` and database types, and runs `prettier --write .` before checking formatting. Those generated/normalized files are packaged as a temporary workflow artifact, not committed to the branch. Consequently, deterministic `npm ci` installation and formatting of the committed tree are not yet established. Do not use real patient data.
