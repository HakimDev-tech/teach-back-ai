begin;
select plan(47);

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
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000002',true);
select lives_ok($$select public.revoke_patient_assignment(current_setting('test.assignment_id')::uuid)$$,'admin can revoke assignment');
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
select lives_ok($select public.approve_instruction_version(current_setting('test.instruction_version_id')::uuid)$,
 'assigned clinician approves instruction version');

-- A second patient in the same tenant must not leak instruction snapshots into Patient A sessions.
select set_config('test.patient_b_id',public.create_patient(
 '40000000-0000-4000-8000-000000000001','Synthetic Patient B','fr'
)::text,true);
select lives_ok($insert into public.care_plans (organization_id,patient_id,title,created_by)
 values ('40000000-0000-4000-8000-000000000001',current_setting('test.patient_b_id')::uuid,
 'Synthetic care plan B','30000000-0000-4000-8000-000000000003')$,
 'clinician creates second patient care plan');
select set_config('test.care_plan_b_id',(
 select id::text from public.care_plans where patient_id=current_setting('test.patient_b_id')::uuid
),true);
select lives_ok($insert into public.instruction_items (organization_id,care_plan_id)
 values ('40000000-0000-4000-8000-000000000001',current_setting('test.care_plan_b_id')::uuid)$,
 'clinician creates second patient instruction item');
select set_config('test.instruction_item_b_id',(
 select id::text from public.instruction_items where care_plan_id=current_setting('test.care_plan_b_id')::uuid
),true);
select set_config('test.instruction_version_b_id',public.create_instruction_version(
 current_setting('test.instruction_item_b_id')::uuid,'Synthetic instructions for Patient B.'
)::text,true);
select lives_ok($select public.approve_instruction_version(current_setting('test.instruction_version_b_id')::uuid)$,
 'clinician approves Patient B instruction version');
select throws_ok(
 $$update public.instruction_versions set content='Changed content' where id=current_setting('test.instruction_version_id')::uuid$$,
 '42501',null,'client cannot directly modify approved instruction content'
);

-- Create a session with an exact instruction snapshot and an approved manual question.
select lives_ok($$insert into public.teachback_sessions
 (organization_id,patient_id,care_plan_id,created_by)
 values ('40000000-0000-4000-8000-000000000001',current_setting('test.patient_id')::uuid,
 current_setting('test.care_plan_id')::uuid,'30000000-0000-4000-8000-000000000003')$$,
 'assigned clinician creates draft session');
select set_config('test.session_id',(
 select id::text from public.teachback_sessions
 where patient_id=current_setting('test.patient_id')::uuid
 order by created_at desc limit 1
),true);
select throws_ok($insert into public.session_instructions
 (organization_id,session_id,instruction_item_id,instruction_version_id)
 values ('40000000-0000-4000-8000-000000000001',current_setting('test.session_id')::uuid,
 current_setting('test.instruction_item_b_id')::uuid,current_setting('test.instruction_version_b_id')::uuid)$,
 '23514',null,'a session cannot snapshot another patients instructions in the same tenant');
select lives_ok($insert into public.session_instructions
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
select lives_ok($$select public.approve_question(current_setting('test.question_id')::uuid)$$,
 'clinician approves question explicitly');
select lives_ok($$select public.transition_session(current_setting('test.session_id')::uuid,1,'ready')$$,
 'session can become ready with approved snapshots and questions');
select lives_ok($$select public.transition_session(current_setting('test.session_id')::uuid,2,'in_progress')$$,
 'ready session can be published and started');
select throws_ok(
 $$select public.transition_session(current_setting('test.session_id')::uuid,2,'cancelled')$$,
 '40001',null,'stale session version is rejected');

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

select * from finish();
rollback;
