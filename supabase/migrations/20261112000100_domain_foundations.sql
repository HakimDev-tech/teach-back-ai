-- Phase B: patient, instruction, question, session, and response domain.
-- All data is synthetic in development and tests. Patient-facing access is deliberately absent.

create table public.patients (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  full_name text not null check (char_length(btrim(full_name)) between 2 and 160),
  preferred_language text null check (preferred_language is null or preferred_language in ('en','fr','ar')),
  status text not null default 'active' check (status in ('active','archived')),
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  constraint patients_org_id_id_key unique (organization_id,id)
);
create index patients_org_status_created_idx on public.patients (organization_id,status,created_at desc);

create table public.patient_clinician_assignments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  patient_id uuid not null,
  clinician_user_id uuid not null,
  status text not null default 'active' check (status in ('active','revoked')),
  assigned_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  constraint assignments_patient_fk foreign key (organization_id,patient_id)
    references public.patients(organization_id,id) on delete restrict,
  constraint assignments_membership_fk foreign key (organization_id,clinician_user_id)
    references public.organization_memberships(organization_id,user_id) on delete restrict,
  constraint assignments_id_org_key unique (organization_id,id)
);
create unique index patient_assignments_one_active_idx
  on public.patient_clinician_assignments (organization_id,patient_id,clinician_user_id)
  where status = 'active';
create index patient_assignments_clinician_status_idx
  on public.patient_clinician_assignments (organization_id,clinician_user_id,status,patient_id);
create index patient_assignments_patient_status_idx
  on public.patient_clinician_assignments (organization_id,patient_id,status);

create table public.care_plans (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  patient_id uuid not null,
  title text not null check (char_length(btrim(title)) between 2 and 160),
  status text not null default 'draft' check (status in ('draft','active','archived')),
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  constraint care_plans_patient_fk foreign key (organization_id,patient_id)
    references public.patients(organization_id,id) on delete restrict,
  constraint care_plans_org_id_id_key unique (organization_id,id),
  constraint care_plans_org_patient_id_key unique (organization_id,patient_id,id)
);
create index care_plans_patient_status_idx on public.care_plans (organization_id,patient_id,status,created_at desc);

create table public.instruction_items (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  care_plan_id uuid not null,
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  constraint instruction_items_care_plan_fk foreign key (organization_id,care_plan_id)
    references public.care_plans(organization_id,id) on delete restrict,
  constraint instruction_items_org_id_id_key unique (organization_id,id),
  constraint instruction_items_org_plan_id_key unique (organization_id,care_plan_id,id)
);
create index instruction_items_plan_idx on public.instruction_items (organization_id,care_plan_id,created_at);

create table public.instruction_versions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  instruction_item_id uuid not null,
  version_number integer not null check (version_number > 0),
  content text not null check (char_length(btrim(content)) between 1 and 12000),
  status text not null default 'draft' check (status in ('draft','approved','superseded','archived')),
  created_by uuid not null references public.profiles(id) on delete restrict,
  approved_by uuid null references public.profiles(id) on delete restrict,
  approved_at timestamptz null,
  created_at timestamptz not null default pg_catalog.now(),
  constraint instruction_versions_item_fk foreign key (organization_id,instruction_item_id)
    references public.instruction_items(organization_id,id) on delete restrict,
  constraint instruction_versions_item_version_key unique (organization_id,instruction_item_id,version_number),
  constraint instruction_versions_org_item_id_key unique (organization_id,instruction_item_id,id),
  constraint instruction_versions_approval_pair check (
    (status in ('approved','superseded') and approved_by is not null and approved_at is not null)
    or (status='draft' and approved_by is null and approved_at is null)
    or (status='archived' and ((approved_by is null and approved_at is null)
      or (approved_by is not null and approved_at is not null)))
  )
);
create index instruction_versions_item_status_idx
  on public.instruction_versions (organization_id,instruction_item_id,status,version_number desc);

create table public.teachback_sessions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  patient_id uuid not null,
  care_plan_id uuid null,
  status text not null default 'draft' check (status in
    ('draft','ready','in_progress','awaiting_review','review_in_progress','completed','cancelled','expired')),
  created_by uuid not null references public.profiles(id) on delete restrict,
  published_at timestamptz null,
  started_at timestamptz null,
  submitted_at timestamptz null,
  completed_at timestamptz null,
  expires_at timestamptz null,
  version integer not null default 1 check (version > 0),
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  constraint sessions_patient_fk foreign key (organization_id,patient_id)
    references public.patients(organization_id,id) on delete restrict,
  constraint sessions_care_plan_fk foreign key (organization_id,patient_id,care_plan_id)
    references public.care_plans(organization_id,patient_id,id) on delete restrict,
  constraint sessions_org_id_id_key unique (organization_id,id)
);
create index sessions_patient_status_idx on public.teachback_sessions (organization_id,patient_id,status,created_at desc);
create index sessions_status_expiry_idx on public.teachback_sessions (status,expires_at) where status not in ('completed','cancelled','expired');

