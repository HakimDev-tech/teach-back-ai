# UI-to-API-to-domain traceability

**Baseline:** Phase C product execution branch. This document records what is actually connected today and what must exist before the clinician and patient journeys can be considered functional.

## 1. Current interface actions

| Interface | Visible action | Actual behavior | Status |
|---|---|---|---|
| Public landing page | Sign in | Navigates to sign-in page | Functional navigation |
| Public landing page | Create professional account | Navigates to sign-up page | Functional navigation |
| Sign-up | Create account | Supabase Auth sign-up; profile is provisioned by database trigger | Persisted |
| Sign-in | Sign in | Supabase Auth password sign-in | Persisted |
| Auth callback | Confirm account/session | Exchanges Supabase auth code and validates same-origin redirect | Implemented |
| Clinician shell | Sign out | POSTs to sign-out route and calls Supabase sign-out | Implemented |
| Clinician overview | View active memberships | Server Component reads current user's active organization memberships under RLS | Read-only |
| Clinician overview | View clinical access explanation | Static explanation of the current least-privilege model | Informational only |

The current interface does not yet expose patient creation, care-plan authoring, instruction approval, session preparation, response review, patient access, or organization administration. Do not describe those journeys as implemented merely because API/database primitives exist.

## 2. Existing API operation trace

| HTTP operation | API route | Application/service | Repository or database operation | Authorization boundary |
|---|---|---|---|---|
| GET | /api/patients?organizationId=… | PatientService.list | SELECT patients | Authenticated clinician with active assignment; RLS |
| POST | /api/patients | PatientService.create | RPC create_patient | Active clinician membership; creates patient and creator assignment atomically |
| GET | /api/patients/:id | PatientService.get | SELECT patients | Active assignment; tenant-scoped query and RLS |
| POST | /api/patients/:id/assignments | PatientService.assign | RPC assign_patient_clinician | Active owner/admin; target must be active clinician |
| DELETE | /api/patients/:id/assignments/:assignmentId | PatientService.revoke | RPC revoke_patient_assignment after assignment/patient consistency lookup | Active owner/admin; assignment revocation |
| POST | /api/care-plans | InstructionService.createCarePlan | INSERT care_plans | Active assigned clinician; created_by derived from authenticated user |
| POST | /api/care-plans/:id/instructions | InstructionService.createInstructionItem | INSERT instruction_items | Active assigned clinician; RLS checks care-plan/patient scope |
| POST | /api/instructions/:id/versions | InstructionService.createVersion | RPC create_instruction_version | Active assigned clinician; immutable versioning |
| POST | /api/instruction-versions/:id/approve | InstructionService.approveVersion | RPC approve_instruction_version | Active assigned clinician; approval and supersession are atomic |
| PATCH | /api/questions/:id | SessionService.updateQuestion | UPDATE questions | Active assigned clinician; draft-only policy, column grants, trigger |
| POST | /api/questions/:id/approve | SessionService.approveQuestion | RPC approve_question | Active assigned clinician; approved question becomes immutable |
| POST | /api/sessions | SessionService.create | INSERT teachback_sessions | Active assigned clinician; session begins as draft |
| POST | /api/sessions/:id/instructions | SessionService.addInstructionSnapshot | INSERT session_instructions | Active assigned clinician; approved version and same-patient validation |
| POST | /api/sessions/:id/questions | SessionService.addQuestion | INSERT questions | Active assigned clinician; question must reference a session snapshot |
| POST | /api/sessions/:id/transition | SessionService.transition | RPC transition_session | Active assigned clinician; row lock and optimistic version |
| POST | /api/sessions/:id/responses | ResponseService.saveDraft | RPC save_response_draft | Currently clinician-only; not patient self-service |
| POST | /api/responses/:id/submit | ResponseService.submit | RPC submit_response | Currently clinician-only; not patient self-service |

All listed route handlers authenticate with the server-side Supabase client and validate route/body inputs with Zod. Database RLS, grants, triggers, and RPC checks remain authoritative.

## 3. Missing API contracts

### Clinician read operations

- List/detail care plans by patient.
- List instruction items and their version history.
- Read an instruction version and approval provenance.
- List sessions and read a session with its exact instruction/question snapshots.
- Read submitted responses and their attempt history.
- Read response reviews and approved clarifications.
- Read follow-up tasks and activity history.

### Clinician write operations

- Update/archive care plans through explicit domain operations.
- Reject or retire draft questions with documented semantics.
- Claim/release a review.
- Record immutable response reviews.
- Author and approve clarifications.
- Request a retry and record follow-up disposition.
- Complete a session only after database-enforced review invariants.
- Create/revoke patient invitations and patient access grants.
- Create/revoke organization invitations.
- Request, verify, suspend, and revoke clinical capability.

### Patient operations

- Read own patient-safe profile and active sessions.
- Read only published approved instructions/questions.
- Start a published session.
- Save and resume a response draft.
- Submit a response and the current response round.
- Read clinician-approved clarifications.
- Start an authorized retry.
- Read own relevant session history.

These must use patient-specific RPCs and RLS. Existing clinician response endpoints must not be reused as patient endpoints.

### Organization and account operations

- Create an organization and show the result in an onboarding flow.
- Invite members by email-bound one-time code.
- Accept/revoke invitations.
- Manage allowed roles and independent clinical capability.
- Profile update and password recovery.
- Clear email-verification and invitation-delivery states.

## 4. Confirmed API contract issues and hardening

- A PostgreSQL unique violation (23505) is not always a duplicate response submission. The public mapping is now generic RESOURCE_CONFLICT rather than the incorrect DUPLICATE_SUBMISSION label.
- Malformed JSON previously fell through to INTERNAL_ERROR. A shared readJsonBody helper now maps malformed request JSON to HTTP 400 INVALID_JSON and is used by JSON-writing routes.
- The patient list currently has no cursor/limit contract. Add bounded pagination before exposing large organizations.
- The patient list returns all rows permitted by the Supabase API row cap; the UI must not imply that this is a complete list without pagination metadata.
- No rate limiting or request-correlation/audit instrumentation exists yet.
- API contracts are not yet published as OpenAPI or generated client types.

## 5. Required UI-to-domain acceptance rule

A user-facing operation is complete only when the following trace exists:

1. An accessible UI control expresses the action and its current state.
2. The control calls one explicit API contract.
3. The route authenticates the actor and validates the input.
4. The application service enforces use-case orchestration.
5. The repository performs scoped persistence or calls an atomic RPC.
6. PostgreSQL constraints, grants, RLS, triggers, and RPC checks enforce the invariant.
7. The UI reflects the persisted result, including failure, retry, and empty states.
8. Tests cover success, unauthorized access, cross-tenant access, invalid transitions, and persistence.

A toast without a successful persisted operation does not satisfy this contract. A page with static sample metrics does not satisfy it. A disabled feature must be presented as unavailable, not as completed.

## 6. Implementation order

1. Add missing domain read contracts required by the clinician workspace.
2. Implement clinical capability and invitation workflows.
3. Implement patient access grants and patient-safe read/RPC contracts.
4. Implement response review, approved clarification, retry, and follow-up operations.
5. Build clinician screens against the real read/write contracts.
6. Build the patient portal against patient-only contracts.
7. Add E2E tests that traverse the UI through the database.
