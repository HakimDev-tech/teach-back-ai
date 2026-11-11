-- Phase A: identity, tenant boundary, and professional memberships only.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated;

create or replace function private.set_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at := pg_catalog.now(); return new; end;
$$;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null check (char_length(btrim(full_name)) between 2 and 120),
  avatar_url text null check (avatar_url is null or char_length(avatar_url) <= 2048),
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now()
);

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 2 and 160),
  slug text not null unique check (
    slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and char_length(slug) between 3 and 63
  ),
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now()
);

create table public.organization_memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('owner', 'admin', 'clinician')),
  status text not null default 'active' check (status in ('active', 'suspended', 'revoked')),
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  constraint organization_memberships_org_user_key unique (organization_id, user_id)
);

create index organization_memberships_user_status_idx
  on public.organization_memberships (user_id, status, organization_id);
create index organization_memberships_org_status_role_idx
  on public.organization_memberships (organization_id, status, role);

create trigger profiles_set_updated_at before update on public.profiles
for each row execute function private.set_updated_at();
create trigger organizations_set_updated_at before update on public.organizations
for each row execute function private.set_updated_at();
create trigger memberships_set_updated_at before update on public.organization_memberships
for each row execute function private.set_updated_at();

-- Minimal profile provisioning from untrusted, bounded display-name metadata.
create or replace function private.handle_new_auth_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare candidate_name text;
begin
  candidate_name := nullif(pg_catalog.btrim(new.raw_user_meta_data ->> 'full_name'), '');
  if candidate_name is null or char_length(candidate_name) < 2 or char_length(candidate_name) > 120 then
    candidate_name := 'New user';
  end if;
  insert into public.profiles (id, full_name)
  values (new.id, candidate_name)
  on conflict (id) do nothing;
  return new;
end;
$$;
revoke all on function private.handle_new_auth_user() from public, anon, authenticated;
create trigger on_auth_user_created after insert on auth.users
for each row execute function private.handle_new_auth_user();

-- SECURITY DEFINER helpers avoid recursive membership RLS. They expose only booleans.
create or replace function private.is_active_member(target_org uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.organization_memberships m
    where m.organization_id = target_org
      and m.user_id = (select auth.uid()) and m.status = 'active'
  );
$$;
create or replace function private.has_org_role(target_org uuid, allowed_roles text[])
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.organization_memberships m
    where m.organization_id = target_org
      and m.user_id = (select auth.uid()) and m.status = 'active'
      and m.role = any(allowed_roles)
  );
$$;
revoke all on function private.is_active_member(uuid) from public, anon;
revoke all on function private.has_org_role(uuid, text[]) from public, anon;
grant execute on function private.is_active_member(uuid) to authenticated;
grant execute on function private.has_org_role(uuid, text[]) to authenticated;

