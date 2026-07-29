-- Keep server-only tables explicitly closed to authenticated clients while
-- satisfying the RLS linter's requirement for a documented policy boundary.
create policy "authenticated cannot read voice ai runs"
  on public.voice_ai_runs for select to authenticated
  using (false);
create policy "authenticated cannot read voice audit logs"
  on public.voice_audit_logs for select to authenticated
  using (false);

create index voice_sessions_prompt_version_id_idx
  on public.voice_sessions (prompt_version_id);
create index voice_sessions_rubric_id_idx
  on public.voice_sessions (rubric_id);
create index voice_media_session_id_idx
  on public.voice_media_assets (voice_session_id);
create index voice_transcripts_session_id_idx
  on public.voice_transcripts (voice_session_id);
create index voice_ai_runs_prompt_version_id_idx
  on public.voice_ai_runs (prompt_version_id);
create index voice_evaluations_rubric_id_idx
  on public.voice_evaluations (rubric_id);
create index voice_evaluations_ai_run_id_idx
  on public.voice_evaluations (ai_run_id);
create index voice_review_queue_candidate_id_idx
  on public.voice_human_review_queue (candidate_id);
create index voice_appeals_evaluation_id_idx
  on public.voice_appeals (evaluation_id);
create index voice_audit_actor_id_idx
  on public.voice_audit_logs (actor_id);
