-- Phase C: verified clinical capability for owner/admin dual-role work.

create table private.platform_verifiers (
  user_id uuid primary key references auth.users(id) on delete cascade,
  active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default pg_catalog.now()
);

alter table private.platform_verifiers enable row level security;
revoke all on table private.platform_verifiers from public, anon, authenticated, service_role;

create table public.organization_clinical_capability_requests (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  user_id uuid not null,
  professional_type text not null,
  verification_method text not null,
  status text not null default 'pending',
  reviewed_by uuid references auth.users(id) on delete restrict,
  reviewed_at timestamptz,
  granted_by uuid references auth.users(id) on delete restrict,
  granted_at timestamptz,
  revoked_by uuid references auth.users(id) on delete restrict,
  revoked_at timestamptz,
  expired_by uuid references auth.users(id) on delete restrict,
  expired_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  constraint organization_clinical_capability_membership_fk
    foreign key (organization_id, user_id)
    references public.organization_memberships(organization_id, user_id)
    on delete restrict,
  constraint organization_clinical_capability_professional_type_check
    check (char_length(btrim(professional_type)) between 2 and 80),
  constraint organization_clinical_capability_method_check
    check (verification_method in ('professional_registry', 'document_review', 'institutional_confirmation')),
  constraint organization_clinical_capability_status_check
    check (status in ('pending', 'verified', 'active', 'rejected', 'revoked', 'expired')),
  constraint organization_clinical_capability_provenance_check
    check (
      (
        status = 'pending'
        and reviewed_by is null and reviewed_at is null
        and granted_by is null and granted_at is null
        and revoked_by is null and revoked_at is null
        and expired_by is null and expired_at is null
      )
      or (
        status in ('verified', 'rejected')
        and reviewed_by is not null and reviewed_at is not null
        and granted_by is null and granted_at is null
        and revoked_by is null and revoked_at is null
        and expired_by is null and expired_at is null
      )
      or (
        status = 'active'
        and reviewed_by is not null and reviewed_at is not null
        and granted_by is not null and granted_at is not null
        and revoked_by is null and revoked_at is null
        and expired_by is null and expired_at is null
      )
      or (
        status = 'revoked'
        and reviewed_by is not null and reviewed_at is not null
        and granted_by is not null and granted_at is not null
        and revoked_by is not null and revoked_at is not null
        and expired_by is null and expired_at is null
      )
      or (
        status = 'expired'
        and reviewed_by is not null and reviewed_at is not null
        and expired_by is not null and expired_at is not null
        and revoked_by is null and revoked_at is null
      )
    ),
  constraint organization_clinical_capability_no_self_review_check
    check (reviewed_by is null or reviewed_by <> user_id),
  constraint organization_clinical_capability_separation_of_duties_check
    check (granted_by is null or granted_by <> reviewed_by)
);

create unique index organization_clinical_capability_one_open_request_idx
  on public.organization_clinical_capability_requests (organization_id, user_id)
  where status in ('pending', 'verified', 'active');

create index organization_clinical_capability_review_queue_idx
  on public.organization_clinical_capability_requests (status, created_at)
  where status = 'pending';

create index organization_clinical_capability_user_idx
  on public.organization_clinical_capability_requests (user_id, organization_id, status);

create trigger organization_clinical_capability_set_updated_at
  before update on public.organization_clinical_capability_requests
  for each row execute function private.set_updated_at();

alter table public.organization_clinical_capability_requests enable row level security;

create policy organization_clinical_capability_select
  on public.organization_clinical_capability_requests
  for select to authenticated
  using (
    user_id = (select auth.uid())
    or private.can_manage_assignments(organization_id)
    or private.is_platform_verifier()
  );

revoke all on table public.organization_clinical_capability_requests from public, anon, authenticated;
grant select on table public.organization_clinical_capability_requests to authenticated;

create or replace function private.is_platform_verifier()
returns boolean
language sql
stable
security definer
set search_path = ''
as $body$
  select exists (
    select 1
    from private.platform_verifiers v
    where v.user_id = (select auth.uid())
      and v.active
  );
$body$;

