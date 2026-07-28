create table public.voice_prompt_versions (
  id uuid primary key default gen_random_uuid(),
  prompt_id text not null,
  version text not null,
  use_case text not null check (
    use_case in ('voice_interviewer', 'voice_evaluator')
  ),
  input_schema jsonb not null default '{}',
  output_schema jsonb not null default '{}',
  safety_constraints jsonb not null default '{}',
  status text not null check (status in ('draft', 'approved', 'retired')),
  created_at timestamptz not null default now(),
  unique (prompt_id, version)
);

create table public.voice_rubrics (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  version text not null,
  dimensions jsonb not null,
  safety_constraints jsonb not null default '{}',
  status text not null check (status in ('draft', 'approved', 'retired')),
  created_at timestamptz not null default now(),
  unique (code, version)
);

create table public.voice_consents (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references auth.users(id) on delete cascade,
  recording boolean not null,
  transcription boolean not null,
  evaluation boolean not null,
  employer_sharing boolean not null default false,
  policy_version text not null,
  granted_at timestamptz not null default now(),
  revoked_at timestamptz,
  check (
    not (recording or transcription or evaluation)
    or (recording and transcription and evaluation)
  )
);

create table public.voice_sessions (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references auth.users(id) on delete cascade,
  session_type text not null default 'practice'
    check (session_type in ('practice', 'application')),
  language text not null default 'en-IN',
  prompt_version_id uuid not null
    references public.voice_prompt_versions(id),
  rubric_id uuid not null references public.voice_rubrics(id),
  status text not null check (
    status in (
      'consent',
      'ready',
      'recording',
      'transcribing',
      'reviewing',
      'evaluating',
      'completed',
      'failed',
      'deleted'
    )
  ),
  technical_failure boolean not null default false,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  deleted_at timestamptz
);

create table public.voice_turns (
  id uuid primary key default gen_random_uuid(),
  voice_session_id uuid not null
    references public.voice_sessions(id) on delete cascade,
  question_id text not null,
  sequence integer not null check (sequence > 0),
  local_client_id text not null,
  duration_ms integer check (duration_ms is null or duration_ms >= 0),
  upload_status text not null default 'pending' check (
    upload_status in ('pending', 'uploading', 'uploaded', 'failed', 'deleted')
  ),
  technical_failure boolean not null default false,
  created_at timestamptz not null default now(),
  unique (voice_session_id, sequence),
  unique (voice_session_id, local_client_id)
);

create table public.voice_media_assets (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references auth.users(id) on delete cascade,
  voice_session_id uuid not null
    references public.voice_sessions(id) on delete cascade,
  voice_turn_id uuid not null
    references public.voice_turns(id) on delete cascade,
  purpose text not null check (purpose = 'voice_interview_turn'),
  storage_key text,
  mime_type text not null,
  duration_ms integer check (duration_ms is null or duration_ms >= 0),
  retention_class text not null default 'candidate_voice_30d',
  upload_status text not null default 'pending' check (
    upload_status in ('pending', 'uploading', 'uploaded', 'failed', 'deleted')
  ),
  checksum_sha256 text,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (voice_turn_id)
);

create table public.voice_transcripts (
  id uuid primary key default gen_random_uuid(),
  voice_session_id uuid not null
    references public.voice_sessions(id) on delete cascade,
  voice_turn_id uuid not null
    references public.voice_turns(id) on delete cascade,
  candidate_id uuid not null references auth.users(id) on delete cascade,
  provider text not null,
  language text not null default 'en-IN',
  transcript_text text not null,
  segments jsonb not null default '[]',
  confidence numeric(5, 4) check (
    confidence is null or (confidence >= 0 and confidence <= 1)
  ),
  candidate_reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (voice_turn_id)
);

