begin;
select plan(98);

select ok(to_regclass('public.patients') is not null, 'patients table exists');
select ok(to_regclass('public.patient_clinician_assignments') is not null, 'assignment table exists');
select ok(to_regclass('public.care_plans') is not null, 'care plans table exists');
select ok(to_regclass('public.instruction_items') is not null, 'instruction items table exists');
select ok(to_regclass('public.instruction_versions') is not null, 'instruction versions table exists');
select ok(to_regclass('public.teachback_sessions') is not null, 'sessions table exists');
select ok(to_regclass('public.session_instructions') is not null, 'session instruction snapshots exist');
select ok(to_regclass('public.questions') is not null, 'questions table exists');
select ok(to_regclass('public.responses') is not null, 'responses table exists');
select ok((select relrowsecurity from pg_class where oid='public.patients'::regclass), 'patients RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.patient_clinician_assignments'::regclass), 'assignments RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.responses'::regclass), 'responses RLS enabled');
select ok(not has_table_privilege('anon','public.patients','select'), 'anonymous cannot read patient records');
select ok(not has_function_privilege('anon','public.create_patient(uuid,text,text)','execute'), 'anonymous cannot create patient records');
select ok(
  has_column_privilege('authenticated','public.questions','question_text','UPDATE')
  and has_column_privilege('authenticated','public.questions','position','UPDATE'),
  'authenticated can update only the intended draft question fields'
);

-- Synthetic Auth identities and two isolated tenants.
insert into auth.users (id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data)
values
 ('30000000-0000-4000-8000-000000000001','authenticated','authenticated','owner-a@phase-b.test','x',now(),'{"provider":"email","providers":["email"]}','{"full_name":"Owner A"}'),
 ('30000000-0000-4000-8000-000000000002','authenticated','authenticated','admin-a@phase-b.test','x',now(),'{"provider":"email","providers":["email"]}','{"full_name":"Admin A"}'),
 ('30000000-0000-4000-8000-000000000003','authenticated','authenticated','clinician-a@phase-b.test','x',now(),'{"provider":"email","providers":["email"]}','{"full_name":"Clinician A"}'),
 ('30000000-0000-4000-8000-000000000004','authenticated','authenticated','clinician-b@phase-b.test','x',now(),'{"provider":"email","providers":["email"]}','{"full_name":"Clinician B"}'),
 ('30000000-0000-4000-8000-000000000005','authenticated','authenticated','owner-b@phase-b.test','x',now(),'{"provider":"email","providers":["email"]}','{"full_name":"Owner B"}');
insert into public.organizations (id,name,slug) values
 ('40000000-0000-4000-8000-000000000001','Synthetic Organization A','synthetic-org-a'),
 ('40000000-0000-4000-8000-000000000002','Synthetic Organization B','synthetic-org-b');
insert into public.organization_memberships (organization_id,user_id,role,status) values
 ('40000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','owner','active'),
 ('40000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000002','admin','active'),
 ('40000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000003','clinician','active'),
 ('40000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000004','clinician','active'),
 ('40000000-0000-4000-8000-000000000002','30000000-0000-4000-8000-000000000005','owner','active');

-- Synthetic clinical capability grants are explicitly approved by a different owner/admin.
insert into public.organization_clinical_capabilities
  (organization_id,user_id,professional_type,status,verification_status,verification_method,
   requested_by,verified_by,verified_at,granted_by,granted_at)
values
 ('40000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000003',
  'physician','active','verified','manual_review',
  '30000000-0000-4000-8000-000000000003','30000000-0000-4000-8000-000000000001',now(),
  '30000000-0000-4000-8000-000000000001',now()),
 ('40000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000004',
  'physician','active','verified','manual_review',
  '30000000-0000-4000-8000-000000000004','30000000-0000-4000-8000-000000000002',now(),
  '30000000-0000-4000-8000-000000000002',now());

select set_config('test.clinician_b_capability_id',(
  select id::text from public.organization_clinical_capabilities
  where user_id='30000000-0000-4000-8000-000000000004' and status='active'
),true);

