# Phase C — Domain extension design

**Status:** implementation in progress on phase-c/world-class-product; explicit capability migration and database tests are being hardened  
**Baseline:** 04ee47470dc94630635ced640a50dbeebcc05396  
**Scope:** clinical capability, organization/patient invitations, patient identity and access, response review, clinician clarification, retries, and clinical auditability.

## 1. Purpose and constraints

The existing Phase B domain is a clinician-only foundation. This design extends it without replacing its valid invariants.

PostgreSQL remains authoritative for organization isolation, clinical authorization, invitation acceptance, patient identity linkage, approved-content immutability, response-attempt sequencing, review evidence, and session transitions.

The application must never use an organization-admin role as a shortcut to clinical access. Patients must never receive access to clinician-only notes, drafts, internal AI output, or another patient's records.

All development and hackathon fixtures remain synthetic. No real patient information is to be introduced during implementation or testing.

## 2. Decision A — Separate organization administration from clinical capability

### Existing constraint

organization_memberships permits exactly one role per user and organization: owner, admin, or clinician. Clinical access currently requires the clinician role plus an active patient assignment. That role is not professional verification: an owner/admin can assign it without a credential review. The role-only shortcut is being removed.

This is a correct least-privilege boundary, but it cannot represent an owner who is also a clinician.

### Recommended extension

Keep organization_memberships as the organization membership and governance record. Add an independent organization_clinical_capabilities record for every member who is explicitly authorized to perform clinical work in that organization. A clinician membership role is organizational metadata only and never grants clinical access by itself.

Conceptual fields:

| Field | Purpose |
|---|---|
| organization_id, user_id | Composite reference to an existing organization membership |
| status | pending, active, suspended, revoked |
| professional_type | Minimal professional category required by the workflow |
| verification_status | pending, verified, rejected, expired |
| verification_method | Manual or documented external verification method |
| verified_by, verified_at | Verification provenance |
| granted_by, granted_at | Grant provenance |
| expires_at, revoked_at | Time-bounded access lifecycle |

Do not collect or retain a full professional license identifier unless a documented legal/operational need requires it. Prefer minimal verification metadata and a protected external reference.

### Authorization rule

A user may read or modify clinical records only when all of the following hold:

1. The user has an active organization membership.
2. The user has an active, verified clinical-capability grant. No membership role, including clinician, is an exception.
3. The user has an active assignment to the target patient.
4. The target patient and organization are active and match the record being accessed.

Owners/admins retain assignment and organization-management permissions but gain no clinical access from those roles alone. Every clinician, including a member whose organization role is clinician, must receive an explicit capability approval. Existing clinician memberships are not silently backfilled; they must be reviewed before clinical access is restored.

The current implementation supports only the `manual_review` verification method. This is an organization-level attestation recorded by an independent owner/admin; it is **not** an external professional-registry check, proof of licensure, or regulatory credential certification. The UI and documentation must not imply otherwise. External credential verification remains deferred until a real provider or documented manual-review operating procedure exists.

A user must not approve their own clinical-capability request. A solo-practitioner owner therefore needs an independent verification path; self-approval is not an acceptable shortcut. For synthetic hackathon fixtures, verified capability may be seeded explicitly and identified as test data.

Update authorization helpers and assignment validation atomically. Do not scatter role checks across API routes.

## 3. Decision B — Secure invitations without bearer secrets in URLs

The security requirement excludes sensitive information from URLs and logs. Therefore, do not put a raw patient-invitation token in a query string, path, or fragment.

### Invitation-code flow

Use an email-bound, high-entropy, one-time invitation code:

1. An authorized clinician creates an invitation for a specific patient and recipient email.
2. The server generates at least 128 bits of cryptographically secure randomness.
3. The raw code is delivered through an InvitationDelivery application port. It is never persisted.
4. The database stores only a keyed digest of the code and a keyed digest of the normalized recipient email.
5. The patient signs in or creates an account, verifies the email address, and enters the code in the patient invitation screen.
6. The server sends the code and authenticated user context to an atomic acceptance RPC.
7. The RPC verifies email binding, expiry, revocation, attempt limits, and single-use state; it creates the patient access grant and consumes the invitation in one transaction.

