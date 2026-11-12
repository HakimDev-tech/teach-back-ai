# Data integrity — Phase B

## Tenant and relational integrity
All clinical tables carry `organization_id`. Composite foreign keys bind patient, care plan, assignment, instruction, session, question, and response relationships to the same tenant. A database trigger also ensures a session snapshot references an instruction version from that exact patient, not merely another patient in the same organization. The question-to-snapshot relationship also binds the instruction item and version, preventing a version from being paired with a different item.

Deletion of clinical parents is restricted. Assignments are revoked; patients and care plans are archived. Session snapshots and instruction versions are retained. Submitted responses cannot be updated or deleted by normal application roles.

## Versioning and immutability
Instruction version numbers are unique per instruction item. Creation locks the instruction item before computing the next number. Approval locks the item and version, and only the latest draft may be approved. Approved content, creator, approval actor, and approval timestamp cannot be rewritten. A later approved version changes the prior version's lifecycle status to superseded without changing its content.

Session instructions are references to exact approved versions. Snapshot rows and questions are frozen once the session leaves draft. Question order is unique within a session. Before a session can become ready, every instruction snapshot must have at least one approved question referencing that exact instruction item and version; a question for one snapshot cannot satisfy another snapshot.

## Transactions and concurrency
- Patient + creator assignment: one security-definer transaction.
- Instruction version allocation: row lock on instruction item.
- Instruction approval: instruction item lock followed by version lock.
- Session transitions: session row lock, expected-version comparison, invariant validation, update and version increment.
- Question approval and writes: session lock precedes question lock.
- Response draft and submission: session lock precedes response lock.
- Response submission is idempotent for the same response ID; draft saving is idempotent by (organization, session, idempotency key).

The consistent lock order for session child operations is session before question/response. No external network call occurs in a transaction. The session readiness coverage check executes under the existing session row lock.

## Limits
The pgTAP suite now has 105 assertions covering sequential state and authorization behavior, including per-instruction question coverage. True multi-connection race tests are still required before claiming concurrent behavior verified. Response attempt numbers are still caller-supplied and sequential retry is not yet enforced. Patient-specific RPCs and persisted response reviews/clarifications are not implemented. Expiration currently requires an explicit caller; no scheduler is installed. Retention periods and legal holds have not been defined.
