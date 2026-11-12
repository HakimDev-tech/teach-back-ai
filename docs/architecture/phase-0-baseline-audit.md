# Phase 0 — Repository baseline audit

**Audit date:** 2026-11-12  
**Working branch:** `phase-c/product-execution`  
**Audited source commit:** `47bef5d713ff8706e86a0d7286188cd6a8e482e8`  
**Validated source branch:** `phase-b/world-class-product`  
**Base domain commit:** `phase-b/business-domain` at `8f9f9a579b04977b640102b4557095efc71a2cc7`

## Executive assessment

The repository has a credible PostgreSQL/Supabase identity and clinical-domain foundation, authenticated internal APIs, a first visual design system, and a minimal clinician-facing application shell.

It is **not yet a complete healthcare product**. There is no secure patient identity or patient portal, no operational clinician workflow, no organization invitation/onboarding flow, and no persisted clinical review/clarification/retry model. The current clinician screen is an access-status overview, not a functioning clinical workspace.

The latest validated commit is suitable as a controlled engineering baseline. It is not evidence of production readiness, clinical validation, regulatory compliance, or end-to-end product completion.

## Audit scope

Inspected the repository tree (85 tracked files at the audited commit), README, product and architecture documentation, all four SQL migrations, database functions/triggers/constraints/indexes/grants/RLS policies, all API route handlers, application services, repositories, authentication helpers, pages, forms, design-system components, global styles, tests, package configuration, and GitHub Actions workflows.

### Repository inventory

- 4 SQL migrations: identity/tenant foundation, owner guard, clinical domain foundation, and domain hardening.
- 12 principal public tables: profiles, organizations, organization memberships, patients, patient-clinician assignments, care plans, instruction items, instruction versions, Teach-Back sessions, session instruction snapshots, questions, and responses.
- 16 API route files covering internal clinician operations.
- 4 feature areas: patients, instructions, sessions, and responses.
- 3 pgTAP test files and 3 Vitest test files.
- Initial landing page, sign-in/sign-up pages, clinician shell, clinician access overview, and reusable UI primitives.

## Implemented foundations

### Identity and organization boundary

- Supabase Auth with cookie-based SSR clients.
- Server-side identity verification through `auth.getUser()` for protected API operations.
- Minimal profile provisioning from bounded user metadata; user metadata is not used for authorization.
- Organization membership roles: owner, admin, clinician.
- Controlled organization creation and ownership transfer.
- Last-active-owner protection.
- RLS and explicit table/function privileges on the identity and organization tables.

### Clinical domain

- Organization-scoped patient records.
- Active clinician-patient assignments.
- Care plans and logical instruction items.
- Versioned instruction content with explicit clinician approval.
- Immutable approved instruction versions and provenance.
- Session-specific references to exact approved instruction versions.
- Explicitly approved questions.
- Optimistic, row-locked session transitions.
- Response drafts, attempt numbers, idempotency keys, controlled submission, and immutable submitted responses. The current RPC still accepts a caller-supplied attempt number and does not yet enforce sequential retries.
- Tenant-aware composite foreign keys, indexes, triggers, explicit grants, and RLS.

### Internal API

The current API supports patient listing/creation and patient lookup; assignment creation/revocation; care-plan and instruction creation; instruction-version creation/approval; question editing/approval; session creation/preparation/transitions; and response draft/submission operations.

The API layer uses Zod validation, authenticated request-scoped Supabase clients, a common error mapper, and feature repositories/services. These endpoints are internal clinician operations. They do not constitute patient authentication or patient self-service.

### User interface and design foundation

- Public product entry page with explicit clinical boundaries.
- Sign-in and sign-up forms backed by Supabase Auth.
- Auth callback with same-origin redirect validation.
- Sign-out endpoint.
- Responsive clinician application shell and access-status page.
- Reusable button, card, badge, field, page-header, and empty-state primitives.
- Warm ivory/forest-green visual direction, semantic tokens, visible focus, skip links, reduced-motion handling, and baseline form semantics.

