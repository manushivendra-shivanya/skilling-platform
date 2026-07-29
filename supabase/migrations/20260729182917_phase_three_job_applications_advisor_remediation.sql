-- Performance advisor: unindexed foreign key on public.jobs.role_profile_id.
create index jobs_role_profile_id_idx on public.jobs (role_profile_id);