-- Clinician A creates a patient and receives an assignment atomically.
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000003',true);
select lives_ok(
 $$select public.create_patient('40000000-0000-4000-8000-000000000001','Synthetic Patient A','en')$$,
 'clinician creates patient and assignment atomically'
);
select set_config('test.patient_id',(
 select id::text from public.patients where full_name='Synthetic Patient A'
),true);
select is((select count(*) from public.patients),1::bigint,'assigned clinician reads own patient');

-- A clinician role alone is not a clinical authorization.
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000002',true);
select lives_ok($cap$select public.revoke_clinical_capability(
  current_setting('test.clinician_b_capability_id')::uuid,'verification re-check'
)$cap$,
  'admin can revoke a clinician capability for re-verification');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000004',true);
select is((select count(*) from public.patients),0::bigint,
  'clinician role without active verified capability cannot read patient records');
select throws_ok(
  $cap$select public.create_patient(
    '40000000-0000-4000-8000-000000000001','Unverified Patient','en'
  )$cap$,
  '42501',null,'clinician role without active verified capability cannot create patient records');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000002',true);
select throws_ok(
  $cap$select public.assign_patient_clinician(
    '40000000-0000-4000-8000-000000000001',
    current_setting('test.patient_id')::uuid,
    '30000000-0000-4000-8000-000000000004'
  )$cap$,
  '23514',null,'admin cannot assign a clinician without active verified capability');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000004',true);
select lives_ok($cap$select set_config('test.clinician_b_new_capability_id',
  public.request_clinical_capability(
    '40000000-0000-4000-8000-000000000001','physician'
  )::text,true)$cap$,
  'clinician can request independent clinical capability re-verification');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000002',true);
select lives_ok($cap$select public.approve_clinical_capability(
  current_setting('test.clinician_b_new_capability_id')::uuid,'manual_review'
)$cap$,
  'another active admin can approve the clinician re-verification');

reset role;

-- An unassigned clinician, tenant owner, and tenant admin do not gain clinical-data access.
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000004',true);
select is((select count(*) from public.patients),0::bigint,'unassigned clinician cannot read patient');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000001',true);
select is((select count(*) from public.patients),0::bigint,'owner does not automatically access clinical data');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000002',true);
select is((select count(*) from public.patients),0::bigint,'admin does not automatically access clinical data');
select set_config('test.assignment_id',public.assign_patient_clinician(
 '40000000-0000-4000-8000-000000000001',current_setting('test.patient_id')::uuid,
 '30000000-0000-4000-8000-000000000004'
)::text,true);
select ok(current_setting('test.assignment_id',true) is not null,'admin can assign an active clinician');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000004',true);
select is((select count(*) from public.patients),1::bigint,'assigned clinician can now read patient');

-- Revoking clinical capability also hides assignment metadata while the assignment row remains active.
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000002',true);
select lives_ok($cap$select public.revoke_clinical_capability(
  current_setting('test.clinician_b_new_capability_id')::uuid,'capability re-check'
)$cap$,
  'admin can revoke clinical capability while an assignment is active');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000004',true);
select is((select count(*) from public.patients),0::bigint,
  'revoked clinical capability removes patient visibility despite active assignment');
select is((select count(*) from public.patient_clinician_assignments),0::bigint,
  'revoked clinical capability also hides assignment metadata');

select lives_ok($cap$select set_config('test.clinician_b_final_capability_id',
  public.request_clinical_capability(
    '40000000-0000-4000-8000-000000000001','physician'
  )::text,true)$cap$,
  'clinician can request capability again after revocation');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000002',true);
select lives_ok($cap$select public.approve_clinical_capability(
  current_setting('test.clinician_b_final_capability_id')::uuid,'manual_review'
)$cap$,
  'admin can independently re-approve clinical capability');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000004',true);
select is((select count(*) from public.patients),1::bigint,
  'active assignment restores patient visibility after capability re-approval');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000002',true);
select lives_ok($select public.revoke_patient_assignment(current_setting('test.assignment_id')::uuid)$,'admin can revoke assignment');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000004',true);
select is((select count(*) from public.patients),0::bigint,'revoked assignment immediately removes access');
reset role;

-- Build an instruction version and approve it through controlled operations.
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000003',true);
select lives_ok($$insert into public.care_plans (organization_id,patient_id,title,created_by)
 values ('40000000-0000-4000-8000-000000000001',current_setting('test.patient_id')::uuid,'Synthetic care plan','30000000-0000-4000-8000-000000000003')$$,
 'assigned clinician creates care plan');