create table public.voice_ai_runs (
  id uuid primary key default gen_random_uuid(),
  voice_session_id uuid not null
    references public.voice_sessions(id) on delete cascade,
  use_case text not null check (
    use_case in ('voice_transcription', 'voice_evaluation')
  ),
  provider text not null,
  model text not null,
  prompt_version_id uuid references public.voice_prompt_versions(id),
  input_hash text not null,
  output_payload jsonb,
  latency_ms integer check (latency_ms is null or latency_ms >= 0),
  cost_minor_units integer check (
    cost_minor_units is null or cost_minor_units >= 0
  ),
  status text not null check (
    status in ('queued', 'running', 'completed', 'failed', 'review_required')
  ),
  error_code text,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

create table public.voice_evaluations (
  id uuid primary key default gen_random_uuid(),
  voice_session_id uuid not null
    references public.voice_sessions(id) on delete cascade,
  candidate_id uuid not null references auth.users(id) on delete cascade,
  rubric_id uuid not null references public.voice_rubrics(id),
  ai_run_id uuid references public.voice_ai_runs(id),
  result jsonb not null,
  confidence numeric(5, 4) not null check (
    confidence >= 0 and confidence <= 1
  ),
  review_status text not null default 'required' check (
    review_status in (
      'required',
      'requested',
      'in_review',
      'confirmed',
      'corrected'
    )
  ),
  created_at timestamptz not null default now(),
  unique (voice_session_id)
);

create table public.voice_human_review_queue (
  id uuid primary key default gen_random_uuid(),
  evaluation_id uuid not null
    references public.voice_evaluations(id) on delete cascade,
  candidate_id uuid not null references auth.users(id) on delete cascade,
  reason text not null,
  status text not null default 'requested' check (
    status in ('requested', 'assigned', 'completed', 'cancelled')
  ),
  requested_at timestamptz not null default now(),
  assigned_at timestamptz,
  reviewed_at timestamptz,
  unique (evaluation_id)
);

create table public.voice_feedback (
  id uuid primary key default gen_random_uuid(),
  evaluation_id uuid not null
    references public.voice_evaluations(id) on delete cascade,
  candidate_id uuid not null references auth.users(id) on delete cascade,
  summary text not null,
  improvement_guidance text not null,
  dimensions jsonb not null,
  is_employer_visible boolean not null default false,
  created_at timestamptz not null default now(),
  unique (evaluation_id)
);

create table public.voice_appeals (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references auth.users(id) on delete cascade,
  evaluation_id uuid not null
    references public.voice_evaluations(id) on delete cascade,
  reason text not null check (char_length(reason) between 10 and 2000),
  status text not null default 'submitted' check (
    status in ('submitted', 'in_review', 'resolved', 'withdrawn')
  ),
  submitted_at timestamptz not null default now(),
  resolved_at timestamptz
);

create table public.voice_audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id) on delete set null,
  voice_session_id uuid references public.voice_sessions(id) on delete set null,
  action text not null,
  subject_type text not null,
  subject_id text,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create index voice_consents_candidate_active_idx
  on public.voice_consents (candidate_id, granted_at desc)
  where revoked_at is null;
create index voice_sessions_candidate_status_idx
  on public.voice_sessions (candidate_id, status, started_at desc);
create index voice_turns_session_sequence_idx
  on public.voice_turns (voice_session_id, sequence);
create index voice_media_candidate_status_idx
  on public.voice_media_assets (candidate_id, upload_status);
create index voice_transcripts_candidate_idx
  on public.voice_transcripts (candidate_id, created_at desc);
create index voice_ai_runs_session_status_idx
  on public.voice_ai_runs (voice_session_id, status);
create index voice_evaluations_candidate_review_idx
  on public.voice_evaluations (candidate_id, review_status, created_at desc);
create index voice_review_queue_status_idx
  on public.voice_human_review_queue (status, requested_at);
create index voice_feedback_candidate_idx
  on public.voice_feedback (candidate_id, created_at desc);
create index voice_appeals_candidate_idx
  on public.voice_appeals (candidate_id, submitted_at desc);
create index voice_audit_session_idx
  on public.voice_audit_logs (voice_session_id, created_at);

alter table public.voice_prompt_versions enable row level security;
alter table public.voice_rubrics enable row level security;
alter table public.voice_consents enable row level security;
alter table public.voice_sessions enable row level security;
alter table public.voice_turns enable row level security;
alter table public.voice_media_assets enable row level security;
alter table public.voice_transcripts enable row level security;
alter table public.voice_ai_runs enable row level security;
alter table public.voice_evaluations enable row level security;
alter table public.voice_human_review_queue enable row level security;
alter table public.voice_feedback enable row level security;
alter table public.voice_appeals enable row level security;
alter table public.voice_audit_logs enable row level security;

