-- Phase C: separate organization governance from verified clinical capability.
-- No organization membership role, including clinician, grants clinical access without explicit approval.
-- Owner/admin memberships require an independent, non-self-approved capability grant.

create table public.organization_clinical_capabilities (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  user_id uuid not null,
  professional_type text not null
    check (char_length(btrim(professional_type)) between 2 and 80),
  status text not null default 'pending'
    check (status in ('pending', 'active', 'suspended', 'revoked')),
  verification_status text not null default 'pending'
    check (verification_status in ('pending', 'verified', 'rejected', 'expired')),
  verification_method text null
    check (verification_method is null or verification_method = 'manual_review'),
  requested_by uuid not null references public.profiles(id) on delete restrict,
  verified_by uuid null references public.profiles(id) on delete restrict,
  verified_at timestamptz null,
  granted_by uuid null references public.profiles(id) on delete restrict,
  granted_at timestamptz null,
  expires_at timestamptz null,
  suspended_by uuid null references public.profiles(id) on delete restrict,
  suspended_at timestamptz null,
  suspension_reason text null
    check (suspension_reason is null or char_length(suspension_reason) <= 500),
  revoked_by uuid null references public.profiles(id) on delete restrict,
  revoked_at timestamptz null,
  revocation_reason text null
    check (revocation_reason is null or char_length(revocation_reason) <= 500),
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  constraint clinical_capability_membership_fk
    foreign key (organization_id, user_id)
    references public.organization_memberships(organization_id, user_id)
    on delete restrict,
  constraint clinical_capability_verification_provenance_check check (
    (verification_status = 'verified'
      and verified_by is not null
      and verified_at is not null
      and verification_method is not null)
    or
    (verification_status <> 'verified'
      and verified_by is null
      and verified_at is null
      and verification_method is null)
  ),
  constraint clinical_capability_active_verified_check check (
    status not in ('active', 'suspended')
    or verification_status = 'verified'
  ),
  constraint clinical_capability_pending_check check (
    status <> 'pending'
    or (
      verification_status = 'pending'
      and granted_by is null
      and granted_at is null
      and suspended_by is null
      and suspended_at is null
      and revoked_by is null
      and revoked_at is null
    )
  ),
  constraint clinical_capability_grant_provenance_check check (
    status not in ('active', 'suspended')
    or (granted_by is not null and granted_at is not null)
  ),
  constraint clinical_capability_suspension_provenance_check check (
    (status = 'suspended' and suspended_by is not null and suspended_at is not null)
    or
    (status <> 'suspended' and suspended_by is null and suspended_at is null)
  ),
  constraint clinical_capability_revocation_provenance_check check (
    (status = 'revoked' and revoked_by is not null and revoked_at is not null)
    or
    (status <> 'revoked' and revoked_by is null and revoked_at is null)
  )
);

-- At most one pending, active, or suspended capability per organization member.
-- Revoked requests remain as history and a new request can be created later.
create unique index clinical_capabilities_one_open_per_member_idx
  on public.organization_clinical_capabilities (organization_id, user_id)
  where status in ('pending', 'active', 'suspended');
create index clinical_capabilities_user_status_idx
  on public.organization_clinical_capabilities (user_id, organization_id, status);

create trigger clinical_capabilities_set_updated_at
before update on public.organization_clinical_capabilities
for each row execute function private.set_updated_at();

alter table public.organization_clinical_capabilities enable row level security;
revoke all on table public.organization_clinical_capabilities from anon, authenticated;
grant select on public.organization_clinical_capabilities to authenticated;

create policy clinical_capabilities_select_self_or_admin
on public.organization_clinical_capabilities
for select to authenticated
using (
  user_id = (select auth.uid())
  or private.can_manage_assignments(organization_id)
);

create or replace function private.has_clinical_capability(
  target_org uuid,
  target_user uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $body$
  select exists (
    select 1
    from public.organization_memberships m
    where m.organization_id = target_org
      and m.user_id = target_user
      and m.status = 'active'
      and exists (
        select 1
        from public.organization_clinical_capabilities c
        where c.organization_id = m.organization_id
          and c.user_id = m.user_id
          and c.status = 'active'
          and c.verification_status = 'verified'
          and (c.expires_at is null or c.expires_at > pg_catalog.now())
      )
  );
$body$;

revoke all on function private.has_clinical_capability(uuid, uuid) from public, anon;
grant execute on function private.has_clinical_capability(uuid, uuid) to authenticated;

-- Preserve the assignment boundary for every member with an active verified clinical capability.
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
    where a.organization_id = target_org
      and a.patient_id = target_patient
      and a.clinician_user_id = (select auth.uid())
      and a.status = 'active'
      and private.has_clinical_capability(a.organization_id, a.clinician_user_id)
  );
