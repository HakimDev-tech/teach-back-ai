# Supabase migration workflow

## Creating a migration scaffold

Next planned additive migration: `phase_c_clinical_capability_verification`.

Create a normal reviewable commit whose subject contains:

    [new-migration: descriptive_snake_case_name]

The CI workflow runs the pinned Supabase CLI and executes:

    supabase migration new descriptive_snake_case_name

Supabase CLI generates the timestamped filename. The workflow uploads the timestamped scaffold as a short-lived artifact immediately after creation, before starting the local database. It later packages all generated/modified files as a second artifact. It does not commit generated migrations automatically.

## Migration requirements

- Never edit an already-applied migration to change domain behavior.
- Keep new schema changes additive unless a reviewed migration plan explicitly requires otherwise.
- Review constraints, indexes, locks, grants, RLS policies, SECURITY DEFINER search paths, and data/backfill behavior.
- Run a clean database reset so the complete migration history is applied in order.
- Add pgTAP coverage for valid, invalid, cross-tenant, and concurrent behavior.
- Keep the migration and its tests in the same reviewed branch change.
- Do not merge a migration while its database tests are failing or its failure is unexplained.

## CI behavior

Independent Node checks continue after a database test failure, provided dependency installation succeeded. Generated database types run only after a successful clean database reset. Artifacts are uploaded only when packaging succeeds. A failed prerequisite does not trigger a cascade of meaningless downstream failures.

Generated artifacts are not repository commits. Review and integrate them explicitly.