-- Session instructions are references to immutable approved versions, not copied medical text.
create table public.session_instructions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  session_id uuid not null,
  instruction_item_id uuid not null,
  instruction_version_id uuid not null,
  created_at timestamptz not null default pg_catalog.now(),
  constraint session_instructions_session_fk foreign key (organization_id,session_id)
    references public.teachback_sessions(organization_id,id) on delete restrict,
  constraint session_instructions_version_fk foreign key (organization_id,instruction_item_id,instruction_version_id)
    references public.instruction_versions(organization_id,instruction_item_id,id) on delete restrict,
  constraint session_instructions_session_version_key unique (organization_id,session_id,instruction_version_id),
  constraint session_instructions_org_session_id_key unique (organization_id,session_id,id)
);
create index session_instructions_session_idx on public.session_instructions (organization_id,session_id);

create table public.questions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  session_id uuid not null,
  instruction_item_id uuid not null,
  instruction_version_id uuid not null,
  question_text text not null check (char_length(btrim(question_text)) between 8 and 2000),
  position integer not null check (position > 0),
  status text not null default 'draft' check (status in ('draft','approved','rejected')),
  created_by uuid not null references public.profiles(id) on delete restrict,
  approved_by uuid null references public.profiles(id) on delete restrict,
  approved_at timestamptz null,
  created_at timestamptz not null default pg_catalog.now(),
  constraint questions_session_fk foreign key (organization_id,session_id)
    references public.teachback_sessions(organization_id,id) on delete restrict,
  constraint questions_session_instruction_fk foreign key (organization_id,session_id,instruction_version_id)
    references public.session_instructions(organization_id,session_id,instruction_version_id) on delete restrict,
  constraint questions_instruction_version_fk foreign key (organization_id,instruction_item_id,instruction_version_id)
    references public.instruction_versions(organization_id,instruction_item_id,id) on delete restrict,
  constraint questions_org_session_id_key unique (organization_id,session_id,id),
  constraint questions_position_key unique (organization_id,session_id,position),
  constraint questions_approval_pair check (
    (status = 'approved' and approved_by is not null and approved_at is not null)
    or (status in ('draft','rejected') and approved_by is null and approved_at is null)
  )
);
create index questions_session_position_idx on public.questions (organization_id,session_id,position);

create table public.responses (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  session_id uuid not null,
  question_id uuid not null,
  attempt_number integer not null default 1 check (attempt_number > 0),
  idempotency_key uuid not null,
  response_text text not null check (char_length(btrim(response_text)) between 1 and 10000),
  status text not null default 'draft' check (status in ('draft','submitted')),
  recorded_by uuid not null references public.profiles(id) on delete restrict,
  submitted_at timestamptz null,
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  constraint responses_question_fk foreign key (organization_id,session_id,question_id)
    references public.questions(organization_id,session_id,id) on delete restrict,
  constraint responses_attempt_key unique (organization_id,session_id,question_id,attempt_number),
  constraint responses_idempotency_key unique (organization_id,session_id,idempotency_key),
  constraint responses_submitted_at_check check (
    (status = 'submitted' and submitted_at is not null)
    or (status = 'draft' and submitted_at is null)
  )
);
create index responses_session_status_idx on public.responses (organization_id,session_id,status,question_id);
create index responses_question_attempt_idx on public.responses (organization_id,question_id,attempt_number desc);

create or replace function private.can_manage_assignments(target_org uuid)
returns boolean
language sql stable security definer set search_path = ''
as $body$
  select private.has_org_role(target_org, array['owner','admin']::text[]);
$body$;

create or replace function private.can_access_patient(target_org uuid, target_patient uuid)
returns boolean
language sql stable security definer set search_path = ''
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
      and m.role = 'clinician'
      and m.status = 'active'
  );
$body$;

create or replace function private.can_access_session(target_org uuid, target_session uuid)
returns boolean
language sql stable security definer set search_path = ''
as $body$
  select exists (
    select 1 from public.teachback_sessions s
    where s.organization_id = target_org
      and s.id = target_session
      and private.can_access_patient(s.organization_id, s.patient_id)
  );
$body$;

revoke all on function private.can_manage_assignments(uuid) from public, anon;
revoke all on function private.can_access_patient(uuid,uuid) from public, anon;
revoke all on function private.can_access_session(uuid,uuid) from public, anon;
grant execute on function private.can_manage_assignments(uuid) to authenticated;
grant execute on function private.can_access_patient(uuid,uuid) to authenticated;
grant execute on function private.can_access_session(uuid,uuid) to authenticated;


-- Common timestamp trigger.
create or replace function private.guard_patient_identity()
returns trigger language plpgsql set search_path = '' as $body$
begin
  if new.organization_id is distinct from old.organization_id or new.id is distinct from old.id
    or new.created_by is distinct from old.created_by or new.created_at is distinct from old.created_at then
    raise exception 'patient identity and tenant ownership are immutable' using errcode='55000';
  end if;
  if old.status='archived' and new.status <> 'archived' then
    raise exception 'archived patient records cannot be reopened' using errcode='23514';
  end if;
  return new;
