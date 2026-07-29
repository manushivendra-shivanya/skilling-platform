revoke execute on function public.rls_auto_enable() from public;
revoke execute on function public.rls_auto_enable() from anon;
revoke execute on function public.rls_auto_enable() from authenticated;

create index competency_evidence_competency_code_idx
  on public.competency_evidence (competency_code);
create index diagnostic_results_definition_version_idx
  on public.diagnostic_results (definition_version);
create index learning_pathways_role_profile_id_idx
  on public.learning_pathways (role_profile_id);
create index role_requirements_competency_code_idx
  on public.role_competency_requirements (competency_code);
create index simulation_attempts_version_idx
  on public.simulation_attempts (simulation_version);
create index simulation_definitions_role_profile_id_idx
  on public.simulation_definitions (role_profile_id);
create index simulation_scores_version_idx
  on public.simulation_scores (simulation_version);
create index simulation_versions_definition_idx
  on public.simulation_versions (simulation_code);
