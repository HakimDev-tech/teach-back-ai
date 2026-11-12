# Domain model — Phase B

## Scope
Phase B adds the clinical business-domain persistence layer and authenticated HTTP boundaries. It does not add AI, patient portal credentials, notifications, or clinical decision support. All development/test records must be synthetic.

## Entities and ownership
- `patients`: one organization-scoped patient record. No cross-organization identity linking is inferred.
- `organization_clinical_capabilities`: explicit, time-bounded organization-level clinical authorization for a member. A `clinician` membership role alone is not authorization; approval provenance is retained.
- `patient_clinician_assignments`: time-relevant access relationship between one patient and one member with active clinical capability. Revocation is retained as history.
- `care_plans`: an organizationally scoped grouping for one patient.
- `instruction_items`: stable logical instruction identity within a care plan.
- `instruction_versions`: immutable approved snapshots, sequential per item. A new edit is a new draft version.
- `teachback_sessions`: a workflow aggregate with an optimistic `version`.
- `session_instructions`: references the exact approved instruction versions used by a session. Medical text is not copied into the snapshot.
- `questions`: session-specific question text tied to one exact instruction version.
- `responses`: append-preserving attempts, each with a stable idempotency key. Draft text is mutable; submitted content is immutable.

## Aggregate boundaries
Patient and assignment writes are coordinated by `create_patient`, which requires active verified clinical capability and creates the patient and creator assignment atomically. Assignment management is exposed through controlled RPCs. Care plans and instruction items are patient-scoped. Instruction version creation serializes on the logical instruction row. A session owns its instruction references, questions, and responses; those child records cannot be changed after the session leaves draft.

## Deliberate decisions
Questions are session-specific rather than global instruction templates. The same approved instruction version can be referenced by multiple sessions, while each session retains its own approved questions and ordering. A session snapshot references exact version IDs, so a later instruction version does not rewrite history.

The Phase B internal response path records a response under an authenticated, assigned clinician context. It is not a patient portal and must not be exposed as public patient access. A separate patient identity/access mechanism is required before patient self-service.

## Deferred
AI extraction, AI question generation, evaluation, clarification, patient access tokens, messaging, and clinical review records are deferred. The session state includes review states only to preserve the domain lifecycle.