create or replace function private.has_clinical_capability(target_org uuid, target_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $body$
  select exists (
    select 1
    from public.organization_clinical_capability_requests c
    where c.organization_id = target_org
      and c.user_id = target_user
      and c.status = 'active'
      and (c.expires_at is null or c.expires_at > pg_catalog.now())
  );
$body$;

revoke all on function private.is_platform_verifier() from public, anon;
grant execute on function private.is_platform_verifier() to authenticated;
revoke all on function private.has_clinical_capability(uuid, uuid) from public, anon;

create or replace function private.can_access_patient(target_org uuid, target_patient uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $body$
  select exists (
    select 1
    from public.patient_clinician_assignments a
    join public.organization_memberships m
      on m.organization_id = a.organization_id
     and m.user_id = a.clinician_user_id
    where a.organization_id = target_org
      and a.patient_id = target_patient
      and a.clinician_user_id = (select auth.uid())
      and a.status = 'active'
      and m.status = 'active'
      and (
        m.role = 'clinician'
        or private.has_clinical_capability(a.organization_id, a.clinician_user_id)
      )
  );
$body$;

revoke all on function private.can_access_patient(uuid, uuid) from public, anon;
grant execute on function private.can_access_patient(uuid, uuid) to authenticated;

create or replace function public.create_patient(
  target_org uuid,
  patient_name text,
  patient_language text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $body$
declare
  caller_id uuid := auth.uid();
  patient_id uuid;
begin
  if caller_id is null or not (
    private.has_org_role(target_org, array['clinician']::text[])
    or (
      private.has_org_role(target_org, array['owner', 'admin']::text[])
      and private.has_clinical_capability(target_org, caller_id)
    )
  ) then
    raise exception 'active clinical authorization required' using errcode = '42501';
  end if;

  if patient_language is not null and patient_language not in ('en', 'fr', 'ar') then
    raise exception 'unsupported preferred language' using errcode = '22023';
  end if;

  insert into public.patients (organization_id, full_name, preferred_language, created_by)
  values (target_org, btrim(patient_name), patient_language, caller_id)
  returning id into patient_id;

  insert into public.patient_clinician_assignments
    (organization_id, patient_id, clinician_user_id, status, assigned_by)
  values (target_org, patient_id, caller_id, 'active', caller_id);

  return patient_id;
end;
$body$;

revoke all on function public.create_patient(uuid, text, text) from public, anon;
grant execute on function public.create_patient(uuid, text, text) to authenticated;

create or replace function public.assign_patient_clinician(
  target_org uuid,
  target_patient uuid,
  target_clinician uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $body$
declare
  caller_id uuid := auth.uid();
  assignment_id uuid;
begin
  if caller_id is null or not private.can_manage_assignments(target_org) then
    raise exception 'organization owner or admin required' using errcode = '42501';
  end if;

  perform 1
  from public.patients p
  where p.id = target_patient
    and p.organization_id = target_org
  for update;

  if not found then
    raise exception 'patient not found' using errcode = 'P0002';
  end if;

  if not exists (
    select 1
    from public.organization_memberships m
    where m.organization_id = target_org
      and m.user_id = target_clinician
      and m.status = 'active'
      and (
        m.role = 'clinician'
        or (
          m.role in ('owner', 'admin')
          and private.has_clinical_capability(target_org, target_clinician)
        )
      )
  ) then
    raise exception 'target member lacks active clinical authorization' using errcode = '42501';
  end if;

  insert into public.patient_clinician_assignments
    (organization_id, patient_id, clinician_user_id, status, assigned_by)
  values (target_org, target_patient, target_clinician, 'active', caller_id)
  returning id into assignment_id;

  return assignment_id;
end;
$body$;

revoke all on function public.assign_patient_clinician(uuid, uuid, uuid) from public, anon;
grant execute on function public.assign_patient_clinician(uuid, uuid, uuid) to authenticated;

create or replace function public.request_clinical_capability(
  target_org uuid,
  target_professional_type text,
  target_verification_method text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $body$
declare
  caller_id uuid := auth.uid();
  request_id uuid;
begin
  if caller_id is null
    or not private.has_org_role(target_org, array['owner', 'admin']::text[]) then
    raise exception 'active organization owner or admin membership required' using errcode = '42501';
  end if;

  if char_length(btrim(coalesce(target_professional_type, ''))) not between 2 and 80 then
    raise exception 'professional type must contain 2 to 80 characters' using errcode = '22023';
  end if;

  if target_verification_method is null
    or target_verification_method not in ('professional_registry', 'document_review', 'institutional_confirmation') then
    raise exception 'unsupported verification method' using errcode = '22023';
  end if;

  update public.organization_clinical_capability_requests
  set
    status = 'expired',
    expired_by = caller_id,
    expired_at = pg_catalog.now(),
    updated_at = pg_catalog.now()
  where organization_id = target_org
    and user_id = caller_id
    and status in ('verified', 'active')
    and expires_at is not null
    and expires_at <= pg_catalog.now();

  insert into public.organization_clinical_capability_requests
    (organization_id, user_id, professional_type, verification_method, status)
  values
    (target_org, caller_id, btrim(target_professional_type), target_verification_method, 'pending')
  returning id into request_id;

  return request_id;
end;
$body$;

create or replace function public.verify_clinical_capability(
  target_request uuid,
  decision text,
  target_expires_at timestamptz default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $body$
declare
  caller_id uuid := auth.uid();
  capability public.organization_clinical_capability_requests%rowtype;
begin
  if caller_id is null or not private.is_platform_verifier() then
    raise exception 'platform verifier access required' using errcode = '42501';
  end if;

  select *
  into capability
  from public.organization_clinical_capability_requests
  where id = target_request
  for update;

  if not found then
    raise exception 'clinical capability request not found' using errcode = 'P0002';
  end if;

  if capability.user_id = caller_id then
    raise exception 'a verifier cannot review their own request' using errcode = '42501';
  end if;

  if capability.status <> 'pending' then
    raise exception 'only pending requests can be reviewed' using errcode = '23514';
  end if;

  if decision not in ('verified', 'rejected') then
    raise exception 'decision must be verified or rejected' using errcode = '22023';
  end if;

  if decision = 'verified' then
    if target_expires_at is not null and target_expires_at <= pg_catalog.now() then
      raise exception 'verification expiry must be in the future' using errcode = '22023';
    end if;
  elsif target_expires_at is not null then
    raise exception 'rejected requests cannot have an expiry' using errcode = '22023';
  end if;

  update public.organization_clinical_capability_requests
  set
    status = decision,
    reviewed_by = caller_id,
    reviewed_at = pg_catalog.now(),
    expires_at = target_expires_at,
    updated_at = pg_catalog.now()
  where id = target_request;
end;
$body$;

create or replace function public.grant_clinical_capability(target_request uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $body$
declare
  caller_id uuid := auth.uid();
  capability public.organization_clinical_capability_requests%rowtype;
begin
  if caller_id is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  select *
  into capability
  from public.organization_clinical_capability_requests
  where id = target_request
  for update;

  if not found then
    raise exception 'clinical capability request not found' using errcode = 'P0002';
  end if;

  if capability.status <> 'verified' then
    raise exception 'only verified requests can be granted' using errcode = '23514';
  end if;

  if capability.expires_at is not null and capability.expires_at <= pg_catalog.now() then
    raise exception 'clinical capability verification has expired' using errcode = '23514';
  end if;

  if capability.reviewed_by = caller_id then
    raise exception 'reviewer cannot grant the capability they verified' using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.organization_memberships m
    where m.organization_id = capability.organization_id
      and m.user_id = capability.user_id
      and m.status = 'active'
      and m.role in ('owner', 'admin')
  ) then
    raise exception 'clinical capability target must be an active organization owner or admin' using errcode = '42501';
  end if;

  if caller_id = capability.user_id then
    if not private.is_platform_verifier() then
      raise exception 'self-grant requires an independent platform verifier' using errcode = '42501';
    end if;
  elsif not private.can_manage_assignments(capability.organization_id) then
    raise exception 'organization owner or admin required to grant capability' using errcode = '42501';
  end if;

  update public.organization_clinical_capability_requests
  set
    status = 'active',
    granted_by = caller_id,
    granted_at = pg_catalog.now(),
    updated_at = pg_catalog.now()
  where id = target_request;
end;
$body$;

create or replace function public.revoke_clinical_capability(target_request uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $body$
declare
  caller_id uuid := auth.uid();
  capability public.organization_clinical_capability_requests%rowtype;
begin
  if caller_id is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  select *
  into capability
  from public.organization_clinical_capability_requests
  where id = target_request
  for update;

  if not found then
    raise exception 'clinical capability request not found' using errcode = 'P0002';
  end if;

  if capability.status <> 'active' then
    raise exception 'only active clinical capabilities can be revoked' using errcode = '23514';
  end if;

  if caller_id <> capability.user_id
    and not private.can_manage_assignments(capability.organization_id)
    and not private.is_platform_verifier() then
    raise exception 'self, organization owner/admin, or platform verifier required' using errcode = '42501';
  end if;

  update public.organization_clinical_capability_requests
  set
    status = 'revoked',
    revoked_by = caller_id,
    revoked_at = pg_catalog.now(),
    updated_at = pg_catalog.now()
  where id = target_request;
end;
$body$;

revoke all on function public.request_clinical_capability(uuid, text, text) from public, anon;
revoke all on function public.verify_clinical_capability(uuid, text, timestamptz) from public, anon;
revoke all on function public.grant_clinical_capability(uuid) from public, anon;
revoke all on function public.revoke_clinical_capability(uuid) from public, anon;

grant execute on function public.request_clinical_capability(uuid, text, text) to authenticated;
grant execute on function public.verify_clinical_capability(uuid, text, timestamptz) to authenticated;
grant execute on function public.grant_clinical_capability(uuid) to authenticated;
grant execute on function public.revoke_clinical_capability(uuid) to authenticated;

comment on table public.organization_clinical_capability_requests is
  'History-preserving professional capability verification and organization grant records. Does not store license numbers or credential documents.';
comment on table private.platform_verifiers is
  'Trusted platform-level credential reviewers. Managed only through privileged database operations.';