Recommended invitation fields:

- organization_id and patient_id;
- recipient_email_hash and invitation_code_hash;
- created_by and created_at;
- expires_at;
- attempt_count and locked_until;
- consumed_at and accepted_user_id;
- revoked_at and revocation reason.

The raw email is passed transiently to the delivery adapter and is not stored in the invitation record. Use a server-only HMAC secret for recipient-email and code digests. Rotate the secret with an explicit invalidation/reissue policy.

### Delivery behavior

The delivery adapter must have an explicit configured/unconfigured state.

- If an email provider is configured, report delivery only after the provider confirms acceptance.
- If no provider is configured, do not show “email sent.” Offer a controlled one-time manual code handoff to an authorized clinician, with an explicit warning that delivery is manual.
- Never log the raw code, full recipient email, or invitation URL.
- Reissuing an invitation revokes the prior code and creates a new digest.

Apply rate limits to code attempts by invitation, authenticated account, and request source. Use generic error responses that do not reveal whether a patient or email exists.

The same pattern can be reused for organization invitations. Organization invitations may create only allowed member roles; ownership transfer remains a separate controlled operation. An organization invitation does not automatically grant clinical capability.

## 4. Decision C — Separate patient identity from the patient record

Do not place an Auth user ID directly on patients as the only identity mechanism. Use a dedicated access-grant relation so identity linkage and revocation are auditable.

### Patient access grants

Add patient_access_grants with:

- organization_id, patient_id, user_id;
- relationship type (initial release: self only);
- status (active/revoked);
- granted_by, granted_at;
- revoked_by, revoked_at.

The initial release supports one authenticated patient identity per patient. Caregiver/delegate access is deliberately deferred until its consent, scope, and revocation rules are designed.

The patient identity must be authenticated and email-verified before invitation acceptance. Invitation acceptance must bind the authenticated user's verified email to the invitation's recipient-email digest.

### Patient authorization helper

Add a narrowly scoped helper such as private.can_access_patient_as_patient(org_id, patient_id). It must verify the active grant for auth.uid(), active patient state, and tenant match.

Do not broaden private.can_access_patient, which is the clinician/assignment boundary. Clinician and patient access are distinct authorization paths.

### Patient-facing data projection

Patients should not receive broad direct access to the internal clinical tables.

Prefer dedicated security_invoker=true views or narrowly scoped RPCs that expose only:

- the patient's own session status and progress;
- published, approved instructions attached to that session;
- approved patient-facing questions;
- the patient's own response drafts and submissions;
- clinician-approved clarifications.

Do not expose draft instructions, unapproved questions, clinician-only notes, response-review rationale, audit metadata, AI internal artifacts, or organization administration records.

Every patient-facing view/RPC must have explicit grants and RLS coverage. A view must not accidentally bypass RLS.

## 5. Decision D — Make patient response capture a separate trust boundary

The existing save_response_draft and submit_response RPCs are clinician-scoped. They call the clinician patient-access helper and record the authenticated clinician as recorded_by. Do not simply make these RPCs callable by patients.

Add dedicated patient RPCs:

- patient_start_session(session_id, expected_version)
- patient_save_response_draft(session_id, question_id, idempotency_key, response_text)
- patient_submit_response(response_id)
- patient_submit_session(session_id, expected_version)

The patient RPCs must derive the user and patient identity from auth.uid(); never trust a client-supplied patient ID, organization ID, actor ID, or attempt number.

They must verify:
- active patient access grant;
- session belongs to that patient and organization;
- session is published and currently accepting patient work;
- question is approved and belongs to the exact session/instruction snapshot;
- session is not expired or cancelled;
- response belongs to the authenticated patient/session;
- response submission is idempotent.

The browser may generate an idempotency UUID, but PostgreSQL owns attempt numbering and validates the idempotency key's scope.

## 6. Decision E — Persist response-level clinical review and clarification

