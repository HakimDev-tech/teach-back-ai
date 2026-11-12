begin;
select plan(24);

select ok(to_regclass('public.organization_clinical_capability_requests') is not null,
  'clinical capability request table exists');
select ok((select relrowsecurity from pg_class where oid='public.organization_clinical_capability_requests'::regclass),
  'clinical capability request RLS is enabled');
select ok(has_table_privilege('authenticated','public.organization_clinical_capability_requests','select'),
  'authenticated can read capability requests through RLS');
select ok(not has_table_privilege('authenticated','public.organization_clinical_capability_requests','insert'),
  'authenticated cannot directly insert capability requests');
select ok(not has_table_privilege('authenticated','public.organization_clinical_capability_requests','update'),
  'authenticated cannot directly update capability requests');
select ok(not has_table_privilege('authenticated','private.platform_verifiers','select'),
  'authenticated cannot read the platform verifier allowlist');

insert into auth.users (id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data)
values
 ('31000000-0000-4000-8000-000000000001','authenticated','authenticated','owner-capability@phase-c.test','x',now(),'{"provider":"email","providers":["email"]}','{"full_name":"Capability Owner"}'),
 ('31000000-0000-4000-8000-000000000002','authenticated','authenticated','admin-capability@phase-c.test','x',now(),'{"provider":"email","providers":["email"]}','{"full_name":"Capability Admin"}'),
 ('31000000-0000-4000-8000-000000000003','authenticated','authenticated','clinician-capability@phase-c.test','x',now(),'{"provider":"email","providers":["email"]}','{"full_name":"Capability Clinician"}'),
 ('31000000-0000-4000-8000-000000000004','authenticated','authenticated','verifier-capability@phase-c.test','x',now(),'{"provider":"email","providers":["email"]}','{"full_name":"Platform Verifier"}');

insert into public.organizations (id,name,slug)
values ('41000000-0000-4000-8000-000000000001','Capability Test Organization','capability-test-org');

insert into public.organization_memberships (organization_id,user_id,role,status)
values
 ('41000000-0000-4000-8000-000000000001','31000000-0000-4000-8000-000000000001','owner','active'),
 ('41000000-0000-4000-8000-000000000001','31000000-0000-4000-8000-000000000002','admin','active'),
 ('41000000-0000-4000-8000-000000000001','31000000-0000-4000-8000-000000000003','clinician','active');

insert into private.platform_verifiers (user_id,active,created_by)
values ('31000000-0000-4000-8000-000000000004',true,'31000000-0000-4000-8000-000000000001');

-- Existing clinician membership remains an explicit organization-level clinical authorization.
set local role authenticated;
select set_config('request.jwt.claim.sub','31000000-0000-4000-8000-000000000003',true);
select lives_ok(
  $$select set_config('test.patient_id',public.create_patient(
    '41000000-0000-4000-8000-000000000001','Synthetic Capability Patient','fr'
  )::text,true)$$,
  'active clinician membership can create a patient'
);

-- An owner may request clinical capability, but cannot verify or grant it to themselves.
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','31000000-0000-4000-8000-000000000001',true);
select lives_ok(
  $$select set_config('test.capability_request_id',public.request_clinical_capability(
    '41000000-0000-4000-8000-000000000001','physician','document_review'
  )::text,true)$$,
  'organization owner can request a clinical capability'
);
select is(
  (select count(*) from public.organization_clinical_capability_requests
   where id=current_setting('test.capability_request_id')::uuid),
  1::bigint,
  'requester can read their own capability request'
);
select throws_ok(
  $$select public.verify_clinical_capability(current_setting('test.capability_request_id')::uuid,'verified',null)$$,
  '42501',null,'requester cannot verify their own clinical capability'
);

-- The organization cannot assign clinical duties before verification and grant.
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','31000000-0000-4000-8000-000000000002',true);
select throws_ok(
  $$select public.assign_patient_clinician(
    '41000000-0000-4000-8000-000000000001',
    current_setting('test.patient_id')::uuid,
    '31000000-0000-4000-8000-000000000001'
  )$$,
  '42501',null,'admin cannot assign an owner without active clinical capability'
);

-- An independently provisioned platform verifier reviews the request.
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','31000000-0000-4000-8000-000000000004',true);
select lives_ok(
  $$select public.verify_clinical_capability(current_setting('test.capability_request_id')::uuid,'verified',null)$$,
  'platform verifier can verify a pending capability request'
);

-- The owner cannot self-grant, but another organization administrator can grant the verified capability.
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','31000000-0000-4000-8000-000000000001',true);
select throws_ok(
  $$select public.grant_clinical_capability(current_setting('test.capability_request_id')::uuid)$$,
  '42501',null,'owner cannot self-grant a verified clinical capability'
);
select is((select count(*) from public.patients),0::bigint,
  'verified capability without a patient assignment does not expose clinical records');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','31000000-0000-4000-8000-000000000002',true);
select lives_ok(
  $$select public.grant_clinical_capability(current_setting('test.capability_request_id')::uuid)$$,
  'different organization admin can grant the verified capability'
);
select lives_ok(
  $$select set_config('test.owner_assignment_id',public.assign_patient_clinician(
    '41000000-0000-4000-8000-000000000001',
    current_setting('test.patient_id')::uuid,
    '31000000-0000-4000-8000-000000000001'
  )::text,true)$$,
  'admin can assign the owner after clinical capability is active'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','31000000-0000-4000-8000-000000000001',true);
select is((select count(*) from public.patients),1::bigint,
  'owner with active capability and assignment can read the assigned patient');
select lives_ok(
  $$select set_config('test.owner_created_patient_id',public.create_patient(
    '41000000-0000-4000-8000-000000000001','Synthetic Owner-Created Patient','ar'
  )::text,true)$$,
  'owner with active capability can create a patient');
select is((select count(*) from public.patients),2::bigint,
  'owner can read both patients assigned through authorized operations');

-- Revocation removes access immediately, including access through existing assignments.
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','31000000-0000-4000-8000-000000000002',true);
select lives_ok(
  $$select public.revoke_clinical_capability(current_setting('test.capability_request_id')::uuid)$$,
  'organization admin can revoke an active clinical capability'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','31000000-0000-4000-8000-000000000001',true);
select is((select count(*) from public.patients),0::bigint,
  'revoked capability immediately removes clinical record access');
select throws_ok(
  $$select public.create_patient('41000000-0000-4000-8000-000000000001','Unauthorized Patient','en')$$,
  '42501',null,'owner cannot create patients after capability revocation'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','31000000-0000-4000-8000-000000000004',true);
select is((select count(*) from public.patients),0::bigint,
  'platform verifier does not gain clinical patient access');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','31000000-0000-4000-8000-000000000003',true);
select is((select count(*) from public.patients),1::bigint,
  'existing clinician role and active assignment remain functional');

select * from finish();
rollback;
