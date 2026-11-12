-- Phase B hardening: allow draft question edits and preserve session finality.

-- The API supports PATCH for draft questions. Column-level grants plus RLS and
-- the immutable-question trigger constrain this to question text and ordering.
grant update (question_text, position) on public.questions to authenticated;

-- A prepared session has already frozen its approved instruction/question set.
-- Keep this invariant at the row boundary as defense in depth.
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
  if old.status = 'ready' and new.status = 'draft' then
    raise exception 'ready sessions cannot return to draft' using errcode = '23514';
  end if;
  return new;
end;
$body$;

-- Keep the transition function's declared state machine aligned with the
-- trigger-level invariant; a prepared session cannot be reset to draft.
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
    raise exception 'ready sessions cannot return to draft' using errcode='23514';
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