The current responses.attempt_number is positive and unique per session/question, but it is client-supplied to the RPC. The current domain has no durable response-review entity or clinician-approved clarification entity. The current session can move from review_in_progress to completed without persisted evidence that every response was reviewed.

This must be corrected before the patient portal is enabled.

### Response reviews

Add an immutable response_reviews entity linked to one submitted response attempt:

- organization_id, session_id, question_id, response_id;
- reviewer_user_id and reviewed_at;
- outcome: understood, partially_understood, not_demonstrated, unable_to_evaluate;
- concise clinician-authored rationale;
- optional evidence reference to the response text;
- amendment/supersession reference if a review correction is required.

A review is an explicit clinician decision. AI output must never create or approve a review.

### Clinician clarifications

Add clinician_clarifications linked to the response review that triggered it:

- organization_id, session_id, question_id, response_id, review_id;
- patient-facing clarification text;
- status: draft, approved, rejected;
- authored_by, approved_by, approved_at;
- immutable approved content and version/provenance.

Only an authorized clinician with an active patient assignment may author/approve a clarification. An approved clarification is immutable. Corrections create a new version or superseding record; they do not overwrite the approved text.

### Review outcomes

- understood: no retry is required for that response.
- partially_understood or not_demonstrated: an approved clarification is required before the patient may retry that question.
- unable_to_evaluate: the system must abstain from an automatic conclusion. The clinician must record an explicit follow-up disposition; the platform must not infer medical safety or close the case automatically.

Do not store hidden model reasoning as clinical evidence. Store only concise, reviewable evidence and clinician-authored decisions.

## 7. Decision F — Enforce sequential retries and session completion in PostgreSQL

### Response attempt rules

The database, not the browser, assigns attempt_number.

- First response for a question is attempt 1.
- A later attempt is allowed only after the previous submitted attempt has a final clinician review.
- A retry after partially_understood or not_demonstrated requires an approved clarification linked to that exact prior response/review.
- A new attempt number is exactly the previous attempt number plus one.
- The same idempotency key can only identify the same question and same attempt.
- Submitted attempts remain immutable. A correction is a new attempt or an explicit amendment record, never an overwrite.

The current RPC's caller-supplied attempt number must be removed from the patient-facing contract and validated/derived inside the database function.

Before a session becomes ready, every session instruction snapshot must be covered by at least one approved question. The current Phase B transition checks only that at least one approved question exists overall; it does not enforce per-instruction coverage.

### Session lifecycle

Recommended lifecycle:

    draft
      -> ready                 clinician publishes approved instructions/questions
      -> in_progress           patient starts the session
      -> awaiting_review       patient submits all currently required responses
      -> review_in_progress    clinician claims/reviews the submitted work
           -> completed        every required latest attempt is reviewed and resolved
           -> retry_ready      approved clarification(s) are ready for patient retry
      retry_ready
      -> in_progress           patient starts the next response attempt

Cancellation and expiry remain explicit terminal transitions from allowed non-terminal states.

Patient-triggered transitions must use patient-specific RPCs. Clinician review and publication transitions must use clinician-specific RPCs. Do not allow a generic client-supplied target_status to cross actor boundaries.

### Completion invariant

A session can be completed only when:
- every required question has a latest submitted response;
- every latest response has a persisted clinician review;
- no response requiring clarification is missing an approved clarification and subsequent retry;
- no unable_to_evaluate response is left without an explicit clinician follow-up disposition.

Use row locks and optimistic session versions to prevent concurrent review/transition races. If multiple clinicians can review the same session, persist the review claimant/lease or use an equivalent atomic claim operation.

## 8. Decision G — Add append-only clinical audit events

Add a narrowly scoped append-only clinical audit record for clinically significant operations, including:

- invitation creation, acceptance, revocation, and access-grant changes;
- patient access and assignment changes;
- instruction creation and approval;
- session publication, patient start, response submission;
- response review, clarification approval, retry, completion, cancellation, and expiry;
- clinical-capability grants, suspension, and revocation.

Audit events should include actor, organization, patient/resource references, action, timestamp, request/correlation ID, and minimal structured metadata.