select set_config('test.care_plan_id',(
 select id::text from public.care_plans where title='Synthetic care plan'
),true);
select lives_ok($$insert into public.instruction_items (organization_id,care_plan_id)
 values ('40000000-0000-4000-8000-000000000001',current_setting('test.care_plan_id')::uuid)$$,
 'clinician creates logical instruction item');
select set_config('test.instruction_item_id',(
 select id::text from public.instruction_items where care_plan_id=current_setting('test.care_plan_id')::uuid
),true);
select set_config('test.instruction_version_id',public.create_instruction_version(
 current_setting('test.instruction_item_id')::uuid,
 'Take the prescribed medicine with food according to the clinician-approved schedule.'
)::text,true);
select ok(current_setting('test.instruction_version_id',true) is not null,'version creation RPC returns a version');
select lives_ok($$select public.approve_instruction_version(current_setting('test.instruction_version_id')::uuid)$$,
 'assigned clinician approves instruction version');

-- A second patient in the same tenant must not leak instruction snapshots into Patient A sessions.
select set_config('test.patient_b_id',public.create_patient(
 '40000000-0000-4000-8000-000000000001','Synthetic Patient B','fr'
)::text,true);
select lives_ok($$insert into public.care_plans (organization_id,patient_id,title,created_by)
 values ('40000000-0000-4000-8000-000000000001',current_setting('test.patient_b_id')::uuid,
 'Synthetic care plan B','30000000-0000-4000-8000-000000000003')$$,
 'clinician creates second patient care plan');
select set_config('test.care_plan_b_id',(
 select id::text from public.care_plans where patient_id=current_setting('test.patient_b_id')::uuid
),true);
select lives_ok($$insert into public.instruction_items (organization_id,care_plan_id)
 values ('40000000-0000-4000-8000-000000000001',current_setting('test.care_plan_b_id')::uuid)$$,
 'clinician creates second patient instruction item');
select set_config('test.instruction_item_b_id',(
 select id::text from public.instruction_items where care_plan_id=current_setting('test.care_plan_b_id')::uuid
),true);
select set_config('test.instruction_version_b_id',public.create_instruction_version(
 current_setting('test.instruction_item_b_id')::uuid,'Synthetic instructions for Patient B.'
)::text,true);
select lives_ok($$select public.approve_instruction_version(current_setting('test.instruction_version_b_id')::uuid)$$,
 'clinician approves Patient B instruction version');
select throws_ok(
 $$update public.instruction_versions set content='Changed content' where id=current_setting('test.instruction_version_id')::uuid$$,
 '42501',null,'client cannot directly modify approved instruction content'
);

-- A session must have at least one approved question for every instruction snapshot.
select lives_ok($$with inserted as (
 insert into public.instruction_items (organization_id,care_plan_id)
 values ('40000000-0000-4000-8000-000000000001',current_setting('test.care_plan_id')::uuid)
 returning id
)
select set_config('test.coverage_item_id',id::text,true) from inserted$$,
 'clinician creates a second instruction item for coverage validation');
select set_config('test.coverage_version_id',public.create_instruction_version(
 current_setting('test.coverage_item_id')::uuid,
 'Synthetic second instruction for coverage validation.'
)::text,true);
select lives_ok($$select public.approve_instruction_version(current_setting('test.coverage_version_id')::uuid)$$,
 'second instruction version is approved');
select lives_ok($$with inserted as (
 insert into public.teachback_sessions
 (organization_id,patient_id,care_plan_id,created_by)
 values ('40000000-0000-4000-8000-000000000001',current_setting('test.patient_id')::uuid,
 current_setting('test.care_plan_id')::uuid,'30000000-0000-4000-8000-000000000003')
 returning id
)
select set_config('test.coverage_session_id',id::text,true) from inserted$$,
 'clinician creates a session for instruction coverage validation');
select lives_ok($$insert into public.session_instructions
 (organization_id,session_id,instruction_item_id,instruction_version_id)
 values ('40000000-0000-4000-8000-000000000001',current_setting('test.coverage_session_id')::uuid,
 current_setting('test.instruction_item_id')::uuid,current_setting('test.instruction_version_id')::uuid)$$,
 'coverage session snapshots its first approved instruction');