end;
$body$;
create trigger patients_identity before update on public.patients for each row execute function private.guard_patient_identity();
create trigger patients_set_updated_at before update on public.patients for each row execute function private.set_updated_at();
create trigger assignments_set_updated_at before update on public.patient_clinician_assignments for each row execute function private.set_updated_at();
create trigger care_plans_set_updated_at before update on public.care_plans for each row execute function private.set_updated_at();
create trigger instruction_items_set_updated_at before update on public.instruction_items for each row execute function private.set_updated_at();
create trigger sessions_set_updated_at before update on public.teachback_sessions for each row execute function private.set_updated_at();
create trigger responses_set_updated_at before update on public.responses for each row execute function private.set_updated_at();

-- Validate assignment membership at write time; a revoked membership cannot be newly assigned.
create or replace function private.validate_patient_assignment()
returns trigger language plpgsql set search_path = '' as $body$
begin
  if new.status = 'active' and not exists (
    select 1 from public.organization_memberships m
    where m.organization_id = new.organization_id
      and m.user_id = new.clinician_user_id
      and m.role = 'clinician' and m.status = 'active'
  ) then
    raise exception 'assignment target must be an active clinician in this organization' using errcode = '23514';
  end if;
  if new.status = 'active' and not exists (
    select 1 from public.patients p
    where p.organization_id=new.organization_id and p.id=new.patient_id and p.status='active'
  ) then
    raise exception 'archived patients cannot receive active assignments' using errcode = '23514';
  end if;
  if new.status = 'active' and not exists (
    select 1 from public.organization_memberships m
    where m.organization_id = new.organization_id
      and m.user_id = new.assigned_by
      and m.status = 'active' and m.role in ('owner','admin','clinician')
  ) then
    raise exception 'assigner must be an active organization member' using errcode = '42501';
  end if;
  return new;
end;
$body$;
create trigger assignments_validate before insert or update of organization_id,clinician_user_id,status,assigned_by
on public.patient_clinician_assignments for each row execute function private.validate_patient_assignment();

-- Approved instruction content and provenance are immutable. Only status may move to superseded/archive.
create or replace function private.guard_instruction_version()
returns trigger language plpgsql set search_path = '' as $body$
begin
  if old.status in ('approved','superseded','archived') then
    if new.organization_id is distinct from old.organization_id
      or new.instruction_item_id is distinct from old.instruction_item_id
      or new.version_number is distinct from old.version_number
      or new.content is distinct from old.content
      or new.created_by is distinct from old.created_by
      or new.approved_by is distinct from old.approved_by
      or new.approved_at is distinct from old.approved_at
      or new.created_at is distinct from old.created_at
      or (new.status not in ('superseded','archived') or old.status <> 'approved') then
      raise exception 'approved instruction versions are immutable' using errcode = '55000';
    end if;
  end if;
  if old.status = 'draft' and new.status not in ('draft','approved','archived') then
    raise exception 'invalid instruction version transition' using errcode = '23514';
  end if;
  return new;
end;
$body$;
create trigger instruction_versions_immutable before update or delete on public.instruction_versions
for each row execute function private.guard_instruction_version();

create or replace function private.guard_care_plan_identity()
returns trigger language plpgsql set search_path = '' as $body$
begin
  if new.organization_id is distinct from old.organization_id or new.patient_id is distinct from old.patient_id
    or new.created_by is distinct from old.created_by or new.created_at is distinct from old.created_at then
    raise exception 'care plan ownership is immutable' using errcode='55000';
  end if;
  if old.status='archived' and new.status <> 'archived' then
    raise exception 'archived care plans cannot be reopened' using errcode='23514';
  end if;
  if old.status='draft' and new.status not in ('draft','active','archived') then
    raise exception 'invalid care plan transition' using errcode='23514';
  end if;
  if old.status='active' and new.status not in ('active','archived') then
    raise exception 'invalid care plan transition' using errcode='23514';
  end if;
  return new;
end;
$body$;
create trigger care_plans_identity before update on public.care_plans
for each row execute function private.guard_care_plan_identity();

create or replace function private.guard_session_snapshot()
returns trigger language plpgsql security definer set search_path = '' as $body$
declare target_session uuid; target_org uuid; current_status text;
begin
  target_session := case when tg_op = 'DELETE' then old.session_id else new.session_id end;
  target_org := case when tg_op = 'DELETE' then old.organization_id else new.organization_id end;
  select s.status into current_status from public.teachback_sessions s
    where s.id = target_session and s.organization_id = target_org for update;
  if current_status is distinct from 'draft' then
    raise exception 'session snapshots are immutable after draft' using errcode = '55000';
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$body$;
create or replace function private.validate_session_instruction()
returns trigger language plpgsql security definer set search_path = '' as $body$
begin
  perform 1
    from public.instruction_versions v
    join public.instruction_items i
      on i.organization_id=v.organization_id and i.id=v.instruction_item_id
    join public.care_plans c
      on c.organization_id=i.organization_id and c.id=i.care_plan_id
    join public.teachback_sessions s
      on s.organization_id=new.organization_id and s.id=new.session_id
   where v.organization_id=new.organization_id
     and v.instruction_item_id=new.instruction_item_id
     and v.id=new.instruction_version_id
     and v.status='approved'
     and c.patient_id=s.patient_id
   for share of v;
  if not found then
    raise exception 'session snapshot requires an approved instruction version for the same patient' using errcode='23514';
  end if;
  return new;