$body$;

revoke all on function private.can_access_patient(uuid, uuid) from public, anon;
grant execute on function private.can_access_patient(uuid, uuid) to authenticated;

-- Assignment metadata is also hidden from a clinician whose capability is suspended, revoked, or expired.
drop policy if exists assignments_select_related on public.patient_clinician_assignments;
create policy assignments_select_related
on public.patient_clinician_assignments
for select to authenticated
using (
  (
    clinician_user_id = (select auth.uid())
    and status = 'active'
    and private.has_clinical_capability(organization_id, clinician_user_id)
  )
  or private.can_manage_assignments(organization_id)
);

-- Assignment creation and reactivation must target a member with current clinical capability.
create or replace function private.validate_patient_assignment()
returns trigger
language plpgsql
set search_path = ''
as $body$
begin
  if new.status = 'active'
    and not private.has_clinical_capability(new.organization_id, new.clinician_user_id) then
    raise exception 'assignment target must have active clinical capability in this organization'
      using errcode = '23514';
  end if;

  if new.status = 'active' and not exists (
    select 1
    from public.patients p
    where p.organization_id = new.organization_id
      and p.id = new.patient_id
      and p.status = 'active'
  ) then
    raise exception 'archived patients cannot receive active assignments' using errcode = '23514';
  end if;

  if new.status = 'active' and not exists (
    select 1
    from public.organization_memberships m
    where m.organization_id = new.organization_id
      and m.user_id = new.assigned_by
      and m.status = 'active'
      and m.role in ('owner', 'admin', 'clinician')
  ) then
    raise exception 'assigner must be an active organization member' using errcode = '42501';
  end if;

  return new;
end;
$body$;

-- Patient creation requires the same capability as every other clinical operation.
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
  if caller_id is null
    or not private.has_clinical_capability(target_org, caller_id) then
    raise exception 'active clinical capability required' using errcode = '42501';
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

