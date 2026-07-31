-- Workplace Management Simulation remote persistence foundation.
--
-- This schema mirrors the existing Flutter WMS domain boundaries:
-- - attempt timing is operational lifecycle state;
-- - wms_learner_actions is the only scoreable behaviour stream;
-- - wms_attempt_audit_events is unscored and append-only;
-- - drafts and generated scenario snapshots stay with the attempt aggregate
--   so a future BFF/Supabase adapter can commit them transactionally.

create table public.wms_attempts (
  id text primary key,
  candidate_id uuid not null references auth.users(id) on delete cascade,
  mission_id text not null,
  mission_version text not null,
  attempt_number integer not null check (attempt_number > 0),
  scenario_seed integer not null,
  scenario_id text,
  state text not null check (
    state in (
      'not_started',
      'briefing',
      'in_progress',
      'paused',
      'submitted',
      'evaluated',
      'completed',
      'failed'
    )
  ),
  timer_status text not null check (
    timer_status in ('not_started', 'running', 'paused', 'stopped')
  ),
  current_stage_id text,
  completed_task_ids text[] not null default '{}',
  created_at timestamptz not null,
  briefing_acknowledged_at timestamptz,
  shift_started_at timestamptz,
  paused_at timestamptz,
  timer_resumed_at timestamptz,
  submitted_at timestamptz,
  completed_at timestamptz,
  elapsed_simulation_seconds integer not null default 0
    check (elapsed_simulation_seconds >= 0),
  generated_scenario jsonb,
  drafts jsonb not null default '{}',
  updated_at timestamptz not null default now(),
  unique (candidate_id, mission_id, attempt_number),
  unique (id, candidate_id),
  check (shift_started_at is null or shift_started_at >= created_at),
  check (briefing_acknowledged_at is null or briefing_acknowledged_at >= created_at),
  check (paused_at is null or shift_started_at is not null),
  check (completed_at is null or shift_started_at is not null)
);

create table public.wms_learner_actions (
  id text primary key,
  attempt_id text not null,
  candidate_id uuid not null,
  mission_id text not null,
  mission_version text not null,
  stage_id text not null,
  task_id text not null,
  action_type text not null,
  target_id text,
  payload jsonb not null default '{}',
  sequence_number integer not null check (sequence_number > 0),
  simulation_time_seconds integer not null check (simulation_time_seconds >= 0),
  created_at timestamptz not null,
  is_technical boolean not null default false check (is_technical = false),
  foreign key (attempt_id, candidate_id)
    references public.wms_attempts (id, candidate_id)
    on delete cascade,
  unique (attempt_id, sequence_number)
);

create table public.wms_attempt_audit_events (
  id text primary key,
  attempt_id text not null,
  candidate_id uuid not null,
  mission_id text not null,
  mission_version text not null,
  screen_id text not null,
  event_type text not null,
  target_id text,
  sequence_number integer not null check (sequence_number > 0),
  simulation_elapsed_seconds integer not null
    check (simulation_elapsed_seconds >= 0),
  occurred_at timestamptz not null,
  payload jsonb not null default '{}',
  foreign key (attempt_id, candidate_id)
    references public.wms_attempts (id, candidate_id)
    on delete cascade,
  unique (attempt_id, sequence_number)
);

create table public.wms_attempt_results (
  attempt_id text primary key,
  candidate_id uuid not null,
  mission_id text not null,
  mission_version text not null,
  scenario_seed integer not null,
  status text not null check (
    status in ('passed', 'retry_recommended', 'critical_failure', 'incomplete')
  ),
  overall_score numeric(5, 2) not null check (
    overall_score >= 0 and overall_score <= 100
  ),
  category_scores jsonb not null default '{}',
  competency_scores jsonb not null default '[]',
  mandatory_tasks_completed boolean not null,
  critical_errors jsonb not null default '[]',
  correct_actions text[] not null default '{}',
  missed_issues text[] not null default '{}',
  recommended_remediation_ids text[] not null default '{}',
  result jsonb not null,
  completed_at timestamptz not null,
  foreign key (attempt_id, candidate_id)
    references public.wms_attempts (id, candidate_id)
    on delete cascade
);

create table public.wms_competency_evidence (
  id text primary key,
  attempt_id text not null,
  candidate_id uuid not null,
  mission_id text not null,
  mission_version text not null,
  scenario_seed integer not null,
  competency_id text not null,
  score integer not null check (score between 0 and 100),
  evidence_type text not null,
  title text not null,
  description text not null,
  verification_status text not null,
  evidence jsonb not null default '{}',
  issued_at timestamptz not null,
  foreign key (attempt_id, candidate_id)
    references public.wms_attempts (id, candidate_id)
    on delete cascade
);

