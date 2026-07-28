create extension if not exists pgcrypto;

create table public.candidate_profiles (
  candidate_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  city text not null default '',
  state text not null default '',
  pin_code text not null default '',
  goal text,
  education_level text,
  experience_level text,
  preferred_role_codes text[] not null default '{}',
  current_step integer not null default 0 check (current_step between 0 and 10),
  onboarding_completed boolean not null default false,
  updated_at timestamptz not null default now()
);

create table public.consent_grants (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references auth.users(id) on delete cascade,
  purpose text not null,
  policy_version text not null,
  granted_at timestamptz not null,
  revoked_at timestamptz,
  unique (candidate_id, purpose, policy_version)
);

create table public.competencies (
  code text primary key,
  name text not null,
  description text not null,
  domain text not null,
  version integer not null default 1,
  status text not null check (status in ('draft', 'published', 'retired'))
);

create table public.role_profiles (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  name text not null,
  sector text not null,
  version integer not null,
  status text not null check (status in ('draft', 'published', 'retired')),
  unique (code, version)
);

create table public.role_competency_requirements (
  role_profile_id uuid not null references public.role_profiles(id),
  competency_code text not null references public.competencies(code),
  target_level integer not null check (target_level between 0 and 3),
  weight numeric(5, 4) not null check (weight > 0 and weight <= 1),
  primary key (role_profile_id, competency_code)
);

create table public.diagnostic_definitions (
  version text primary key,
  title text not null,
  question_manifest jsonb not null,
  status text not null check (status in ('draft', 'published', 'retired')),
  published_at timestamptz
);

create table public.diagnostic_results (
  candidate_id uuid primary key references auth.users(id) on delete cascade,
  definition_version text not null references public.diagnostic_definitions(version),
  recommended_role_code text not null,
  recommended_role_version integer not null default 1,
  result jsonb not null,
  completed_at timestamptz not null
);

create table public.learning_pathways (
  code text primary key,
  role_profile_id uuid not null references public.role_profiles(id),
  version integer not null,
  status text not null check (status in ('draft', 'published', 'retired')),
  unique (code, version)
);

create table public.learning_units (
  id text primary key,
  pathway_code text not null references public.learning_pathways(code),
  version text not null,
  title text not null,
  sequence integer not null,
  duration_minutes integer not null check (duration_minutes > 0),
  content jsonb not null,
  is_downloadable boolean not null default true,
  unique (pathway_code, sequence)
);

create table public.candidate_learning_state (
  candidate_id uuid primary key references auth.users(id) on delete cascade,
  downloaded_unit_ids text[] not null default '{}',
  completed_unit_ids text[] not null default '{}',
  updated_at timestamptz not null default now()
);

create table public.simulation_definitions (
  code text primary key,
  title text not null,
  sector text not null,
  role_profile_id uuid not null references public.role_profiles(id)
);

create table public.simulation_versions (
  version text primary key,
  simulation_code text not null references public.simulation_definitions(code),
  graph jsonb not null,
  scoring_rubric jsonb not null,
  published_at timestamptz not null
);

create table public.simulation_attempts (
  id text primary key,
  candidate_id uuid not null references auth.users(id) on delete cascade,
  simulation_version text not null references public.simulation_versions(version),
  status text not null check (status in ('active', 'submitted', 'scored', 'invalid')),
  started_at timestamptz not null,
  submitted_at timestamptz
);

create table public.simulation_events (
  attempt_id text not null references public.simulation_attempts(id) on delete cascade,
  sequence integer not null check (sequence > 0),
  event_type text not null,
  payload jsonb not null default '{}',
  client_time timestamptz not null,
  server_time timestamptz not null default now(),
  is_technical boolean not null default false,
  primary key (attempt_id, sequence)
);

create table public.simulation_scores (
  attempt_id text primary key references public.simulation_attempts(id) on delete cascade,
  candidate_id uuid not null references auth.users(id) on delete cascade,
  simulation_version text not null references public.simulation_versions(version),
  total_score integer not null check (total_score between 0 and 100),
  result jsonb not null,
  completed_at timestamptz not null
);

create table public.competency_evidence (
  id text primary key,
  candidate_id uuid not null references auth.users(id) on delete cascade,
  competency_code text not null references public.competencies(code),
  source_type text not null check (source_type in ('diagnostic', 'learning', 'simulation', 'physical')),
  score integer not null check (score between 0 and 100),
  evidence jsonb not null,
  created_at timestamptz not null
);