end;
$body$;
revoke all on function private.validate_session_instruction() from public,anon,authenticated;
create trigger session_instructions_validate before insert on public.session_instructions
for each row execute function private.validate_session_instruction();
revoke all on function private.guard_session_snapshot() from public,anon,authenticated;
create trigger session_instructions_immutable before insert or update or delete on public.session_instructions
for each row execute function private.guard_session_snapshot();

create or replace function private.guard_question()
returns trigger language plpgsql security definer set search_path = '' as $body$
declare current_status text; target_session uuid; target_org uuid;
begin
  target_session := case when tg_op='DELETE' then old.session_id else new.session_id end;
  target_org := case when tg_op='DELETE' then old.organization_id else new.organization_id end;
  select s.status into current_status from public.teachback_sessions s
   where s.id=target_session and s.organization_id=target_org for update;
  if tg_op='DELETE' or current_status <> 'draft' then
    raise exception 'questions cannot be changed after session leaves draft' using errcode='55000';
  end if;
  if tg_op='UPDATE' and old.status='approved' and (
    new.question_text is distinct from old.question_text
    or new.position is distinct from old.position
    or new.instruction_version_id is distinct from old.instruction_version_id
    or new.instruction_item_id is distinct from old.instruction_item_id
    or new.created_by is distinct from old.created_by
    or new.status <> 'approved'
    or new.approved_by is distinct from old.approved_by
    or new.approved_at is distinct from old.approved_at
  ) then
    raise exception 'approved questions are immutable' using errcode='55000';
  end if;
  return new;
end;
$body$;
revoke all on function private.guard_question() from public,anon,authenticated;
create trigger questions_immutable before insert or update or delete on public.questions
for each row execute function private.guard_question();

create or replace function private.guard_session_status()
returns trigger language plpgsql set search_path = '' as $body$
begin
  if new.organization_id is distinct from old.organization_id
    or new.patient_id is distinct from old.patient_id
    or new.care_plan_id is distinct from old.care_plan_id
    or new.created_by is distinct from old.created_by
    or new.created_at is distinct from old.created_at then
    raise exception 'session identity and ownership are immutable' using errcode = '55000';
  end if;
  return new;
end;
$body$;
create trigger sessions_identity_immutable before update on public.teachback_sessions
for each row execute function private.guard_session_status();

create or replace function private.guard_response()
returns trigger language plpgsql set search_path = '' as $body$
begin
  if tg_op = 'DELETE' then
    raise exception 'response history cannot be deleted' using errcode = '55000';
  end if;
  if old.status = 'submitted' then
    raise exception 'submitted responses are immutable' using errcode = '55000';
  end if;
  if new.organization_id is distinct from old.organization_id
    or new.session_id is distinct from old.session_id
    or new.question_id is distinct from old.question_id
    or new.attempt_number is distinct from old.attempt_number
    or new.idempotency_key is distinct from old.idempotency_key
    or new.recorded_by is distinct from old.recorded_by
    or new.created_at is distinct from old.created_at then
    raise exception 'response identity is immutable' using errcode = '55000';
  end if;
  return new;
end;
$body$;
create trigger responses_immutable before update or delete on public.responses
for each row execute function private.guard_response();

-- Atomic patient creation also creates the creator's active clinician assignment.
create or replace function public.create_patient(
  target_org uuid, patient_name text, patient_language text default null
)
returns uuid language plpgsql security definer set search_path = '' as $body$
declare caller_id uuid := auth.uid(); patient_id uuid;
begin
  if caller_id is null or not private.has_org_role(target_org,array['clinician']::text[]) then
    raise exception 'active clinician membership required' using errcode = '42501';
  end if;
  if patient_language is not null and patient_language not in ('en','fr','ar') then
    raise exception 'unsupported preferred language' using errcode = '22023';
  end if;
  insert into public.patients (organization_id,full_name,preferred_language,created_by)
  values (target_org,btrim(patient_name),patient_language,caller_id) returning id into patient_id;
  insert into public.patient_clinician_assignments
    (organization_id,patient_id,clinician_user_id,status,assigned_by)
  values (target_org,patient_id,caller_id,'active',caller_id);
  return patient_id;
end;
$body$;
revoke all on function public.create_patient(uuid,text,text) from public,anon;
grant execute on function public.create_patient(uuid,text,text) to authenticated;

-- Assignment administration is separate from access to the patient's clinical record.
create or replace function public.assign_patient_clinician(
  target_org uuid, target_patient uuid, target_clinician uuid
)
returns uuid language plpgsql security definer set search_path = '' as $body$
declare caller_id uuid := auth.uid(); assignment_id uuid;
begin
  if caller_id is null or not private.can_manage_assignments(target_org) then
    raise exception 'organization owner or admin required' using errcode = '42501';
  end if;
  perform 1 from public.patients p where p.id=target_patient and p.organization_id=target_org for update;
  if not found then raise exception 'patient not found' using errcode = 'P0002'; end if;
  insert into public.patient_clinician_assignments
    (organization_id,patient_id,clinician_user_id,status,assigned_by)
  values (target_org,target_patient,target_clinician,'active',caller_id)
  returning id into assignment_id;
  return assignment_id;