select lives_ok($$insert into public.session_instructions
 (organization_id,session_id,instruction_item_id,instruction_version_id)
 values ('40000000-0000-4000-8000-000000000001',current_setting('test.coverage_session_id')::uuid,
 current_setting('test.coverage_item_id')::uuid,current_setting('test.coverage_version_id')::uuid)$$,
 'coverage session snapshots its second approved instruction');
select lives_ok($$with inserted as (
 insert into public.questions
 (organization_id,session_id,instruction_item_id,instruction_version_id,question_text,position,created_by)
 values ('40000000-0000-4000-8000-000000000001',current_setting('test.coverage_session_id')::uuid,
 current_setting('test.instruction_item_id')::uuid,current_setting('test.instruction_version_id')::uuid,
 'How will you follow the first instruction?',1,'30000000-0000-4000-8000-000000000003')
 returning id
)
select set_config('test.coverage_question_id',id::text,true) from inserted$$,
 'coverage session receives a question for only its first instruction');
select lives_ok($$select public.approve_question(current_setting('test.coverage_question_id')::uuid)$$,
 'first instruction question is approved');
select throws_ok(
 $$select public.transition_session(current_setting('test.coverage_session_id')::uuid,1,'ready')$$,
 '23514',null,'session cannot publish while an instruction snapshot has no approved question'
);
select is((select status from public.teachback_sessions
 where id=current_setting('test.coverage_session_id')::uuid),
 'draft','incomplete instruction coverage leaves session in draft');

-- Create a session with an exact instruction snapshot and an approved manual question.
select lives_ok($$with inserted as (
 insert into public.teachback_sessions
 (organization_id,patient_id,care_plan_id,created_by)
 values ('40000000-0000-4000-8000-000000000001',current_setting('test.patient_id')::uuid,
 current_setting('test.care_plan_id')::uuid,'30000000-0000-4000-8000-000000000003')
 returning id
)
select set_config('test.session_id',id::text,true) from inserted$$,
 'assigned clinician creates draft session');
select throws_ok($$insert into public.session_instructions
 (organization_id,session_id,instruction_item_id,instruction_version_id)
 values ('40000000-0000-4000-8000-000000000001',current_setting('test.session_id')::uuid,
 current_setting('test.instruction_item_b_id')::uuid,current_setting('test.instruction_version_b_id')::uuid)$$,
 '23514',null,'a session cannot snapshot another patients instructions in the same tenant');
select lives_ok($$insert into public.session_instructions
 (organization_id,session_id,instruction_item_id,instruction_version_id)
 values ('40000000-0000-4000-8000-000000000001',current_setting('test.session_id')::uuid,
 current_setting('test.instruction_item_id')::uuid,current_setting('test.instruction_version_id')::uuid)$$,
 'session stores exact approved instruction version');
select lives_ok($$insert into public.questions
 (organization_id,session_id,instruction_item_id,instruction_version_id,question_text,position,created_by)
 values ('40000000-0000-4000-8000-000000000001',current_setting('test.session_id')::uuid,
 current_setting('test.instruction_item_id')::uuid,current_setting('test.instruction_version_id')::uuid,
 'Can you explain how you will take this medicine?',1,'30000000-0000-4000-8000-000000000003')$$,
 'clinician creates session-specific open question');
select set_config('test.question_id',(
 select id::text from public.questions where session_id=current_setting('test.session_id')::uuid
),true);
select lives_ok($$update public.questions set question_text='Please explain the schedule in your own words?' where id=current_setting('test.question_id')::uuid$$,
 'draft question can be edited before approval');
select lives_ok($$select public.approve_question(current_setting('test.question_id')::uuid)$$,
 'clinician approves question explicitly');
reset role;
select throws_ok(
 $$update public.questions set question_text='Changed after approval' where id=current_setting('test.question_id')::uuid$$,
 '55000',null,'approved question content is immutable');
set local role authenticated;
select lives_ok($$select public.transition_session(current_setting('test.session_id')::uuid,1,'ready')$$,
 'session can become ready with approved snapshots and questions');
