-- Tighten the WMS table grant surface after initial creation.
-- RLS already blocks unsupported row operations, but exposed public-schema
-- tables should also grant only the operations the current adapter contract
-- needs.

revoke all on public.wms_attempts from anon, authenticated;
revoke all on public.wms_learner_actions from anon, authenticated;
revoke all on public.wms_attempt_audit_events from anon, authenticated;
revoke all on public.wms_attempt_results from anon, authenticated;
revoke all on public.wms_competency_evidence from anon, authenticated;

grant select, insert, update on public.wms_attempts to authenticated;
grant select, insert on public.wms_learner_actions to authenticated;
grant select, insert on public.wms_attempt_audit_events to authenticated;
grant select, insert on public.wms_attempt_results to authenticated;
grant select, insert on public.wms_competency_evidence to authenticated;
