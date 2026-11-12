-- Return only the caller's own clinical capability status, including database-evaluated expiry.
-- The function remains SECURITY INVOKER so the table's self/admin RLS policy is still enforced.

create or replace function public.list_my_clinical_capabilities()
returns table (
  id uuid,
  organization_id uuid,
  professional_type text,
  status text,
  verification_status text,
  expires_at timestamptz,
  created_at timestamptz,
  is_expired boolean
)
language sql
stable
security invoker
set search_path = ''
as $body$
  select
    c.id,
    c.organization_id,
    c.professional_type,
    c.status,
    c.verification_status,
    c.expires_at,
    c.created_at,
    c.expires_at is not null and c.expires_at <= pg_catalog.now() as is_expired
  from public.organization_clinical_capabilities c
  where c.user_id = (select auth.uid())
  order by c.created_at desc, c.id desc;
$body$;

revoke all on function public.list_my_clinical_capabilities() from public, anon;
grant execute on function public.list_my_clinical_capabilities() to authenticated;

comment on function public.list_my_clinical_capabilities() is
  'Returns the authenticated member own capability records and database-evaluated expiry status under RLS.';