create policy "authenticated reads approved voice prompts"
  on public.voice_prompt_versions for select to authenticated
  using (status = 'approved');
create policy "authenticated reads approved voice rubrics"
  on public.voice_rubrics for select to authenticated
  using (status = 'approved');

create policy "candidate reads own voice consents"
  on public.voice_consents for select to authenticated
  using ((select auth.uid()) = candidate_id);
create policy "candidate creates own voice consents"
  on public.voice_consents for insert to authenticated
  with check ((select auth.uid()) = candidate_id);
create policy "candidate revokes own voice consents"
  on public.voice_consents for update to authenticated
  using ((select auth.uid()) = candidate_id)
  with check ((select auth.uid()) = candidate_id);

create policy "candidate reads own voice sessions"
  on public.voice_sessions for select to authenticated
  using ((select auth.uid()) = candidate_id);
create policy "candidate creates own practice voice sessions"
  on public.voice_sessions for insert to authenticated
  with check (
    (select auth.uid()) = candidate_id
    and session_type = 'practice'
  );
create policy "candidate updates own practice voice sessions"
  on public.voice_sessions for update to authenticated
  using (
    (select auth.uid()) = candidate_id
    and session_type = 'practice'
  )
  with check (
    (select auth.uid()) = candidate_id
    and session_type = 'practice'
  );

create policy "candidate reads own voice turns"
  on public.voice_turns for select to authenticated
  using (
    exists (
      select 1
      from public.voice_sessions session
      where session.id = voice_turns.voice_session_id
        and session.candidate_id = (select auth.uid())
    )
  );
create policy "candidate creates turns in own practice session"
  on public.voice_turns for insert to authenticated
  with check (
    exists (
      select 1
      from public.voice_sessions session
      where session.id = voice_turns.voice_session_id
        and session.candidate_id = (select auth.uid())
        and session.session_type = 'practice'
    )
  );
create policy "candidate updates turns in own practice session"
  on public.voice_turns for update to authenticated
  using (
    exists (
      select 1
      from public.voice_sessions session
      where session.id = voice_turns.voice_session_id
        and session.candidate_id = (select auth.uid())
        and session.session_type = 'practice'
    )
  )
  with check (
    exists (
      select 1
      from public.voice_sessions session
      where session.id = voice_turns.voice_session_id
        and session.candidate_id = (select auth.uid())
        and session.session_type = 'practice'
    )
  );

create policy "candidate reads own voice media metadata"
  on public.voice_media_assets for select to authenticated
  using ((select auth.uid()) = candidate_id);
create policy "candidate creates own practice voice media metadata"
  on public.voice_media_assets for insert to authenticated
  with check (
    (select auth.uid()) = candidate_id
    and exists (
      select 1
      from public.voice_sessions session
      where session.id = voice_media_assets.voice_session_id
        and session.candidate_id = (select auth.uid())
        and session.session_type = 'practice'
    )
  );
create policy "candidate updates own practice voice media metadata"
  on public.voice_media_assets for update to authenticated
  using ((select auth.uid()) = candidate_id)
  with check ((select auth.uid()) = candidate_id);

create policy "candidate reads own voice transcripts"
  on public.voice_transcripts for select to authenticated
  using ((select auth.uid()) = candidate_id);
create policy "candidate reviews own voice transcripts"
  on public.voice_transcripts for update to authenticated
  using ((select auth.uid()) = candidate_id)
  with check ((select auth.uid()) = candidate_id);

create policy "candidate reads own voice evaluations"
  on public.voice_evaluations for select to authenticated
  using ((select auth.uid()) = candidate_id);
create policy "candidate reads own voice review requests"
  on public.voice_human_review_queue for select to authenticated
  using ((select auth.uid()) = candidate_id);