end;
$body$;
revoke all on function public.assign_patient_clinician(uuid,uuid,uuid) from public,anon;
grant execute on function public.assign_patient_clinician(uuid,uuid,uuid) to authenticated;

create or replace function public.revoke_patient_assignment(target_assignment uuid)
returns void language plpgsql security definer set search_path = '' as $body$
declare target_org uuid;
begin
  select a.organization_id into target_org from public.patient_clinician_assignments a
   where a.id=target_assignment for update;
  if target_org is null or not private.can_manage_assignments(target_org) then
    raise exception 'assignment not found or forbidden' using errcode = '42501';
  end if;
  update public.patient_clinician_assignments set status='revoked'
   where id=target_assignment and status='active';
end;
$body$;
revoke all on function public.revoke_patient_assignment(uuid) from public,anon;
grant execute on function public.revoke_patient_assignment(uuid) to authenticated;

create or replace function public.create_instruction_version(target_item uuid, instruction_content text)
returns uuid language plpgsql security definer set search_path = '' as $body$
declare caller_id uuid := auth.uid(); target_org uuid; next_version integer; new_version uuid;
begin
  if caller_id is null then raise exception 'authentication required' using errcode='42501'; end if;
  select i.organization_id into target_org
   from public.instruction_items i join public.care_plans c
     on c.organization_id=i.organization_id and c.id=i.care_plan_id
   where i.id=target_item and c.status <> 'archived'
     and exists (select 1 from public.patients p where p.organization_id=c.organization_id
       and p.id=c.patient_id and p.status='active')
     and private.can_access_patient(c.organization_id,c.patient_id)
   for update of i;
  if target_org is null then raise exception 'instruction item not found' using errcode='P0002'; end if;
  select coalesce(max(v.version_number),0)+1 into next_version
   from public.instruction_versions v
   where v.organization_id=target_org and v.instruction_item_id=target_item;
  insert into public.instruction_versions
   (organization_id,instruction_item_id,version_number,content,status,created_by)
  values (target_org,target_item,next_version,btrim(instruction_content),'draft',caller_id)
  returning id into new_version;
  return new_version;
end;
$body$;
revoke all on function public.create_instruction_version(uuid,text) from public,anon;
grant execute on function public.create_instruction_version(uuid,text) to authenticated;

create or replace function public.approve_instruction_version(target_version uuid)
returns void language plpgsql security definer set search_path = '' as $body$
declare target_org uuid; target_item uuid; current_status text;
begin
  select v.organization_id,v.instruction_item_id into target_org,target_item
    from public.instruction_versions v where v.id=target_version;
  if target_org is null then raise exception 'instruction version not found' using errcode='P0002'; end if;
  perform 1 from public.instruction_items i where i.organization_id=target_org and i.id=target_item for update;
  select v.status into current_status from public.instruction_versions v
    where v.id=target_version and v.organization_id=target_org for update;
  if target_org is null or not exists (
    select 1 from public.care_plans c join public.instruction_items i
      on i.organization_id=c.organization_id and i.care_plan_id=c.id
    where i.organization_id=target_org and i.id=target_item and c.status <> 'archived'
      and exists (select 1 from public.patients p where p.organization_id=c.organization_id
        and p.id=c.patient_id and p.status='active')
      and private.can_access_patient(c.organization_id,c.patient_id)
  ) then raise exception 'instruction version not found' using errcode='P0002'; end if;
  if current_status <> 'draft' then raise exception 'only draft versions can be approved' using errcode='23514'; end if;
  if (select max(version_number) from public.instruction_versions where organization_id=target_org and instruction_item_id=target_item)
     <> (select version_number from public.instruction_versions where id=target_version) then
    raise exception 'only the latest instruction version can be approved' using errcode='23514';
  end if;
  update public.instruction_versions set status='superseded'
   where organization_id=target_org and instruction_item_id=target_item and status='approved';
  update public.instruction_versions set status='approved',approved_by=auth.uid(),approved_at=pg_catalog.now()
   where id=target_version;
end;
$body$;
revoke all on function public.approve_instruction_version(uuid) from public,anon;
grant execute on function public.approve_instruction_version(uuid) to authenticated;

create or replace function public.approve_question(target_question uuid)
returns void language plpgsql security definer set search_path = '' as $body$
declare target_org uuid; target_session uuid; target_status text;
begin
  select q.organization_id,q.session_id into target_org,target_session
   from public.questions q where q.id=target_question;
  if target_org is null or not private.can_access_session(target_org,target_session) then
    raise exception 'question not found' using errcode='P0002';
  end if;
  perform 1 from public.teachback_sessions s where s.organization_id=target_org and s.id=target_session for update;
  select q.status into target_status from public.questions q
   where q.id=target_question and q.organization_id=target_org for update;
  if target_org is null or not private.can_access_session(target_org,target_session) then
    raise exception 'question not found' using errcode='P0002';
  end if;
  if target_status <> 'draft' then raise exception 'only draft questions can be approved' using errcode='23514'; end if;
  update public.questions set status='approved',approved_by=auth.uid(),approved_at=pg_catalog.now()
   where id=target_question;