Never copy response text, instruction content, invitation codes, raw email addresses, access tokens, secrets, or unnecessary patient identifiers into event metadata.

Administrative audit access and clinical audit access must remain separate. Organization admins must not gain access to clinical records merely because they can inspect organization administration events.

No application role should be able to update or delete audit history. Writes should occur atomically with the domain operation or through trusted database triggers/RPCs.

## 9. Decision H — Keep AI downstream of the human review model

AI is a later phase and consumes the approved domain model; it does not own it.

- Keep provider calls server-side behind an application interface.
- Store evaluations separately from clinician reviews.
- Bind every evaluation to the exact response attempt and instruction version.
- Store provider/model version, prompt/schema version, timestamps, structured result, and abstention state.
- Require schema validation and strict size/time limits.
- Verify any quoted evidence is an exact excerpt of the patient's response.
- Do not store hidden chain-of-thought.
- Present suggestions as drafts. Only a clinician may create a review decision or approve clarification.
- AI must not transition sessions, prescribe, diagnose, or determine medical safety.

## 10. Additive migration and verification sequence

Do not rewrite or delete the Phase A/B migrations. The first additive migration is named phase_c_instruction_question_coverage and closes the publication invariant before patient access is enabled. Implement subsequent additive migrations in this order:

1. Clinical capability records and authorization-helper extension, with explicit compatibility/backfill behavior.
2. Organization invitations and patient invitation codes, plus patient access grants.
3. Patient-specific RLS policies, safe projections, and patient RPCs.
4. Response reviews, clarifications, audit events, and immutable-history guards.
5. Database-owned attempt sequencing and revised session state transitions.
6. API contracts, repositories, services, and user interfaces.
7. AI evaluation tables/adapters only after human review is complete.

Each migration must be tested from a clean database and against the existing schema. Review locking, indexes, grants, RLS policy composition, rollback/forward-recovery implications, and existing synthetic fixtures before merging.

### Required database tests

- Owner/admin without clinical capability cannot read patient data.
- Owner/admin with explicit verified capability and active assignment can access only assigned patients.
- Clinician without active assignment cannot access the patient.
- Revoked/suspended clinical capability immediately removes clinical access.
- Invitation code is email-bound, expires, is single-use, is revocable, and cannot be brute-forced indefinitely.
- Two concurrent invitation acceptances produce only one grant.
- Patient A cannot read or mutate Patient B's records, even in the same organization.
- Patient cannot read drafts, internal reviews, unapproved clarifications, or AI evaluation artifacts.
- Patient can read only approved published instructions/questions and their own response data.
- Patient cannot submit to a cancelled, expired, unpublished, or another patient's session.
- Every instruction snapshot in a published session has at least one approved question.
- Response attempts are sequential and cannot skip/reuse attempt numbers.
- Same idempotency key returns the same attempt; a different payload/attempt cannot reuse it.
- Submitted responses, reviews, and approved clarifications are immutable.
- Session cannot complete with missing reviews, unresolved clarification, or an unhandled unable-to-evaluate outcome.
- Concurrent review/transition operations respect version/claim locks.

### Required application tests

- Clinician onboarding and capability request/review.
- Organization invitation acceptance.
- Patient invitation creation, delivery fallback, acceptance, and revocation.
- Patient session start, draft recovery, submit, interruption, and retry.
- Clinician response review, clarification approval, and follow-up.
- No false “email sent” or “saved” confirmation when the external operation did not succeed.

## 11. Explicitly deferred

- Caregiver/delegate access until consent and scope rules are designed.
- Automatic credential verification against external professional registries until a verified integration is available.
- Any autonomous AI approval or clinical decision.
- Production compliance claims until a legal, technical, and operational assessment exists.

## Decision summary

The recommended architecture preserves the current tenant and assignment model while adding independent clinical capability, email-bound one-time invitation codes, patient-specific access grants, dedicated patient RPCs, immutable response reviews, clinician-approved clarifications, database-enforced retry sequencing, and append-only audit events.

This is the minimum coherent domain extension required before patient self-service and the full Teach-Back review loop can be implemented safely.
