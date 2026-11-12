# Phase 0 — Repository baseline audit

**Audit date:** 2026-11-12  
**Audited branch:** `phase-b/world-class-product`  
**Audited commit:** `50eaaabaa99cc1a8c38f4f82afd24de86df23543`  
**Base:** `phase-b/business-domain` at `8f9f9a579b04977b640102b4557095efc71a2cc7`

## Executive assessment

The repository contains a meaningful PostgreSQL/Supabase domain foundation and a small set of authenticated API routes. It does **not** yet contain a complete healthcare product. The clinician and patient workflows are not connected through a usable end-to-end interface, patient identity and invitation flows are absent, and organization onboarding is incomplete.

The current state is best described as a **backend domain foundation with a minimal authentication shell**, not as a launch-ready or production-ready healthcare application.

## Scope inspected

- README and architecture documentation.
- All existing Supabase migrations, database functions, triggers, constraints, grants, indexes, and RLS policies.
- API route handlers, application services, repositories, and authentication helpers.
- Existing pages, forms, layouts, and global styles.
- Vitest and pgTAP tests.
- Package manifest, dependency overrides, TypeScript/ESLint/Prettier configuration, and CI workflows.

## Implemented foundations

### Identity and organization boundary

- Supabase Auth integration with server-side user verification.
- Profile provisioning from bounded user metadata.
- Organization memberships with owner, admin, and clinician roles.
- Controlled organization creation and ownership transfer.
- Protection against removing or demoting the final active owner.
- RLS on profiles, organizations, and memberships.

### Clinical domain

- Organization-scoped patient records.
- Active clinician-patient assignments.
- Care plans and instruction items.
- Versioned instruction content with explicit clinician approval.
- Immutable approved instruction versions.
- Teach-Back sessions with exact instruction-version snapshots.
- Approved session questions.
- Session state transitions with optimistic version checks.
- Response drafts, submission, idempotency, and immutable submitted responses.
- Tenant-aware foreign keys, indexes, explicit grants, and RLS.

### API surface

The current API includes operations for patients, assignments, care plans, instruction versions, question editing/approval, sessions, response capture, and response submission. These routes use Zod validation and authenticated Supabase server clients.

The API layer is not equivalent to a completed product workflow: several read operations, onboarding paths, patient-facing operations, and review/clarification operations remain absent.

## Current interface

The production build currently exposes these user-facing pages:

- `/`
- `/sign-in`
- `/sign-up`
- `/clinician`

The clinician page is an authentication-gated placeholder, not an operational workspace. There is no patient portal, organization administration interface, clinician onboarding experience, or full navigation system.

## Phase 0 defects corrected

1. **pgTAP SQL quoting and incomplete execution:** malformed dollar-quoted statements were repaired. The Phase B test plan now executes all 59 assertions.
2. **HTTP response typing:** the API wrapper now uses the standard `Response` contract, compatible with Next.js route handlers returning either `Response` or `NextResponse`.
3. **Draft question editing:** a migration grants only the `question_text` and `position` update columns to authenticated users. RLS and the immutable-question trigger remain authoritative.
4. **Session finality:** a session in `ready` can no longer return to `draft`. The transition function and database trigger enforce the invariant.
5. **CI Supabase concurrency:** the separate preparation workflow was consolidated into the CI workflow to avoid competing local Supabase stacks and port collisions.

## Verification evidence

GitHub Actions run: [CI run 43218762278](https://github.com/HakimDev-tech/teach-back-ai/actions/runs/43218762278)  
Commit: `50eaaabaa99cc1a8c38f4f82afd24de86df23543`

| Check | Result |
|---|---:|
| Clean database migration reset | Passed |
| PostgreSQL lint | Passed |
| pgTAP suite | 96/96 assertions passed |
| Vitest | 3 files, 20 tests passed |
| ESLint | Passed |
| TypeScript strict check | Passed |
| npm audit | 0 vulnerabilities reported |
| Next.js production build | Passed |
| Database type generation | Passed |
| Prettier verification | Passed |

These results validate the current foundation and its automated checks. They do **not** establish clinical validity, regulatory compliance, production security, accessibility conformance, or completion of the product journeys.

## Critical gaps before product implementation

### 1. Patient identity and secure access

The patient table currently stores a name and preferred language but has no authenticated patient identity link. There are no hashed, expiring, single-use patient invitations and no patient-specific RLS access model. A patient cannot securely enter the application or complete a session independently.

### 2. Organization onboarding and combined capabilities

An organization membership has one role: `owner`, `admin`, or `clinician`. Organization creation assigns the creator the owner role, while clinical operations require clinician capability. A solo practitioner cannot naturally be both organization owner and clinician.

Administrative rights must remain separate from clinical access. The model needs explicit clinical capability, plus an active patient assignment, rather than granting clinical visibility to all owners or administrators.

### 3. Clinician review and repeated Teach-Back

The response table has an attempt number, but the current state machine does not support a complete review → clinician clarification → patient retry cycle. There is no structured review decision or immutable clinician clarification linked to a specific response attempt.

This is a domain-model gap, not a frontend-only issue.

### 4. Missing product experiences

- Clinician onboarding and operational workspace.
- Organization creation, member invitations, role management, and administration.
- Patient invitations, authentication, and portal.
- Patient-facing instruction and Teach-Back experience.
- Clinician review, clarification, retry, and follow-up queue.
- Meaningful aggregate comprehension metrics.
- Controlled AI assistance and traceable evidence.

### 5. Security and operations

The repository does not yet implement or verify rate limiting, a clinical audit-event model, retention/deletion policy, backup/restore procedures, production observability, or a production security-header policy. No legal or technical assessment supports a HIPAA/GDPR compliance claim.

### 6. Internationalization and accessibility

English, French, Arabic, RTL behavior, WCAG 2.2 AA validation, keyboard-only workflows, and screen-reader testing are not implemented as a complete system.

### 7. Reproducible generated files

The CI workflow successfully generated `package-lock.json`, `src/types/database.types.ts`, and formatting updates. They are packaged in the CI artifact but are not committed in this branch yet. See the generated integration archive supplied with this audit; apply it only to this branch after reviewing the diff.

## Release assessment

**Not production-ready.** The current database foundation is verified by the listed automated checks, but the product still lacks patient access, end-to-end workflows, the review/retry domain, operational security controls, localization, and accessibility validation.

## Recommended next sequence

1. Finalize generated lockfile/types integration and switch CI to deterministic `npm ci`.
2. Define the route map, role/capability model, and complete clinician/patient journeys.
3. Design secure organization and patient invitation flows.
4. Add explicit clinical capabilities without granting implicit clinical access to owners/admins.
5. Model per-response clinical review, clinician-authored clarifications, and sequential retries.
6. Build the design system and responsive application shells.
7. Implement clinician workflows, then patient portal.
8. Add controlled AI assistance only after the human review domain is complete.
9. Complete i18n/RTL, accessibility, security, E2E, performance, and operations hardening.