end;
$body$;
revoke all on function public.approve_question(uuid) from public,anon;
grant execute on function public.approve_question(uuid) to authenticated;

-- Optimistic, row-locked session state machine.
create or replace function public.transition_session(
  target_session uuid, expected_version integer, target_status text
)
returns integer language plpgsql security definer set search_path = '' as $body$
declare s public.teachback_sessions%rowtype; required_count bigint; answered_count bigint;
begin
  select * into s from public.teachback_sessions where id=target_session for update;
  if s.id is null or not private.can_access_patient(s.organization_id,s.patient_id) then
    raise exception 'session not found' using errcode='P0002';
  end if;
  if s.version <> expected_version then raise exception 'session version conflict' using errcode='40001'; end if;
  if s.expires_at is not null and s.expires_at <= pg_catalog.now() and target_status <> 'expired' then
    raise exception 'session has expired' using errcode='23514';
  end if;
  if target_status in ('ready','in_progress') and not exists (
    select 1 from public.patients p where p.organization_id=s.organization_id
      and p.id=s.patient_id and p.status='active'
  ) then raise exception 'archived patient cannot start a session' using errcode='23514'; end if;
  if s.status in ('completed','cancelled','expired') then
    raise exception 'terminal session cannot transition' using errcode='23514';
  end if;
  if target_status='ready' and s.status='draft' then
    if not exists (select 1 from public.session_instructions si join public.instruction_versions iv
      on iv.organization_id=si.organization_id and iv.instruction_item_id=si.instruction_item_id
      and iv.id=si.instruction_version_id
      where si.organization_id=s.organization_id and si.session_id=s.id and iv.status in ('approved','superseded')) then
      raise exception 'session requires approved instruction snapshots' using errcode='23514';
    end if;
    if not exists (select 1 from public.questions q where q.organization_id=s.organization_id
      and q.session_id=s.id and q.status='approved') then
      raise exception 'session requires approved questions' using errcode='23514';
    end if;
    if exists (select 1 from public.questions q where q.organization_id=s.organization_id
      and q.session_id=s.id and q.status <> 'approved') then
      raise exception 'all session questions must be approved' using errcode='23514';
    end if;
  elsif target_status='draft' and s.status='ready' then
    null;
  elsif target_status='in_progress' and s.status='ready' then
    null;
  elsif target_status='awaiting_review' and s.status='in_progress' then
    select count(*) into required_count from public.questions q
      where q.organization_id=s.organization_id and q.session_id=s.id and q.status='approved';
    select count(*) into answered_count from public.questions q
      where q.organization_id=s.organization_id and q.session_id=s.id and q.status='approved'
      and exists (select 1 from public.responses r where r.organization_id=q.organization_id
        and r.session_id=q.session_id and r.question_id=q.id and r.status='submitted');
    if required_count=0 or answered_count <> required_count then
      raise exception 'all approved questions require submitted responses' using errcode='23514';
    end if;
  elsif target_status='review_in_progress' and s.status='awaiting_review' then
    null;
  elsif target_status='awaiting_review' and s.status='review_in_progress' then
    null;
  elsif target_status='completed' and s.status='review_in_progress' then
    null;
  elsif target_status='cancelled' and s.status in ('draft','ready','in_progress','awaiting_review') then
    null;
  elsif target_status='expired' and s.status in ('draft','ready','in_progress','awaiting_review','review_in_progress') then
    if s.expires_at is null or s.expires_at > pg_catalog.now() then
      raise exception 'session expiration time has not elapsed' using errcode='23514';
    end if;
  else
    raise exception 'invalid session transition' using errcode='23514';
  end if;

  update public.teachback_sessions set
    status=target_status,
    version=version+1,
    published_at=case when target_status='in_progress' then coalesce(published_at,pg_catalog.now()) else published_at end,
    started_at=case when target_status='in_progress' then coalesce(started_at,pg_catalog.now()) else started_at end,
    submitted_at=case when target_status='awaiting_review' then pg_catalog.now() else submitted_at end,
    completed_at=case when target_status='completed' then pg_catalog.now() else completed_at end
  where id=target_session;
  return expected_version+1;
end;
$body$;
revoke all on function public.transition_session(uuid,integer,text) from public,anon;
grant execute on function public.transition_session(uuid,integer,text) to authenticated;

