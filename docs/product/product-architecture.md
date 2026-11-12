# Teach-back AI — Product architecture and route map

## Product boundary

Teach-back AI is a communication and comprehension workflow, not a diagnostic or prescribing system.

- Clinicians author and approve medical instructions.
- Patients explain instructions in their own words.
- The system organizes responses and evidence.
- Clinicians review responses and approve clarifications.
- AI may assist with drafts and evidence summaries, but never approves clinical content or determines medical safety.

The PostgreSQL database remains authoritative for tenant isolation, clinical access, approval, immutable history, and state transitions.

## Role and capability model

Do not equate organization administration with clinical access.

| Capability | Owner | Admin | Clinician | Patient |
|---|---:|---:|---:|---:|
| Manage organization profile | Yes | Policy-based | No | No |
| Invite/manage organization members | Yes | Policy-based | No | No |
| View assigned clinical records | Only with explicit clinical capability and assignment | Only with explicit clinical capability and assignment | With active assignment | Own authorized patient record |
| Author/approve instructions | Only with clinical capability and assignment | Only with clinical capability and assignment | With active assignment | No |
| Review patient responses | Only with clinical capability and assignment | Only with clinical capability and assignment | With active assignment | Own submitted history only |
| Submit Teach-Back responses | No | No | No | Own active session |

The current single-role membership model does not support a solo practitioner who is both owner and clinician. Resolve this before implementing organization onboarding. A separate, explicitly granted clinical capability is preferable to implicitly granting clinical access to owners or administrators.

## Proposed route map

### Public and authentication

- `/` — product entry.
- `/sign-in` — sign in.
- `/sign-up` — account creation without automatic professional privileges.
- `/forgot-password` — password recovery.
- `/auth/callback` — verified auth callback.
- `/onboarding/organization` — create or join an organization after authorization checks.

### Clinician workspace

- `/clinician` — operational overview and actionable queue.
- `/clinician/patients` — assigned patient list.
- `/clinician/patients/new` — create patient.
- `/clinician/patients/[patientId]` — patient profile and authorized history.
- `/clinician/patients/[patientId]/care-plans/[carePlanId]` — care plan and instruction authoring.
- `/clinician/sessions` — session list and filters.
- `/clinician/sessions/[sessionId]` — session preparation and progress.
- `/clinician/reviews` — submitted responses awaiting clinician review.
- `/clinician/follow-ups` — clarifications and retry tasks.
- `/clinician/settings/profile` — professional profile.
- `/clinician/settings/organization` — organization settings, subject to role.
- `/clinician/settings/members` — membership and invitation management, subject to role.

### Patient portal

- `/patient` — patient home and active tasks.
- `/patient/sessions/[sessionId]` — session introduction and progress.
- `/patient/sessions/[sessionId]/instructions` — approved instructions.
- `/patient/sessions/[sessionId]/teach-back` — response capture and draft recovery.
- `/patient/history` — relevant completed sessions and clinician-approved clarifications.

The patient portal must not expose clinician-only notes, drafts, AI internal reasoning, organization administration data, or other patients' records.

### Organization administration

Organization administration should be presented within a dedicated settings area, not mixed into clinical patient navigation. It manages organization profile, membership invitations, explicit capabilities, and audit history. Administrative status alone must never grant clinical record access.

## Core user journeys

### Clinician onboarding

1. User creates an account and verifies email.
2. User creates or accepts an organization invitation.
3. Organization membership is activated only through an authorized process.
4. Clinical capability is granted explicitly and, where required, manually verified.
5. Clinician sees only patients with an active assignment.

### Patient creation and access

1. Authorized clinician creates a patient record.
2. An authorized invitation is issued to the patient or approved delegate.
3. Token is cryptographically random; only a hash is stored.
4. Invitation is single-use, expiring, revocable, and bound to the intended recipient.
5. Acceptance atomically links the authenticated identity to a narrowly scoped patient access grant.
6. Patient can access only their patient-facing session projection.

### Instruction authoring and approval

1. Clinician creates a care plan and instruction item.
2. Instruction content is saved as a draft version.
3. Clinician reviews and approves a specific version.
4. Approved versions become immutable.
5. Sessions snapshot the exact approved version; later edits create a new version.

### Teach-Back session

1. Clinician prepares a session and attaches approved instruction snapshots.
2. Clinician authors and approves questions.
3. Session becomes ready and is published.
4. Patient reads approved instructions and submits their own explanation.
5. Drafts can be resumed; submission is idempotent.
6. Clinician reviews each response attempt and records a structured decision.

### Review, clarification, and retry

This journey requires a domain extension before UI implementation:

- A review decision must reference a specific response attempt.
- Outcomes must distinguish understood, partially understood, not demonstrated, and unable to evaluate.
- Clinician clarification must be authored/approved by an authorized clinician and linked to the response that triggered it.
- Retry attempts must be sequential and immutable after submission.
- A session can complete only after the clinician has reviewed the latest required attempts.
- AI suggestions remain drafts and cannot create an approved clarification or complete a session.

## Required domain additions

Before enabling patient access or iterative review, design and test:

1. **Clinical capability grants** independent of organization administration roles.
2. **Organization invitations** with token hashing, expiration, revocation, email binding, and atomic acceptance.
3. **Patient access grants/invitations** with narrow patient scope and caregiver/delegate support policy.
4. **Response reviews** linked to immutable response attempts.
5. **Clinician clarifications** linked to reviewed attempts and authorized authors.
6. **Audit events** for access-sensitive and clinically significant actions.

Patient-facing RLS should be separate from clinician-facing RLS. Do not broaden the existing clinician access helper to expose internal clinical data to patients.

## API and persistence principles

- Server Components by default; client components only for interaction.
- Server-side authentication and authorization on every protected operation.
- Zod at API boundaries.
- PostgreSQL RPCs for atomic transitions and multi-row invariants.
- RLS and explicit grants as defense in depth.
- No browser service-role key.
- No client-side-only business rules.
- No fabricated production metrics or simulated successful integrations.
- All development and hackathon fixtures use synthetic patient data.

## Design system direction

The visual system should combine clinical trust with human warmth:

- Warm ivory canvas and quiet, readable surfaces.
- Deep forest green as the primary action color.
- Muted sage for supportive surfaces.
- Restrained terracotta for selected emphasis.
- Amber for attention and pending states.
- Charcoal text and high-contrast semantic statuses.
- Editorial display typography paired with highly legible interface typography.
- Logical CSS properties and explicit `dir` handling for Arabic.
- Purposeful motion with `prefers-reduced-motion` support.

Avoid generic blue hospital dashboards, excessive cards, ornamental gradients, and decorative metrics. Every displayed metric must come from authorized persisted data.

## Accessibility and localization requirements

- English, French, and Arabic from a centralized message catalog.
- RTL at the layout boundary, not per-component patches.
- Locale-aware dates and numbers.
- Semantic forms, keyboard navigation, visible focus, and screen-reader announcements.
- WCAG 2.2 AA contrast and interaction checks.
- Mobile-first patient flow with readable instructions and generous touch targets.
- No SVG text or untranslated strings embedded in components.

## Implementation order

1. Repository stabilization and generated-file integration.
2. Domain decisions for clinical capability, patient identity, invitations, reviews, and retries.
3. Design tokens, reusable primitives, and responsive shells.
4. Authentication and onboarding.
5. Clinician workspace.
6. Patient portal.
7. Human review and clarification cycle.
8. AI assistance with abstention and traceable evidence.
9. Organization administration.
10. Localization, accessibility, E2E, security, performance, and operations hardening.