select lives_ok($$select public.transition_session(current_setting('test.session_id')::uuid,2,'in_progress')$$,
 'ready session can be published and started');
select throws_ok(
 $$select public.transition_session(current_setting('test.session_id')::uuid,2,'cancelled')$$,
 '40001',null,'stale session version is rejected');
select throws_ok(
 $$select public.transition_session(current_setting('test.session_id')::uuid,3,'completed')$$,
 '23514',null,'session cannot bypass the clinician review workflow');

select set_config('test.response_id',public.save_response_draft(
 current_setting('test.session_id')::uuid,current_setting('test.question_id')::uuid,
 '50000000-0000-4000-8000-000000000001',
 'I will follow the schedule that my clinician approved and take it with food.',1
)::text,true);
select is(public.save_response_draft(
 current_setting('test.session_id')::uuid,current_setting('test.question_id')::uuid,
 '50000000-0000-4000-8000-000000000001',
 'I will follow the schedule that my clinician approved and take it with food.',1
),current_setting('test.response_id')::uuid,'same idempotency key returns the same draft response');
select lives_ok($$select public.submit_response(current_setting('test.response_id')::uuid)$$,
 'response submission is persisted through controlled RPC');
select is(
 public.submit_response(current_setting('test.response_id')::uuid),
 current_setting('test.response_id')::uuid,
 'submitting an already submitted response is idempotent');
select throws_ok(
 $$select public.save_response_draft(current_setting('test.session_id')::uuid,
 current_setting('test.question_id')::uuid,'50000000-0000-4000-8000-000000000001',
 'Reused idempotency key with a different attempt',2)$$,
 '23505',null,'idempotency key cannot be reused for a different attempt');
update public.responses set response_text='attempted overwrite'
 where id=current_setting('test.response_id')::uuid;
select is((select response_text from public.responses where id=current_setting('test.response_id')::uuid),
 'I will follow the schedule that my clinician approved and take it with food.',
 'submitted response content remains unchanged');
select lives_ok($$select public.transition_session(current_setting('test.session_id')::uuid,3,'awaiting_review')$$,
 'session requires and accepts complete submitted responses');
select lives_ok($$select public.transition_session(current_setting('test.session_id')::uuid,4,'review_in_progress')$$,
 'clinician can enter review state');
select lives_ok($$select public.transition_session(current_setting('test.session_id')::uuid,5,'completed')$$,
 'only review workflow can complete session');
select throws_ok(
 $$select public.transition_session(current_setting('test.session_id')::uuid,6,'in_progress')$$,
 '23514',null,'terminal session cannot be reopened');

-- A prepared session must never return to draft, because its approved snapshots are immutable.
select lives_ok($$with inserted as (
 insert into public.teachback_sessions
 (organization_id,patient_id,care_plan_id,created_by)
 values ('40000000-0000-4000-8000-000000000001',current_setting('test.patient_id')::uuid,
 current_setting('test.care_plan_id')::uuid,'30000000-0000-4000-8000-000000000003')
 returning id
)
select set_config('test.reversion_session_id',id::text,true) from inserted$$,
 'clinician creates a second session for transition-boundary coverage');
select lives_ok($$insert into public.session_instructions
 (organization_id,session_id,instruction_item_id,instruction_version_id)
 values ('40000000-0000-4000-8000-000000000001',current_setting('test.reversion_session_id')::uuid,
 current_setting('test.instruction_item_id')::uuid,current_setting('test.instruction_version_id')::uuid)$$,
 'second session receives an approved instruction snapshot');
select lives_ok($$insert into public.questions
 (organization_id,session_id,instruction_item_id,instruction_version_id,question_text,position,created_by)
 values ('40000000-0000-4000-8000-000000000001',current_setting('test.reversion_session_id')::uuid,
 current_setting('test.instruction_item_id')::uuid,current_setting('test.instruction_version_id')::uuid,
 'How will you follow the approved schedule?',1,'30000000-0000-4000-8000-000000000003')$$,
 'second session receives a draft question');
select set_config('test.reversion_question_id',(
 select id::text from public.questions where session_id=current_setting('test.reversion_session_id')::uuid
),true);
select lives_ok($$select public.approve_question(current_setting('test.reversion_question_id')::uuid)$$,
 'second session question is approved');