-- Client cannot directly create an organization or assign itself an owner role.
create or replace function public.create_organization(org_name text, org_slug text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare caller_id uuid := auth.uid(); new_org_id uuid;
begin
  if caller_id is null then raise exception 'authentication required' using errcode = '42501'; end if;
  if char_length(btrim(org_name)) not between 2 and 160
     or org_slug !~ '^[a-z0-9]+(-[a-z0-9]+)*$'
     or char_length(org_slug) not between 3 and 63 then
    raise exception 'invalid organization details' using errcode = '22023';
  end if;
  insert into public.organizations (name, slug)
  values (btrim(org_name), org_slug) returning id into new_org_id;
  insert into public.organization_memberships (organization_id, user_id, role, status)
  values (new_org_id, caller_id, 'owner', 'active');
  return new_org_id;
end;
$$;
revoke all on function public.create_organization(text, text) from public, anon;
grant execute on function public.create_organization(text, text) to authenticated;

-- Controlled ownership transfer promotes the target before demoting the caller.
create or replace function public.transfer_organization_ownership(target_org uuid, new_owner_user_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare caller_id uuid := auth.uid();
begin
  if caller_id is null or caller_id = new_owner_user_id then
    raise exception 'invalid ownership transfer' using errcode = '22023';
  end if;
  perform 1 from public.organizations o where o.id = target_org for update;
  if not found or not private.has_org_role(target_org, array['owner']::text[]) then
    raise exception 'only an active owner can transfer ownership' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.organization_memberships m
    where m.organization_id = target_org and m.user_id = new_owner_user_id and m.status = 'active'
  ) then raise exception 'target must be an active organization member' using errcode = '22023'; end if;
  update public.organization_memberships set role = 'owner'
  where organization_id = target_org and user_id = new_owner_user_id;
  update public.organization_memberships set role = 'admin'
  where organization_id = target_org and user_id = caller_id;
end;
$$;
revoke all on function public.transfer_organization_ownership(uuid, uuid) from public, anon;
grant execute on function public.transfer_organization_ownership(uuid, uuid) to authenticated;

-- Prevent removal/demotion/suspension of the final active owner.
create or replace function private.guard_owner_membership()
returns trigger language plpgsql security definer set search_path = '' as $$
declare remaining_owners bigint; target_org uuid; old_user uuid;
begin
  target_org := case when tg_op = 'DELETE' then old.organization_id else new.organization_id end;
  old_user := case when tg_op = 'INSERT' then null else old.user_id end;
  if tg_op <> 'INSERT' and old.role = 'owner'
     and not private.has_org_role(old.organization_id, array['owner']::text[]) then
    raise exception 'only an active owner can modify an owner membership' using errcode = '42501';
  end if;
  if tg_op = 'DELETE' or (tg_op = 'UPDATE' and old.role = 'owner'
      and (new.role <> 'owner' or new.status <> 'active')) then
    select count(*) into remaining_owners from public.organization_memberships m
    where m.organization_id = target_org and m.role = 'owner'
      and m.status = 'active' and m.user_id <> old_user;
    if remaining_owners = 0 then
      raise exception 'organization must retain at least one active owner' using errcode = '23514';
    end if;
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;
revoke all on function private.guard_owner_membership() from public, anon, authenticated;
create trigger memberships_guard_owner before update or delete on public.organization_memberships
for each row execute function private.guard_owner_membership();

alter table public.profiles enable row level security;
alter table public.organizations enable row level security;
alter table public.organization_memberships enable row level security;

-- Explicit grants are separate from RLS. Profile updates are column-restricted.
revoke all on table public.profiles from anon, authenticated;
grant select on table public.profiles to authenticated;
grant update (full_name, avatar_url) on table public.profiles to authenticated;
revoke all on table public.organizations from anon, authenticated;
grant select on table public.organizations to authenticated;
grant update (name) on table public.organizations to authenticated;
revoke all on table public.organization_memberships from anon, authenticated;
grant select, delete on table public.organization_memberships to authenticated;
grant insert (organization_id, user_id, role, status) on table public.organization_memberships to authenticated;
grant update (role, status) on table public.organization_memberships to authenticated;

create policy profiles_select_self on public.profiles for select to authenticated
using (id = (select auth.uid()));
create policy profiles_update_self on public.profiles for update to authenticated
using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy organizations_select_member on public.organizations for select to authenticated
using (private.is_active_member(id));
create policy organizations_update_admin on public.organizations for update to authenticated
using (private.has_org_role(id, array['owner', 'admin']::text[]))
with check (private.has_org_role(id, array['owner', 'admin']::text[]));

create policy memberships_select_org_member on public.organization_memberships for select to authenticated
using (private.is_active_member(organization_id));
create policy memberships_insert_admin on public.organization_memberships for insert to authenticated
with check (user_id <> (select auth.uid()) and role = 'clinician'
  and private.has_org_role(organization_id, array['owner', 'admin']::text[]));
create policy memberships_update_admin on public.organization_memberships for update to authenticated
using (user_id <> (select auth.uid())
  and private.has_org_role(organization_id, array['owner', 'admin']::text[]))
with check (user_id <> (select auth.uid()) and (
  (role = 'clinician' and private.has_org_role(organization_id, array['owner', 'admin']::text[]))
  or (role = 'admin' and private.has_org_role(organization_id, array['owner']::text[]))
));
create policy memberships_delete_admin on public.organization_memberships for delete to authenticated
using (user_id <> (select auth.uid())
  and private.has_org_role(organization_id, array['owner', 'admin']::text[]));