create or replace function public.save_response_draft(
  target_session uuid, target_question uuid, target_idempotency_key uuid,
  response_content text, target_attempt integer default 1
)
returns uuid language plpgsql security definer set search_path = '' as $body$
declare s public.teachback_sessions%rowtype; existing public.responses%rowtype; new_id uuid;
begin
  select * into s from public.teachback_sessions where id=target_session for update;
  if s.id is null or not private.can_access_patient(s.organization_id,s.patient_id) then
    raise exception 'session not found' using errcode='P0002';
  end if;
  if s.status <> 'in_progress' or (s.expires_at is not null and s.expires_at <= pg_catalog.now()) then
    raise exception 'session is not accepting responses' using errcode='23514'; end if;
  if not exists (select 1 from public.questions q where q.id=target_question
    and q.organization_id=s.organization_id and q.session_id=s.id and q.status='approved') then
    raise exception 'question is not part of this active session' using errcode='23514';
  end if;
  select * into existing from public.responses r where r.organization_id=s.organization_id
    and r.session_id=s.id and r.idempotency_key=target_idempotency_key for update;
  if existing.id is not null then
    if existing.question_id <> target_question or existing.attempt_number <> target_attempt then
      raise exception 'idempotency key reused for a different response' using errcode='23505';
    end if;
    if existing.status='submitted' then return existing.id; end if;
    update public.responses set response_text=btrim(response_content) where id=existing.id;
    return existing.id;
  end if;
  insert into public.responses (organization_id,session_id,question_id,attempt_number,idempotency_key,
    response_text,status,recorded_by)
  values (s.organization_id,s.id,target_question,target_attempt,target_idempotency_key,
    btrim(response_content),'draft',auth.uid())
  returning id into new_id;
  return new_id;
end;
$body$;
revoke all on function public.save_response_draft(uuid,uuid,uuid,text,integer) from public,anon;
grant execute on function public.save_response_draft(uuid,uuid,uuid,text,integer) to authenticated;

create or replace function public.submit_response(target_response uuid)
returns uuid language plpgsql security definer set search_path = '' as $body$
declare r public.responses%rowtype; session_status text; session_expires_at timestamptz; target_org uuid; target_session uuid;
begin
  select organization_id,session_id into target_org,target_session
    from public.responses where id=target_response;
  if target_org is null or not private.can_access_session(target_org,target_session) then
    raise exception 'response not found' using errcode='P0002';
  end if;
  select s.status,s.expires_at into session_status,session_expires_at from public.teachback_sessions s
   where s.id=target_session and s.organization_id=target_org for update;
  select * into r from public.responses where id=target_response for update;
  if r.id is null or r.organization_id<>target_org or r.session_id<>target_session then
    raise exception 'response not found' using errcode='P0002';
  end if;
  if r.status='submitted' then return r.id; end if;
  if session_status <> 'in_progress' or (session_expires_at is not null and session_expires_at <= pg_catalog.now()) then
    raise exception 'session is not accepting responses' using errcode='23514'; end if;
  if not exists (select 1 from public.questions q where q.id=r.question_id
    and q.organization_id=r.organization_id and q.session_id=r.session_id and q.status='approved') then
    raise exception 'response question is not approved' using errcode='23514';
  end if;
  update public.responses set status='submitted',submitted_at=pg_catalog.now() where id=r.id;
  return r.id;
end;
$body$;
revoke all on function public.submit_response(uuid) from public,anon;
grant execute on function public.submit_response(uuid) to authenticated;

-- RLS: only assigned active clinicians can read clinical records. Admins manage assignments, not clinical content.
alter table public.patients enable row level security;
alter table public.patient_clinician_assignments enable row level security;
alter table public.care_plans enable row level security;
alter table public.instruction_items enable row level security;
alter table public.instruction_versions enable row level security;
alter table public.teachback_sessions enable row level security;
alter table public.session_instructions enable row level security;
alter table public.questions enable row level security;
alter table public.responses enable row level security;

revoke all on table public.patients,public.patient_clinician_assignments,public.care_plans,
 public.instruction_items,public.instruction_versions,public.teachback_sessions,
 public.session_instructions,public.questions,public.responses from anon,authenticated;

grant select on public.patients to authenticated;
grant update (full_name,preferred_language,status) on public.patients to authenticated;
grant select on public.patient_clinician_assignments to authenticated;
grant select on public.care_plans to authenticated;
grant insert (organization_id,patient_id,title,created_by) on public.care_plans to authenticated;
grant update (title,status) on public.care_plans to authenticated;
grant select on public.instruction_items to authenticated;
grant insert (organization_id,care_plan_id) on public.instruction_items to authenticated;
grant select on public.instruction_versions to authenticated;
grant select on public.teachback_sessions to authenticated;
grant insert (organization_id,patient_id,care_plan_id,created_by,expires_at) on public.teachback_sessions to authenticated;
grant select on public.session_instructions to authenticated;
grant insert (organization_id,session_id,instruction_item_id,instruction_version_id) on public.session_instructions to authenticated;
grant select on public.questions to authenticated;
grant insert (organization_id,session_id,instruction_item_id,instruction_version_id,question_text,position,created_by) on public.questions to authenticated;
grant update (question_text,position) on public.questions to authenticated;
grant select on public.responses to authenticated;
grant update (response_text) on public.responses to authenticated;

create policy patients_select_assigned on public.patients for select to authenticated
using (private.can_access_patient(organization_id,id));
create policy patients_update_assigned on public.patients for update to authenticated
using (private.can_access_patient(organization_id,id))
with check (private.can_access_patient(organization_id,id));

create policy assignments_select_related on public.patient_clinician_assignments for select to authenticated
using (clinician_user_id=(select auth.uid()) and status='active'
  or private.can_manage_assignments(organization_id));
