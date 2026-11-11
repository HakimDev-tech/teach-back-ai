begin;
select plan(21);

-- Synthetic identities only. All fixtures are rolled back with this test transaction.
insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data)
values
 ('10000000-0000-4000-8000-000000000001','authenticated','authenticated','owner-a@example.test','not-a-real-password',now(),'{"provider":"email","providers":["email"]}','{"full_name":"Owner A"}'),
 ('10000000-0000-4000-8000-000000000002','authenticated','authenticated','clinician-a@example.test','not-a-real-password',now(),'{"provider":"email","providers":["email"]}','{"full_name":"Clinician A"}'),
 ('10000000-0000-4000-8000-000000000003','authenticated','authenticated','admin-a@example.test','not-a-real-password',now(),'{"provider":"email","providers":["email"]}','{"full_name":"Admin A"}'),
 ('10000000-0000-4000-8000-000000000004','authenticated','authenticated','owner-b@example.test','not-a-real-password',now(),'{"provider":"email","providers":["email"]}','{"full_name":"Owner B"}'),
 ('10000000-0000-4000-8000-000000000005','authenticated','authenticated','unassigned@example.test','not-a-real-password',now(),'{"provider":"email","providers":["email"]}','{"full_name":"Unassigned"}'),
 ('10000000-0000-4000-8000-000000000006','authenticated','authenticated','new-clinician@example.test','not-a-real-password',now(),'{"provider":"email","providers":["email"]}','{"full_name":"New Clinician"}');

insert into public.organizations (id, name, slug) values
 ('20000000-0000-4000-8000-000000000001','Organization A','organization-a'),
 ('20000000-0000-4000-8000-000000000002','Organization B','organization-b');
insert into public.organization_memberships (organization_id,user_id,role,status) values
 ('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','owner','active'),
 ('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002','clinician','active'),
 ('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000003','admin','active'),
 ('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000004','owner','active');

-- Owner A: own profile, tenant isolation, and protected profile columns.
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true);
select is((select count(*) from public.profiles),1::bigint,'owner sees only own profile');
select is((select count(*) from public.profiles where id='10000000-0000-4000-8000-000000000002'),0::bigint,'owner cannot read another profile');
select is((select count(*) from public.organizations),1::bigint,'owner sees own organization only');
select is((select count(*) from public.organizations where id='20000000-0000-4000-8000-000000000002'),0::bigint,'cross-tenant organization read is denied');
select is((select count(*) from public.organization_memberships),3::bigint,'owner sees memberships in own organization');
select throws_ok(
  $$insert into public.organization_memberships (organization_id,user_id,role) values ('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','admin')$$,
  '42501', null, 'self-assigned privileged membership is rejected'
);
select throws_ok(
  $$update public.profiles set id='10000000-0000-4000-8000-000000000002' where id='10000000-0000-4000-8000-000000000001'$$,
  '42501', null, 'profile identity column cannot be mass-assigned'
);
reset role;

-- Clinician B cannot administer memberships or elevate their role.
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true);
with changed as (
  update public.organization_memberships set status='suspended'
  where organization_id='20000000-0000-4000-8000-000000000001'
    and user_id='10000000-0000-4000-8000-000000000003' returning 1
)
select is((select count(*) from changed),0::bigint,'clinician cannot update another membership');
with changed as (
  update public.organization_memberships set role='admin'
  where organization_id='20000000-0000-4000-8000-000000000001'
    and user_id='10000000-0000-4000-8000-000000000002' returning 1
)
select is((select count(*) from changed),0::bigint,'clinician cannot promote self');
with removed as (
  delete from public.organization_memberships
  where organization_id='20000000-0000-4000-8000-000000000001'
    and user_id='10000000-0000-4000-8000-000000000003' returning 1
)
select is((select count(*) from removed),0::bigint,'clinician cannot delete another membership');
reset role;

-- Admin C can add a clinician, but cannot promote itself or create an owner directly.
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000003',true);
select lives_ok(
  $$insert into public.organization_memberships (organization_id,user_id,role,status) values ('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000006','clinician','active')$$,
  'admin can add a clinician membership'
);
with changed as (
  update public.organization_memberships set role='owner'
  where organization_id='20000000-0000-4000-8000-000000000001'
    and user_id='10000000-0000-4000-8000-000000000003' returning 1
)
select is((select count(*) from changed),0::bigint,'admin cannot promote self to owner');
select throws_ok(
  $$insert into public.organization_memberships (organization_id,user_id,role) values ('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000005','owner')$$,
  '42501', null, 'admin cannot create owner membership directly'
);
reset role;

-- Suspended and revoked memberships both lose tenant access.
update public.organization_memberships set status='suspended'
where organization_id='20000000-0000-4000-8000-000000000001'
  and user_id='10000000-0000-4000-8000-000000000002';
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true);
select is((select count(*) from public.organizations),0::bigint,'suspended member cannot read organization');
reset role;
update public.organization_memberships set status='revoked'
where organization_id='20000000-0000-4000-8000-000000000001'
  and user_id='10000000-0000-4000-8000-000000000002';
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true);
select is((select count(*) from public.organizations),0::bigint,'revoked member cannot read organization');
reset role;

-- Trigger-level final-owner protection with the owner JWT context.
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true);
select throws_ok(
  $$update public.organization_memberships set role='admin' where organization_id='20000000-0000-4000-8000-000000000001' and user_id='10000000-0000-4000-8000-000000000001'$$,
  '23514', null, 'last active owner cannot be demoted'
);

-- Restore clinician and verify controlled transfer.
update public.organization_memberships set status='active'
where organization_id='20000000-0000-4000-8000-000000000001'
  and user_id='10000000-0000-4000-8000-000000000002';
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true);
select lives_ok(
  $$select public.transfer_organization_ownership('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002')$$,
  'active owner can transfer ownership to an active member'
);
reset role;
select is((select role from public.organization_memberships where organization_id='20000000-0000-4000-8000-000000000001' and user_id='10000000-0000-4000-8000-000000000002'),'owner','target becomes owner');

-- User E starts without tenant access and can create an organization only through the RPC.
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000005',true);
select is((select count(*) from public.organizations),0::bigint,'unassigned user cannot read organizations');
select lives_ok($$select public.create_organization('New Test Org','new-test-org')$$,'user can create an organization through controlled RPC');
reset role;

select ok(
  not has_table_privilege('anon','public.profiles','select')
  and not has_table_privilege('anon','public.organizations','select'),
  'anonymous role has no grants on foundational tables'
);
select * from finish();
rollback;