create table public.resume_parse_jobs (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references auth.users(id) on delete cascade,
  document_storage_key text not null,
  adapter text not null,
  status text not null check (status in ('queued', 'processing', 'completed', 'failed', 'review_required')),
  structured_result jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index consent_grants_candidate_active_idx
  on public.consent_grants (candidate_id, purpose)
  where revoked_at is null;
create index simulation_attempts_candidate_status_idx
  on public.simulation_attempts (candidate_id, status);
create index simulation_scores_candidate_completed_idx
  on public.simulation_scores (candidate_id, completed_at desc);
create index competency_evidence_candidate_created_idx
  on public.competency_evidence (candidate_id, created_at desc);
create index resume_parse_jobs_candidate_status_idx
  on public.resume_parse_jobs (candidate_id, status);

alter table public.candidate_profiles enable row level security;
alter table public.consent_grants enable row level security;
alter table public.competencies enable row level security;
alter table public.role_profiles enable row level security;
alter table public.role_competency_requirements enable row level security;
alter table public.diagnostic_definitions enable row level security;
alter table public.diagnostic_results enable row level security;
alter table public.learning_pathways enable row level security;
alter table public.learning_units enable row level security;
alter table public.candidate_learning_state enable row level security;
alter table public.simulation_definitions enable row level security;
alter table public.simulation_versions enable row level security;
alter table public.simulation_attempts enable row level security;
alter table public.simulation_events enable row level security;
alter table public.simulation_scores enable row level security;
alter table public.competency_evidence enable row level security;
alter table public.resume_parse_jobs enable row level security;

create policy "candidate reads own profile"
  on public.candidate_profiles for select to authenticated
  using ((select auth.uid()) = candidate_id);
create policy "candidate inserts own profile"
  on public.candidate_profiles for insert to authenticated
  with check ((select auth.uid()) = candidate_id);
create policy "candidate updates own profile"
  on public.candidate_profiles for update to authenticated
  using ((select auth.uid()) = candidate_id)
  with check ((select auth.uid()) = candidate_id);

create policy "candidate reads own consents"
  on public.consent_grants for select to authenticated
  using ((select auth.uid()) = candidate_id);
create policy "candidate inserts own consents"
  on public.consent_grants for insert to authenticated
  with check ((select auth.uid()) = candidate_id);
create policy "candidate updates own consents"
  on public.consent_grants for update to authenticated
  using ((select auth.uid()) = candidate_id)
  with check ((select auth.uid()) = candidate_id);

create policy "authenticated reads published competencies"
  on public.competencies for select to authenticated
  using (status = 'published');
create policy "authenticated reads published roles"
  on public.role_profiles for select to authenticated
  using (status = 'published');
create policy "authenticated reads role requirements"
  on public.role_competency_requirements for select to authenticated
  using (true);
create policy "authenticated reads published diagnostics"
  on public.diagnostic_definitions for select to authenticated
  using (status = 'published');
create policy "authenticated reads published pathways"
  on public.learning_pathways for select to authenticated
  using (status = 'published');
create policy "authenticated reads published learning units"
  on public.learning_units for select to authenticated
  using (
    exists (
      select 1 from public.learning_pathways pathway
      where pathway.code = learning_units.pathway_code
        and pathway.status = 'published'
    )
  );
create policy "authenticated reads simulations"
  on public.simulation_definitions for select to authenticated
  using (true);
create policy "authenticated reads simulation versions"
  on public.simulation_versions for select to authenticated
  using (published_at <= now());

create policy "candidate manages own diagnostic result"
  on public.diagnostic_results for all to authenticated
  using ((select auth.uid()) = candidate_id)
  with check ((select auth.uid()) = candidate_id);
create policy "candidate manages own learning state"
  on public.candidate_learning_state for all to authenticated
  using ((select auth.uid()) = candidate_id)
  with check ((select auth.uid()) = candidate_id);
create policy "candidate manages own simulation attempts"
  on public.simulation_attempts for all to authenticated
  using ((select auth.uid()) = candidate_id)
  with check ((select auth.uid()) = candidate_id);
create policy "candidate reads own simulation events"
  on public.simulation_events for select to authenticated
  using (
    exists (
      select 1 from public.simulation_attempts attempt
      where attempt.id = simulation_events.attempt_id
        and attempt.candidate_id = (select auth.uid())
    )
  );
create policy "candidate inserts own simulation events"
  on public.simulation_events for insert to authenticated
  with check (
    exists (
      select 1 from public.simulation_attempts attempt
      where attempt.id = simulation_events.attempt_id
        and attempt.candidate_id = (select auth.uid())
        and attempt.status = 'active'
    )
  );
create policy "candidate reads own simulation scores"
  on public.simulation_scores for select to authenticated
  using ((select auth.uid()) = candidate_id);
create policy "candidate inserts own simulation scores"
  on public.simulation_scores for insert to authenticated
  with check ((select auth.uid()) = candidate_id);
create policy "candidate updates own simulation scores"
  on public.simulation_scores for update to authenticated
  using ((select auth.uid()) = candidate_id)
  with check ((select auth.uid()) = candidate_id);
create policy "candidate reads own competency evidence"
  on public.competency_evidence for select to authenticated
  using ((select auth.uid()) = candidate_id);
create policy "candidate inserts own competency evidence"
  on public.competency_evidence for insert to authenticated
  with check ((select auth.uid()) = candidate_id);
create policy "candidate updates own competency evidence"
  on public.competency_evidence for update to authenticated
  using ((select auth.uid()) = candidate_id)
  with check ((select auth.uid()) = candidate_id);
create policy "candidate reads own resume parse jobs"
  on public.resume_parse_jobs for select to authenticated
  using ((select auth.uid()) = candidate_id);
create policy "candidate creates own resume parse jobs"
  on public.resume_parse_jobs for insert to authenticated
  with check ((select auth.uid()) = candidate_id);

grant select, insert, update on public.candidate_profiles to authenticated;
grant select, insert, update on public.consent_grants to authenticated;
grant select on public.competencies, public.role_profiles,
  public.role_competency_requirements, public.diagnostic_definitions,
  public.learning_pathways, public.learning_units,
  public.simulation_definitions, public.simulation_versions to authenticated;
grant select, insert, update on public.diagnostic_results,
  public.candidate_learning_state, public.simulation_attempts to authenticated;
grant select, insert on public.simulation_events, public.resume_parse_jobs
  to authenticated;
grant select, insert, update on public.simulation_scores,
  public.competency_evidence to authenticated;

insert into public.competencies (code, name, description, domain, status) values
  ('inventory_accuracy', 'Inventory accuracy', 'Counts, compares, and preserves accurate stock records.', 'logistics', 'published'),
  ('safe_escalation', 'Safe escalation', 'Recognises exceptions and escalates with an audit trail.', 'logistics', 'published'),
  ('sla_prioritisation', 'SLA prioritisation', 'Orders work by urgency without bypassing safety controls.', 'logistics', 'published'),
  ('handover_communication', 'Handover communication', 'Shares clear facts, action taken, and outstanding risk.', 'logistics', 'published');

insert into public.role_profiles (code, name, sector, version, status) values
  ('warehouse_associate', 'Warehouse Operations Associate', 'logistics', 1, 'published'),
  ('inventory_executive', 'Inventory Executive', 'logistics', 1, 'published'),
  ('dispatch_executive', 'Dispatch Executive', 'logistics', 1, 'published');

insert into public.role_competency_requirements
  (role_profile_id, competency_code, target_level, weight)
select role.id, requirement.competency_code, requirement.target_level, requirement.weight
from (
  values
    ('warehouse_associate', 'inventory_accuracy', 2, 0.35::numeric),
    ('warehouse_associate', 'safe_escalation', 2, 0.30::numeric),
    ('warehouse_associate', 'sla_prioritisation', 1, 0.20::numeric),
    ('warehouse_associate', 'handover_communication', 1, 0.15::numeric),
    ('inventory_executive', 'inventory_accuracy', 3, 0.40::numeric),
    ('inventory_executive', 'safe_escalation', 2, 0.25::numeric),
    ('inventory_executive', 'sla_prioritisation', 2, 0.20::numeric),
    ('inventory_executive', 'handover_communication', 2, 0.15::numeric),
    ('dispatch_executive', 'inventory_accuracy', 2, 0.20::numeric),
    ('dispatch_executive', 'safe_escalation', 2, 0.25::numeric),
    ('dispatch_executive', 'sla_prioritisation', 3, 0.40::numeric),
    ('dispatch_executive', 'handover_communication', 2, 0.15::numeric)
) as requirement(role_code, competency_code, target_level, weight)
join public.role_profiles role
  on role.code = requirement.role_code and role.version = 1;

insert into public.diagnostic_definitions
  (version, title, question_manifest, status, published_at) values
  ('logistics-diagnostic-v1', 'Logistics career diagnostic v1', '{"question_count":4,"languages":["en"],"scoring":"deterministic"}', 'published', now());

insert into public.learning_pathways
  (code, role_profile_id, version, status)
select 'logistics-foundation-v1', id, 1, 'published'
from public.role_profiles
where code = 'warehouse_associate' and version = 1;

insert into public.learning_units
  (id, pathway_code, version, title, sequence, duration_minutes, content) values
  ('inventory-basics', 'logistics-foundation-v1', '1.0.0', 'Inventory accuracy basics', 1, 8, '{"format":"text","checkpoint":"preserve_records"}'),
  ('safe-escalation', 'logistics-foundation-v1', '1.0.0', 'When and how to escalate', 2, 6, '{"format":"text","checkpoint":"safe_escalation"}'),
  ('dispatch-priority', 'logistics-foundation-v1', '1.0.0', 'Understanding dispatch priority', 3, 10, '{"format":"text","checkpoint":"sla_priority"}');

insert into public.simulation_definitions
  (code, title, sector, role_profile_id)
select 'inventory-discrepancy', 'Inventory discrepancy', 'logistics', id
from public.role_profiles
where code = 'warehouse_associate' and version = 1;

insert into public.simulation_versions
  (version, simulation_code, graph, scoring_rubric, published_at) values
  (
    'inventory-discrepancy-v1',
    'inventory-discrepancy',
    '{"states":["briefed","active","submitted","scored"],"required_sequence":["decision_selected","records_preserved","exception_escalated"]}',
    '{"dimensions":{"accuracy":0.3333,"safe_escalation":0.3333,"sequence_compliance":0.3334},"technical_events_excluded":true}',
    now()
  );