create policy assignments_insert_admin on public.patient_clinician_assignments for insert to authenticated
with check (private.can_manage_assignments(organization_id));
create policy assignments_update_admin on public.patient_clinician_assignments for update to authenticated
using (private.can_manage_assignments(organization_id))
with check (private.can_manage_assignments(organization_id));

create policy care_plans_select_assigned on public.care_plans for select to authenticated
using (private.can_access_patient(organization_id,patient_id));
create policy care_plans_insert_assigned on public.care_plans for insert to authenticated
with check (created_by=(select auth.uid()) and status='draft'
  and private.can_access_patient(organization_id,patient_id)
  and exists (select 1 from public.patients p where p.organization_id=care_plans.organization_id
    and p.id=care_plans.patient_id and p.status='active'));
create policy care_plans_update_assigned on public.care_plans for update to authenticated
using (private.can_access_patient(organization_id,patient_id))
with check (private.can_access_patient(organization_id,patient_id));

create policy instruction_items_select_assigned on public.instruction_items for select to authenticated
using (exists (select 1 from public.care_plans c where c.organization_id=instruction_items.organization_id
 and c.id=instruction_items.care_plan_id and c.status <> 'archived'
 and private.can_access_patient(c.organization_id,c.patient_id)));
create policy instruction_items_insert_assigned on public.instruction_items for insert to authenticated
with check (exists (select 1 from public.care_plans c where c.organization_id=instruction_items.organization_id
 and c.id=instruction_items.care_plan_id and c.status <> 'archived'
 and private.can_access_patient(c.organization_id,c.patient_id)));

create policy instruction_versions_select_assigned on public.instruction_versions for select to authenticated
using (exists (select 1 from public.instruction_items i join public.care_plans c
 on c.organization_id=i.organization_id and c.id=i.care_plan_id
 where i.organization_id=instruction_versions.organization_id and i.id=instruction_versions.instruction_item_id
 and private.can_access_patient(c.organization_id,c.patient_id)));

create policy sessions_select_assigned on public.teachback_sessions for select to authenticated
using (private.can_access_patient(organization_id,patient_id));
create policy sessions_insert_assigned on public.teachback_sessions for insert to authenticated
with check (created_by=(select auth.uid()) and status='draft'
 and private.can_access_patient(organization_id,patient_id)
 and exists (select 1 from public.patients p where p.organization_id=teachback_sessions.organization_id
  and p.id=teachback_sessions.patient_id and p.status='active')
 and (care_plan_id is null or exists (select 1 from public.care_plans c
   where c.organization_id=teachback_sessions.organization_id and c.patient_id=teachback_sessions.patient_id
   and c.id=teachback_sessions.care_plan_id and c.status <> 'archived')));

create policy session_instructions_select_assigned on public.session_instructions for select to authenticated
using (private.can_access_session(organization_id,session_id));
create policy session_instructions_insert_assigned on public.session_instructions for insert to authenticated
with check (private.can_access_session(organization_id,session_id)
 and exists (select 1 from public.teachback_sessions s where s.organization_id=session_instructions.organization_id
  and s.id=session_instructions.session_id and s.status='draft')
 and exists (select 1 from public.instruction_versions v where v.organization_id=session_instructions.organization_id
  and v.instruction_item_id=session_instructions.instruction_item_id
  and v.id=session_instructions.instruction_version_id and v.status='approved'));

create policy questions_select_assigned on public.questions for select to authenticated
using (private.can_access_session(organization_id,session_id));
create policy questions_insert_assigned on public.questions for insert to authenticated
with check (created_by=(select auth.uid()) and status='draft'
 and private.can_access_session(organization_id,session_id)
 and exists (select 1 from public.teachback_sessions s where s.organization_id=questions.organization_id
  and s.id=questions.session_id and s.status='draft')
 and exists (select 1 from public.session_instructions si where si.organization_id=questions.organization_id
  and si.session_id=questions.session_id and si.instruction_version_id=questions.instruction_version_id));
create policy questions_update_draft on public.questions for update to authenticated
using (status='draft' and private.can_access_session(organization_id,session_id)
 and exists (select 1 from public.teachback_sessions s where s.organization_id=questions.organization_id
  and s.id=questions.session_id and s.status='draft'))
with check (status='draft' and private.can_access_session(organization_id,session_id));

create policy responses_select_assigned on public.responses for select to authenticated
using (private.can_access_session(organization_id,session_id));
create policy responses_insert_assigned on public.responses for insert to authenticated
with check (recorded_by=(select auth.uid()) and status='draft' and submitted_at is null
 and private.can_access_session(organization_id,session_id)
 and exists (select 1 from public.teachback_sessions s where s.organization_id=responses.organization_id
  and s.id=responses.session_id and s.status='in_progress')
 and exists (select 1 from public.questions q where q.organization_id=responses.organization_id
  and q.session_id=responses.session_id and q.id=responses.question_id and q.status='approved'));
create policy responses_update_draft_assigned on public.responses for update to authenticated
using (status='draft' and recorded_by=(select auth.uid())
 and private.can_access_session(organization_id,session_id))
with check (status in ('draft','submitted') and recorded_by=(select auth.uid())
 and private.can_access_session(organization_id,session_id));

-- No DELETE grants are given on clinical history. Submitted response mutation is blocked by trigger.