create policy "candidate requests review for own evaluation"
  on public.voice_human_review_queue for insert to authenticated
  with check (
    (select auth.uid()) = candidate_id
    and exists (
      select 1
      from public.voice_evaluations evaluation
      where evaluation.id = voice_human_review_queue.evaluation_id
        and evaluation.candidate_id = (select auth.uid())
    )
  );
create policy "candidate reads own voice feedback"
  on public.voice_feedback for select to authenticated
  using ((select auth.uid()) = candidate_id);
create policy "candidate reads own voice appeals"
  on public.voice_appeals for select to authenticated
  using ((select auth.uid()) = candidate_id);
create policy "candidate creates own voice appeals"
  on public.voice_appeals for insert to authenticated
  with check (
    (select auth.uid()) = candidate_id
    and exists (
      select 1
      from public.voice_evaluations evaluation
      where evaluation.id = voice_appeals.evaluation_id
        and evaluation.candidate_id = (select auth.uid())
    )
  );

revoke all on table public.voice_prompt_versions from anon, authenticated;
revoke all on table public.voice_rubrics from anon, authenticated;
revoke all on table public.voice_consents from anon, authenticated;
revoke all on table public.voice_sessions from anon, authenticated;
revoke all on table public.voice_turns from anon, authenticated;
revoke all on table public.voice_media_assets from anon, authenticated;
revoke all on table public.voice_transcripts from anon, authenticated;
revoke all on table public.voice_ai_runs from anon, authenticated;
revoke all on table public.voice_evaluations from anon, authenticated;
revoke all on table public.voice_human_review_queue from anon, authenticated;
revoke all on table public.voice_feedback from anon, authenticated;
revoke all on table public.voice_appeals from anon, authenticated;
revoke all on table public.voice_audit_logs from anon, authenticated;

grant select on public.voice_prompt_versions, public.voice_rubrics
  to authenticated;
grant select, insert, update on public.voice_consents,
  public.voice_sessions, public.voice_turns, public.voice_media_assets
  to authenticated;
grant select, update on public.voice_transcripts to authenticated;
grant select on public.voice_evaluations, public.voice_feedback
  to authenticated;
grant select, insert on public.voice_human_review_queue,
  public.voice_appeals to authenticated;

insert into public.voice_prompt_versions (
  prompt_id,
  version,
  use_case,
  input_schema,
  output_schema,
  safety_constraints,
  status
) values
  (
    'P-VOICE-INTERVIEWER-001',
    '1.0.0',
    'voice_interviewer',
    '{"required":["candidate_id","language","question_manifest"]}',
    '{"required":["question_id","prompt_text"]}',
    '{
      "forbidden_inferences":["accent","emotion","personality","protected_traits"],
      "technical_failures_excluded":true,
      "human_review_required":true
    }',
    'approved'
  ),
  (
    'P-VOICE-EVALUATOR-001',
    '1.0.0',
    'voice_evaluator',
    '{"required":["reviewed_transcripts","rubric_version"]}',
    '{"required":["dimensions","confidence","improvement_guidance"]}',
    '{
      "transcript_only":true,
      "forbidden_inferences":["accent","emotion","personality","protected_traits"],
      "autonomous_rejection_forbidden":true,
      "technical_failures_excluded":true,
      "human_review_required":true
    }',
    'approved'
  );

insert into public.voice_rubrics (
  code,
  version,
  dimensions,
  safety_constraints,
  status
) values (
  'voice-logistics',
  'v1',
  '{
    "relevance":{"weight":0.20},
    "operational_correctness":{"weight":0.25},
    "structure":{"weight":0.20},
    "clarity":{"weight":0.15},
    "safe_escalation":{"weight":0.20}
  }',
  '{
    "audio_characteristics_excluded":true,
    "technical_failures_excluded":true,
    "human_review_required":true
  }',
  'approved'
);

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
) values (
  'voice-media',
  'voice-media',
  false,
  15728640,
  array['audio/mp4', 'audio/aac', 'audio/m4a']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- No authenticated storage.objects policies are created intentionally.
-- The planned NestJS BFF will authorize each candidate-owned media operation
-- and issue short-lived signed upload/download credentials. Service-role access
-- remains server-only and must never be embedded in the Flutter application.
