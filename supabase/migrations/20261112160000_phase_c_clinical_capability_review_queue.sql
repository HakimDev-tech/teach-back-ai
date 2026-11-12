-- Expose a minimal, organization-scoped review queue to active owners/admins only.
-- No email, phone, or clinical record data is returned.

create or replace function public.list_clinical_capability_requests(target_org uuid)
returns table (
  capability_id uuid,
  user_id uuid,
  display_name text,
  professional_type text,
  status text,
  verification_status text,
  requested_at timestamptz,
  expires_at timestamptz,
  verification_method text
)
language plpgsql
stable
security definer
set search_path = ''
as $body$
begin
  if not private.can_manage_assignments(target_org) then
    raise exception 'organization owner/admin permission required'
      using errcode = '42501';
  end if;

  return query
  select
    c.id,
    c.user_id,
    coalesce(nullif(btrim(p.full_name), ''), 'Organization member'),
    c.professional_type,
    c.status,
    c.verification_status,
    c.created_at,
    c.expires_at,
    c.verification_method
  from public.organization_clinical_capabilities c
  left join public.profiles p on p.id = c.user_id
  where c.organization_id = target_org
    and c.status = 'pending'
  order by c.created_at desc, c.id desc
  limit 100;
end;
$body$;

revoke all on function public.list_clinical_capability_requests(uuid) from public, anon;
grant execute on function public.list_clinical_capability_requests(uuid) to authenticated;

comment on function public.list_clinical_capability_requests(uuid) is
  'Returns minimal clinical-capability review metadata to active organization owners/admins only.';