The clinician page currently shows organization membership/access state only. It does not yet let a clinician manage patients, author instructions, prepare sessions, or review responses.

## Phase 0 defects corrected and verified

The validated product branch includes these corrections:

1. Malformed pgTAP dollar quoting was repaired. The Phase B test plan executes all 59 assertions.
2. The API wrapper accepts the standard `Response` contract, which is compatible with both standard `Response` and `NextResponse` route handlers.
3. Draft question updates are restricted to the `question_text` and `position` columns; RLS and the immutable-question trigger remain in force.
4. A session in `ready` cannot transition back to `draft`; the state machine and database guard enforce session finality.
5. Supabase verification and generated-artifact handling were consolidated into one CI workflow to avoid competing local database stacks.

## Verification evidence

GitHub Actions: [CI run 43220452882](https://github.com/HakimDev-tech/teach-back-ai/actions/runs/43220452882)  
Validated commit: `47bef5d713ff8706e86a0d7286188cd6a8e482e8`

| Check | Observed result |
|---|---:|
| Clean local database reset and migrations | Passed |
| Supabase database lint | Passed — no schema errors |
| pgTAP | Passed — 96/96 assertions across 3 files |
| Vitest | Passed — 3 files, 20 tests |
| ESLint | Passed |
| TypeScript strict check | Passed |
| npm audit | Passed — 0 vulnerabilities reported |
| Next.js production build | Passed |
| Database type generation | Passed |
| Prettier | Formatter and subsequent check passed in the CI workspace |

**Important qualification:** CI runs `npm install`, generates database types, and runs `prettier --write` before its formatting check. The resulting `package-lock.json`, generated `src/types/database.types.ts`, and formatter changes are packaged as a CI artifact; they are not committed in the audited source branch. Therefore deterministic `npm ci` installation and formatting of the committed tree are not yet established. The artifact must be reviewed and integrated before claiming reproducible installation.

The audit command is `npm audit --audit-level=high`; the recorded npm output reported zero vulnerabilities. The package manifest contains a scoped override forcing `@typescript-eslint/typescript-estree`'s nested `minimatch` to `11.0.5`, outside its declared `^10.2.2` range. ESLint and the dependency audit passed on this exact lockfile, but this compatibility override should be re-evaluated on dependency upgrades rather than treated as a permanent upstream-compatible dependency range.

## Critical product and domain gaps

### 1. Patient identity and secure access — missing

The patient record has no authenticated patient identity linkage. There are no hashed, expiring, single-use, revocable invitations or patient-specific access grants. There is no patient-facing RLS model, patient portal, or patient authentication journey.

**Consequence:** patients cannot independently access approved instructions, save answers, submit Teach-Back responses, resume sessions, or view clinician-approved clarifications.

### 2. Clinical capability and solo-practitioner model — unresolved

Membership currently has exactly one role: owner, admin, or clinician. Clinical access is granted only when the active membership role is clinician and the user has an active patient assignment. Owners/admins can manage assignments but do not automatically see clinical records.

This least-privilege boundary is intentional. However, an owner who is also a solo practitioner cannot naturally exercise both organization-administration and clinical capabilities. Do not solve this by granting all owners/admins clinical access. Introduce explicit, independently granted capabilities or a carefully modeled multi-role membership.

### 3. Clinical review, clarification, and retry — missing domain model

The current session state machine includes review states, but there is no persisted review decision linked to a specific immutable response attempt, no clinician-authored clarification entity, and no enforced sequential patient retry workflow. The current attempt number is positive and unique but remains caller-supplied.

A transition from `review_in_progress` to `completed` does not currently require durable evidence that every required response was reviewed or that necessary clarification was approved. This is a domain-integrity gap, not a frontend task.

Before implementing this workflow, model response-level outcomes (understood, partially understood, not demonstrated, unable to evaluate), clinician review provenance, approved clarifications, retry sequencing, and completion conditions in PostgreSQL.

### 4. Clinician operations — incomplete

Missing operational capabilities include patient profile/history screens, care-plan and instruction read APIs, instruction authoring UI, approval UI, session preparation UI, invitation management, progress monitoring, review queues, follow-up tasks, and meaningful persisted comprehension metrics.

### 5. Organization administration and professional onboarding — incomplete

There is no organization onboarding UI, invitation-by-email flow, membership invitation lifecycle, role/capability management interface, clinician credential verification workflow, or audit-history interface. Sign-up creates an Auth identity but intentionally does not grant professional or organization permissions.

### 6. Authentication lifecycle — incomplete

Sign-in, sign-up, callback, and sign-out exist. Password recovery/reset UX, clear email-verification states, MFA policy, session revocation policy, and complete production auth configuration are not implemented. Local Supabase configuration disables email confirmations for development; hosted environments must configure confirmation, SMTP, redirect allowlists, and auth policy independently.

### 7. AI — not implemented

There is no AI provider adapter, instruction rewriting, question drafting, response evaluation, evidence extraction, abstention handling, or AI audit trail. This is appropriate at this stage: AI must follow the human review and clarification domain, not precede it.

### 8. Internationalization — not implemented

There is no centralized message catalog or locale-routing/state architecture. English, French, Arabic translations, locale-aware formatting, persistent language choice, and complete RTL behavior are absent. A CSS font fallback for `[dir="rtl"]` is not a complete RTL implementation.

### 9. Accessibility — foundational only

Visible focus, skip links, semantic landmarks, associated form labels, alert roles, reduced-motion support, and generous primary controls are present. There is no complete WCAG 2.2 AA audit, keyboard-only workflow verification, screen-reader testing, automated accessibility suite, or verified mobile patient journey.

### 10. Production security and operations — incomplete

Not implemented or not evidenced: rate limiting, clinical audit events, security headers/CSP, MFA, operational monitoring/alerting, incident response, backup/restore drills, retention/deletion policy, data-subject request procedures, and a documented threat model for patient invitations and delegated access.

No HIPAA, GDPR, or other compliance claim is supported by the current evidence.

## Test coverage limitations

The green CI validates the existing foundation; it does not validate the full product.

- Vitest currently has 20 tests focused on API error mapping, environment validation, and patient repository behavior.
- pgTAP has 96 assertions covering core schema, grants, RLS, selected tenant boundaries, state transitions, immutability, and idempotency.
- There are no Playwright end-to-end tests.
- There are no complete browser tests for authentication/onboarding, clinician journeys, patient journeys, or organization administration.
- API handler authorization and full multi-tenant adversarial scenarios are not exhaustively covered.
- No accessibility, localization, performance, or load-test suite exists.

## Release assessment

**Status: validated foundation, incomplete product; not production-ready.**

The next phase must not add a patient-facing UI on top of the current clinician-only access model. First finalize the domain contracts for clinical capabilities, invitations, patient identity, response review, clarification, and retries. PostgreSQL and RLS must remain authoritative for these boundaries.

## Recommended execution order

1. Integrate and review the generated lockfile/types/formatting artifact; switch CI to deterministic `npm ci` and check formatting without silently rewriting the source tree.
2. Finalize the capability model, including the solo-practitioner case, without broadening administrative clinical access.
3. Design and test organization invitations and secure patient identity/invitation/access grants.
4. Add response review, clinician-approved clarification, immutable attempts, and retry/completion invariants.
5. Complete the domain read APIs and map each UI action to a persisted, authorized operation.
6. Implement clinician workflows and then the patient portal.
7. Add controlled AI assistance only after the human review workflow is enforceable.
8. Complete organization administration, localization/RTL, accessibility, E2E testing, security, performance, observability, and operational documentation.

## Git state

- Working branch created: `phase-c/product-execution`.
- Branch base: `phase-b/world-class-product` at `47bef5d713ff8706e86a0d7286188cd6a8e482e8`.
- `main` was not modified.
- No merge or pull request was created.
- The separate stabilization experiment branch is not merged into this working branch.
