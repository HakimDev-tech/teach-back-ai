# Domain workflows — Phase B

## Patient creation and assignment
1. An authenticated active clinician calls `POST /api/patients`.
2. PostgreSQL verifies active clinician membership.
3. `create_patient` inserts the patient and active self-assignment in one transaction.
4. Owners/admins can assign another active clinician with `assign_patient_clinician`; they do not thereby gain access to the clinical record.
5. Assignment revocation is a status change, not a delete.

## Care plan and instructions
1. An assigned clinician creates a draft care plan.
2. The clinician creates a logical instruction item.
3. `create_instruction_version` locks the item and allocates the next version number.
4. The clinician approves the latest draft through `approve_instruction_version`.
5. Approval records actor and timestamp. A previously approved version may become superseded, but its content and provenance remain immutable.

## Questions and session preparation
1. The clinician creates a draft session for an assigned patient.
2. The clinician adds references to approved instruction versions through `session_instructions`.
3. Questions are manually entered for that session and must reference one of its instruction snapshots.
4. Each question is approved explicitly.
5. `draft → ready` is permitted only when approved instruction snapshots exist, every snapshot has at least one approved question referencing that exact item/version, and every question in the session is approved. This invariant is enforced by migration `20261112140115_phase_c_instruction_question_coverage.sql`.

## Publication, response and review
- `ready → in_progress` publishes and starts the session atomically.
- The authenticated internal workflow saves drafts through `save_response_draft`, using a client-generated UUID idempotency key.
- `submit_response` locks the session before the response and makes the submission immutable.
- `in_progress → awaiting_review` requires a submitted response for every approved question.
- The current clinician-only state machine permits `awaiting_review → review_in_progress → completed`, but completion is not yet gated by persisted response-review records.
- `review_in_progress → awaiting_review` currently returns work to the review queue; it is not a patient retry or a persisted clarification workflow.
- Patient identity, patient-specific response RPCs, response_reviews, clinician_clarifications, and database-enforced retry sequencing are not implemented yet.
- Cancellation and expiry are controlled transitions. Expiry requires a configured expiry time that has elapsed.
- Terminal states (`completed`, `cancelled`, `expired`) cannot be reopened.

No AI operation may approve instructions/questions or complete a session.
