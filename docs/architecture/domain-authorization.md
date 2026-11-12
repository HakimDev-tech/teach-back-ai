# Domain authorization — Phase B

## Source of truth
Supabase Auth establishes identity. PostgreSQL membership and assignment rows determine authorization. Client-supplied IDs are only selectors; they never grant access by themselves.

## Access model
- Owner/admin: may manage patient-clinician assignments. They do not automatically receive patient, care-plan, instruction, session, question, or response visibility.
- Clinician: may read and operate on clinical records only when they have an active organization membership, an active unexpired verified clinical-capability grant, and an active assignment to that patient. The `clinician` membership role alone is not sufficient.
- Suspended/revoked membership, capability, or assignment removes access on the next database statement. Expired capability grants are denied even if their stored status has not yet been changed.
- Anonymous users have no grants on the domain tables.
- Patient-facing access is not implemented. No public route accepts patient identity or patient IDs as proof of access.

## RLS and grants
RLS is enabled on every Phase B public table. Table privileges are separately restricted. Sensitive writes use narrowly scoped RPCs: patient creation/assignment, instruction version creation/approval, question approval, session transitions, response draft saving and response submission. Application services use the authenticated SSR Supabase client; they do not use a service-role credential.

Authorization helpers live in the non-exposed `private` schema, use fixed search paths, and expose only scoped booleans. Clinical data access requires both a verified capability grant and an active patient assignment; neither a `clinician` membership role nor administrative membership alone is sufficient. Capability approval is currently an organization-level manual attestation, not external licensure verification.

## Security limitations
RLS and database tests are not a compliance certification. Rate limiting, MFA enforcement, audit-event history, patient authentication, data retention, consent, encryption/key management review, and jurisdiction-specific legal validation remain outside Phase B. Never use real patient data in this development environment.