create or replace function public.request_clinical_capability(
  target_org uuid,
  target_professional_type text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $body$
declare
  caller_id uuid := auth.uid();
  capability_id uuid;
begin
  if caller_id is null or not private.is_active_member(target_org) then
    raise exception 'active organization membership required' using errcode = '42501';
  end if;

  if private.has_clinical_capability(target_org, caller_id) then
    raise exception 'member already has clinical capability' using errcode = '23505';
  end if;

  if exists (
    select 1
    from public.organization_clinical_capabilities c
    where c.organization_id = target_org
      and c.user_id = caller_id
      and c.status = 'pending'
  ) then
    raise exception 'a clinical capability request is already pending' using errcode = '23505';
  end if;

  if exists (
    select 1
    from public.organization_clinical_capabilities c
    where c.organization_id = target_org
      and c.user_id = caller_id
      and c.status = 'suspended'
  ) then
    raise exception 'a suspended capability requires administrator review' using errcode = '23514';
  end if;

  -- Expired grants are closed before a renewal request is inserted.
  update public.organization_clinical_capabilities
  set
    status = 'revoked',
    revoked_by = caller_id,
    revoked_at = pg_catalog.now(),
    revocation_reason = 'Expired capability; renewal requested'
  where organization_id = target_org
    and user_id = caller_id
    and status = 'active'
    and expires_at is not null
    and expires_at <= pg_catalog.now();

  insert into public.organization_clinical_capabilities
    (organization_id, user_id, professional_type, status, verification_status, requested_by)
  values
    (target_org, caller_id, btrim(target_professional_type), 'pending', 'pending', caller_id)
  returning id into capability_id;

  return capability_id;
end;
$body$;

revoke all on function public.request_clinical_capability(uuid, text) from public, anon;
grant execute on function public.request_clinical_capability(uuid, text) to authenticated;

create or replace function public.approve_clinical_capability(
  target_capability uuid,
  target_verification_method text,
  target_expires_at timestamptz default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $body$
declare
  capability public.organization_clinical_capabilities%rowtype;
  caller_id uuid := auth.uid();
begin
  select * into capability
  from public.organization_clinical_capabilities
  where id = target_capability
  for update;

  if capability.id is null then
    raise exception 'clinical capability request not found' using errcode = 'P0002';
  end if;

  if caller_id is null
    or not private.can_manage_assignments(capability.organization_id)
    or caller_id = capability.user_id then
    raise exception 'independent organization owner/admin approval required'
      using errcode = '42501';
  end if;

  if capability.status <> 'pending' then
    raise exception 'only pending capability requests can be approved' using errcode = '23514';
  end if;

  if target_verification_method is distinct from 'manual_review' then
    raise exception 'only organization manual review is currently supported'
      using errcode = '22023';
  end if;

  update public.organization_clinical_capabilities
  set
    status = 'active',
    verification_status = 'verified',
    verification_method = btrim(target_verification_method),
    verified_by = caller_id,
    verified_at = pg_catalog.now(),
    granted_by = caller_id,
    granted_at = pg_catalog.now(),
    expires_at = target_expires_at
  where id = target_capability;
end;
$body$;

revoke all on function public.approve_clinical_capability(uuid, text, timestamptz) from public, anon;
grant execute on function public.approve_clinical_capability(uuid, text, timestamptz) to authenticated;

create or replace function public.reject_clinical_capability(
  target_capability uuid,
  target_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $body$
declare
  capability public.organization_clinical_capabilities%rowtype;
  caller_id uuid := auth.uid();
begin
  select * into capability
  from public.organization_clinical_capabilities
  where id = target_capability
  for update;

  if capability.id is null then
    raise exception 'clinical capability request not found' using errcode = 'P0002';
  end if;

  if caller_id is null
    or not private.can_manage_assignments(capability.organization_id)
    or caller_id = capability.user_id then
    raise exception 'independent organization owner/admin review required'
      using errcode = '42501';
  end if;

  if capability.status <> 'pending' then
    raise exception 'only pending capability requests can be rejected' using errcode = '23514';
  end if;

  if target_reason is null or char_length(btrim(target_reason)) not between 2 and 500 then
    raise exception 'a rejection reason is required' using errcode = '22023';
  end if;

  update public.organization_clinical_capabilities
  set
    status = 'revoked',
    verification_status = 'rejected',
    revoked_by = caller_id,
    revoked_at = pg_catalog.now(),
    revocation_reason = btrim(target_reason)
  where id = target_capability;
end;
$body$;

revoke all on function public.reject_clinical_capability(uuid, text) from public, anon;
grant execute on function public.reject_clinical_capability(uuid, text) to authenticated;

create or replace function public.suspend_clinical_capability(
  target_capability uuid,
  target_reason text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $body$
declare
  capability public.organization_clinical_capabilities%rowtype;
  caller_id uuid := auth.uid();
begin
  select * into capability
  from public.organization_clinical_capabilities
  where id = target_capability
  for update;

  if capability.id is null then
    raise exception 'clinical capability not found' using errcode = 'P0002';
  end if;

  if caller_id is null or not private.can_manage_assignments(capability.organization_id) then
    raise exception 'organization owner/admin permission required' using errcode = '42501';
  end if;

  if capability.status <> 'active' then
    raise exception 'only active clinical capabilities can be suspended' using errcode = '23514';
  end if;

  update public.organization_clinical_capabilities
  set
    status = 'suspended',
    suspended_by = caller_id,
    suspended_at = pg_catalog.now(),
    suspension_reason = nullif(btrim(target_reason), '')
  where id = target_capability;
end;
$body$;

revoke all on function public.suspend_clinical_capability(uuid, text) from public, anon;
grant execute on function public.suspend_clinical_capability(uuid, text) to authenticated;

create or replace function public.revoke_clinical_capability(
  target_capability uuid,
  target_reason text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $body$
declare
  capability public.organization_clinical_capabilities%rowtype;
  caller_id uuid := auth.uid();
begin
  select * into capability
  from public.organization_clinical_capabilities
  where id = target_capability
  for update;

  if capability.id is null then
    raise exception 'clinical capability not found' using errcode = 'P0002';
  end if;

  if caller_id is null or not private.can_manage_assignments(capability.organization_id) then
    raise exception 'organization owner/admin permission required' using errcode = '42501';
  end if;

  if capability.status = 'revoked' then
    raise exception 'clinical capability is already revoked' using errcode = '23514';
  end if;

  update public.organization_clinical_capabilities
  set
    status = 'revoked',
    suspended_by = null,
    suspended_at = null,
    suspension_reason = null,
    revoked_by = caller_id,
    revoked_at = pg_catalog.now(),
    revocation_reason = nullif(btrim(target_reason), '')
  where id = target_capability;
end;
$body$;

revoke all on function public.revoke_clinical_capability(uuid, text) from public, anon;
grant execute on function public.revoke_clinical_capability(uuid, text) to authenticated;

comment on table public.organization_clinical_capabilities is
  'Organization-level clinical access attestation. Manual review is not an external license-registry validation or regulatory credential certification.';
comment on column public.organization_clinical_capabilities.verification_method is
  'Currently restricted to manual_review; external credential integrations are not configured.';
