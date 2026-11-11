-- Serialize owner-removal checks per organization to avoid concurrent last-owner races.
create or replace function private.guard_owner_membership()
returns trigger language plpgsql security definer set search_path = '' as $$
declare remaining_owners bigint; target_org uuid; old_user uuid;
begin
  target_org := case when tg_op = 'DELETE' then old.organization_id else new.organization_id end;
  old_user := case when tg_op = 'INSERT' then null else old.user_id end;
  perform 1 from public.organizations o where o.id = target_org for update;
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
