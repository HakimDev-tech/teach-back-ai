# Domain authorization — Phase B

## Source of truth
Supabase Auth establishes identity. PostgreSQL membership and assignment rows determine authorization. Client-supplied IDs are only selectors; they never grant access by themselves.

## Access model
- Owner/admin: may manage patient-clinician assignments. They do not automatically receive patient, care-plan, instruction, session, question, or response visibility.
- Clinician: may read and operate on clinical records only when they have an active `clinician` membership in the same organization and an active assignment to that patient.
- Suspended/revoked membership or revoked assignment removes access on the next database statement.
- Anonymous users have no grants on the domain tables.
- Patient-facing access is not implemented. No public route accepts patient identity or patient IDs as proof of access.

## RLS and grants
RLS is enabled on every Phase B public table. Table privileges are separately restricted. Sensitive writes use narrowly scoped RPCs: patient creation/assignment, instruction version creation/approval, question approval, session transitions, response draft saving and response submission. Application services use the authenticated SSR Supabase client; they do not use a service-role credential.

Authorization helpers live in the non-exposed `private` schema, use fixed search paths, and expose only scoped booleans. Clinical data access is assignment-based; administrative membership alone is insufficient.

## Security limitations
RLS and database tests are not a compliance certification. Rate limiting, MFA enforcement, audit-event history, patient authentication, data retention, consent, encryption/key management review, and jurisdiction-specific legal validation remain outside Phase B. Never use real patient data in this development environment.