select lives_ok($$select public.transition_session(current_setting('test.reversion_session_id')::uuid,1,'ready')$$,
 'second session becomes ready');
select throws_ok($$select public.transition_session(current_setting('test.reversion_session_id')::uuid,2,'draft')$$,
 '23514',null,'ready session cannot return to draft');
select is((select status from public.teachback_sessions where id=current_setting('test.reversion_session_id')::uuid),
 'ready','rejected backward transition leaves session ready');

-- Clinical capability is independent from organization administration and cannot be self-approved.
reset role;
select ok(to_regclass('public.organization_clinical_capabilities') is not null,
  'organization clinical capability table exists');
select ok((select relrowsecurity from pg_class
  where oid='public.organization_clinical_capabilities'::regclass),
  'clinical capability RLS is enabled');
select ok(not has_table_privilege('anon','public.organization_clinical_capabilities','select'),
  'anonymous cannot inspect clinical capability records');

set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000001',true);
select lives_ok($cap$select set_config('test.owner_capability_id',
  public.request_clinical_capability(
    '40000000-0000-4000-8000-000000000001','physician'
  )::text,true)$cap$,
  'owner can request a separate clinical capability');

select throws_ok(
  $cap$select public.approve_clinical_capability(
    current_setting('test.owner_capability_id')::uuid,'manual_review'
  )$cap$,
  '42501',null,'a member cannot approve their own clinical capability');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000002',true);
select throws_ok($cap$select public.approve_clinical_capability(
  current_setting('test.owner_capability_id')::uuid,'external_registry'
)$cap$,
  '22023',null,'unconfigured external registry verification cannot be claimed');
select lives_ok($cap$select public.approve_clinical_capability(
  current_setting('test.owner_capability_id')::uuid,'manual_review'
)$cap$,
  'another active organization admin can verify and grant clinical capability');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000001',true);
select is((select count(*) from public.patients
  where id=current_setting('test.patient_id')::uuid),0::bigint,
  'verified capability without patient assignment does not grant clinical record access');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000002',true);
select lives_ok($cap$select public.assign_patient_clinician(
  '40000000-0000-4000-8000-000000000001',
  current_setting('test.patient_id')::uuid,
  '30000000-0000-4000-8000-000000000001'
)$cap$,
  'admin can assign a verified owner-clinician to a patient');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000001',true);
select is((select count(*) from public.patients
  where id=current_setting('test.patient_id')::uuid),1::bigint,
  'verified owner-clinician can read only after an active patient assignment');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000002',true);
select lives_ok($cap$select public.suspend_clinical_capability(
  current_setting('test.owner_capability_id')::uuid,'verification paused'
)$cap$,
  'organization admin can suspend a clinical capability');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000001',true);
select is((select count(*) from public.patients
  where id=current_setting('test.patient_id')::uuid),0::bigint,
  'suspending clinical capability immediately removes clinical access');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000002',true);
select lives_ok($cap$select public.revoke_clinical_capability(
  current_setting('test.owner_capability_id')::uuid,'capability withdrawn'
)$cap$,
  'organization admin can revoke a suspended clinical capability');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000001',true);
select is((select count(*) from public.patients
  where id=current_setting('test.patient_id')::uuid),0::bigint,
  'revoking clinical capability immediately removes clinical access');

select lives_ok($cap$select set_config('test.expired_capability_id',
  public.request_clinical_capability(
    '40000000-0000-4000-8000-000000000001','physician'
  )::text,true)$cap$,
  'a revoked member may submit a new capability request');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000002',true);
select lives_ok($cap$select public.approve_clinical_capability(
  current_setting('test.expired_capability_id')::uuid,
  'manual_review',
  pg_catalog.now() - interval '1 day'
)$cap$,
  'capability grants may carry an explicit expiry');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000001',true);
select is((select count(*) from public.patients
  where id=current_setting('test.patient_id')::uuid),0::bigint,
  'expired clinical capability does not authorize patient record access');
select lives_ok($cap$select public.request_clinical_capability(
  '40000000-0000-4000-8000-000000000001','physician'
)$cap$,
  'member can request renewal after an expired clinical capability is closed');

select * from finish();
rollback;
