begin;
select plan(17);

-- Synthetic identities only. All fixtures are rolled back with this test transaction.
insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data)
values
 ('10000000-0000-4000-8000-000000000001','authenticated','authenticated','owner-a@example.test','not-a-real-password',now(),'{"provider":"email","providers":["email"]}','{"full_name":"Owner A"}'),
 ('10000000-0000-4000-8000-000000000002','authenticated','authenticated','clinician-a@example.test','not-a-real-password',now(),'{"provider":"email","providers":["email"]}','{"full_name":"Clinician A"}'),
 ('10000000-0000-4000-8000-000000000003','authenticated','authenticated','admin-a@example.test','not-a-real-password',now(),'{"provider":"email","providers":["email"]}','{"full_name":"Admin A"}'),
 ('10000000-0000-4000-8000-000000000004','authenticated','authenticated','owner-b@example.test','not-a-real-password',now(),'{"provider":"email","providers":["email"]}','{"full_name":"Owner B"}'),
 ('10000000-0000-4000-8000-000000000005','authenticated','authenticated','unassigned@example.test','not-a-real-password',now(),'{"provider":"email","providers":["email"]}','{"full_name":"Unassigned"}');

insert into public.organizations (id, name, slug) values
 ('20000000-0000-4000-8000-000000000001','Organization A','organization-a'),
 ('20000000-0000-4000-8000-000000000002','Organization B','organization-b');
insert into public.organization_memberships (organization_id,user_id,role,status) values
 ('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','owner','active'),
 ('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002','clinician','active'),
 ('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000003','admin','active'),
 ('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000004','owner','active');

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
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true);
select is((with changed as (
  update public.organization_memberships set status='suspended'
  where organization_id='20000000-0000-4000-8000-000000000001'
    and user_id='10000000-0000-4000-8000-000000000003' returning 1
) select count(*) from changed),0::bigint,'clinician cannot update another membership');
select is((with changed as (
  update public.organization_memberships set role='admin'
  where organization_id='20000000-0000-4000-8000-000000000001'
    and user_id='10000000-0000-4000-8000-000000000002' returning 1
) select count(*) from changed),0::bigint,'clinician cannot promote self');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000003',true);
select is((with changed as (
  update public.organization_memberships set role='owner'
  where organization_id='20000000-0000-4000-8000-000000000001'
    and user_id='10000000-0000-4000-8000-000000000003' returning 1
) select count(*) from changed),0::bigint,'admin cannot promote self to owner');
select throws_ok(
  $$insert into public.organization_memberships (organization_id,user_id,role) values ('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000005','owner')$$,
  '42501', null, 'admin cannot create owner membership directly'
);
reset role;

update public.organization_memberships set status='suspended'
where organization_id='20000000-0000-4000-8000-000000000001'
  and user_id='10000000-0000-4000-8000-000000000002';
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true);
select is((select count(*) from public.organizations),0::bigint,'suspended member cannot read organization');
reset role;

select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true);
select throws_ok(
  $$update public.organization_memberships set role='admin' where organization_id='20000000-0000-4000-8000-000000000001' and user_id='10000000-0000-4000-8000-000000000001'$$,
  '23514', null, 'last active owner cannot be demoted'
);

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

set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000005',true);
select lives_ok($$select public.create_organization('New Test Org','new-test-org')$$,'user can create an organization through controlled RPC');
reset role;

set local role anon;
select throws_ok($$select * from public.profiles$$,'42501',null,'anonymous cannot read profiles');
select throws_ok($$select * from public.organizations$$,'42501',null,'anonymous cannot read organizations');
reset role;

select * from finish();
rollback;