create index wms_attempts_candidate_mission_state_idx
  on public.wms_attempts (candidate_id, mission_id, state);
create index wms_attempts_candidate_updated_idx
  on public.wms_attempts (candidate_id, updated_at desc);
create index wms_learner_actions_candidate_created_idx
  on public.wms_learner_actions (candidate_id, created_at);
create index wms_attempt_audit_events_candidate_occurred_idx
  on public.wms_attempt_audit_events (candidate_id, occurred_at);
create index wms_attempt_results_candidate_completed_idx
  on public.wms_attempt_results (candidate_id, completed_at desc);
create index wms_competency_evidence_candidate_issued_idx
  on public.wms_competency_evidence (candidate_id, issued_at desc);
create index wms_competency_evidence_competency_idx
  on public.wms_competency_evidence (competency_id, issued_at desc);

alter table public.wms_attempts enable row level security;
alter table public.wms_learner_actions enable row level security;
alter table public.wms_attempt_audit_events enable row level security;
alter table public.wms_attempt_results enable row level security;
alter table public.wms_competency_evidence enable row level security;

create policy "candidate reads own wms attempts"
  on public.wms_attempts for select to authenticated
  using ((select auth.uid()) = candidate_id);
create policy "candidate creates own wms attempts"
  on public.wms_attempts for insert to authenticated
  with check ((select auth.uid()) = candidate_id);
create policy "candidate updates own wms attempts"
  on public.wms_attempts for update to authenticated
  using ((select auth.uid()) = candidate_id)
  with check ((select auth.uid()) = candidate_id);

create policy "candidate reads own wms learner actions"
  on public.wms_learner_actions for select to authenticated
  using ((select auth.uid()) = candidate_id);
create policy "candidate appends own wms learner actions"
  on public.wms_learner_actions for insert to authenticated
  with check (
    (select auth.uid()) = candidate_id
    and exists (
      select 1 from public.wms_attempts attempt
      where attempt.id = wms_learner_actions.attempt_id
        and attempt.candidate_id = (select auth.uid())
        and attempt.state in ('in_progress', 'paused')
    )
  );

create policy "candidate reads own wms audit events"
  on public.wms_attempt_audit_events for select to authenticated
  using ((select auth.uid()) = candidate_id);
create policy "candidate appends own wms audit events"
  on public.wms_attempt_audit_events for insert to authenticated
  with check (
    (select auth.uid()) = candidate_id
    and exists (
      select 1 from public.wms_attempts attempt
      where attempt.id = wms_attempt_audit_events.attempt_id
        and attempt.candidate_id = (select auth.uid())
    )
  );

create policy "candidate reads own wms results"
  on public.wms_attempt_results for select to authenticated
  using ((select auth.uid()) = candidate_id);
create policy "candidate creates own wms results"
  on public.wms_attempt_results for insert to authenticated
  with check ((select auth.uid()) = candidate_id);

create policy "candidate reads own wms competency evidence"
  on public.wms_competency_evidence for select to authenticated
  using ((select auth.uid()) = candidate_id);
create policy "candidate creates own wms competency evidence"
  on public.wms_competency_evidence for insert to authenticated
  with check ((select auth.uid()) = candidate_id);

grant select, insert, update on public.wms_attempts to authenticated;
grant select, insert on public.wms_learner_actions to authenticated;
grant select, insert on public.wms_attempt_audit_events to authenticated;
grant select, insert on public.wms_attempt_results to authenticated;
grant select, insert on public.wms_competency_evidence to authenticated;

comment on table public.wms_attempts is
  'Candidate-owned Workplace Management Simulation attempt aggregate, including operational timer lifecycle, draft state and scenario provenance.';
comment on table public.wms_learner_actions is
  'Append-only scoreable WMS learner behaviour stream. Technical and lifecycle events belong in wms_attempt_audit_events.';
comment on table public.wms_attempt_audit_events is
  'Append-only unscored WMS lifecycle, analytics and UI audit event stream.';
comment on table public.wms_attempt_results is
  'Final deterministic WMS scoring result payload for a completed attempt.';
comment on table public.wms_competency_evidence is
  'Candidate-owned WMS competency evidence generated from simulation results; this is not a regulated certification.';
