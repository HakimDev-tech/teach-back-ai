# Security model — Phase A

## Authentication
Supabase Auth manages credentials. The app uses cookie-based `@supabase/ssr` clients and the Next.js 16 `proxy.ts` session-refresh entry point. Proxy refresh uses `getClaims()`; protected server routes use `getUser()` to verify identity. Do not authorize from `getSession()` alone.

## Roles and tenant isolation
Professional roles exist only in organization memberships: owner, admin, clinician. Active membership is required. Patient access will be modeled separately in a later phase. Client-supplied organization IDs never grant access by themselves.

## RLS and GRANT
RLS is enabled on all three public foundation tables. Table privileges are separately revoked and granted. Profile UPDATE is column-limited to full_name/avatar_url. Organizations are readable by active members and updateable by active owners/admins. Membership reads are tenant-scoped; direct membership insertion only permits adding clinician roles by an active owner/admin. Owner creation and transfer use dedicated RPCs.

## SECURITY DEFINER functions
Membership helper functions live in non-exposed `private` schema to avoid recursive RLS. Functions use a fixed empty search_path, fully qualified object names, and restricted EXECUTE grants. Organization creation and ownership transfer are narrowly scoped public RPCs with authenticated identity checks.

## Last-owner protection
A trigger blocks deletion, demotion, or suspension of the final active owner. The transfer function promotes the target before demoting the current owner. Concurrency and full authenticated-JWT behavior still require integration testing before production use.

## Credentials and limitations
No service-role/secret client is created. Browser code uses only the publishable key. Local email confirmation is disabled for convenience and must be explicitly configured for hosted environments. Rate limiting, MFA, recovery UX, audit logging, monitoring, retention, and compliance review are not implemented. The current pgTAP suite is a schema/privilege baseline, not exhaustive adversarial RLS coverage.
