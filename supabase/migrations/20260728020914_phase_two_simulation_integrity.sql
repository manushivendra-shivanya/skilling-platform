alter table public.simulation_scores
  add constraint simulation_scores_attempt_id_fkey
  foreign key (attempt_id)
  references public.simulation_attempts(id)
  on delete cascade;

create policy "candidate updates own simulation scores"
  on public.simulation_scores for update to authenticated
  using ((select auth.uid()) = candidate_id)
  with check ((select auth.uid()) = candidate_id);

create policy "candidate updates own competency evidence"
  on public.competency_evidence for update to authenticated
  using ((select auth.uid()) = candidate_id)
  with check ((select auth.uid()) = candidate_id);

grant update on public.simulation_scores, public.competency_evidence
  to authenticated;
