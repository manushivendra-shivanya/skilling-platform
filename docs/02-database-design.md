# 02 — Database Design

## Principles
- PostgreSQL is the system of record.
- UUID primary keys.
- UTC timestamps; store candidate timezone separately.
- Soft deletion only where legally and operationally appropriate.
- Immutable versions for rubrics, simulations, prompts, and assessments.
- PII separation and field-level encryption for sensitive identifiers.
- Append-only audit and financial ledgers.

## Core Schemas and Tables

### Identity
- `users(id, phone_e164, email, status, preferred_language, created_at)`
- `user_devices(id, user_id, platform, push_token, last_seen_at)`
- `roles(id, code)`
- `user_role_assignments(user_id, role_id, tenant_id, scope)`
- `auth_sessions(id, user_id, expires_at, revoked_at)`

### Candidate
- `candidate_profiles(user_id, display_name, city_id, education_level, experience_months, availability)`
- `candidate_languages(candidate_id, language_code, proficiency_self_reported)`
- `candidate_documents(id, candidate_id, type, storage_key, verification_status)`
- `consent_grants(id, candidate_id, purpose, policy_version, granted_at, revoked_at)`
- `employer_sharing_grants(id, candidate_id, employer_id, scope, expires_at, revoked_at)`

### Competency and Learning
- `competencies(id, code, name, domain, parent_id)`
- `role_profiles(id, code, name, sector, version, status)`
- `role_competency_requirements(role_profile_id, competency_id, target_level, weight)`
- `learning_pathways(id, role_profile_id, version, status)`
- `learning_units(id, pathway_id, type, title, sequence, content_ref)`
- `learning_attempts(id, candidate_id, unit_id, status, started_at, completed_at)`

### Assessments
- `assessment_definitions(id, type, version, rubric_id, status)`
- `assessment_attempts(id, candidate_id, definition_id, status, raw_score, normalised_score)`
- `assessment_responses(id, attempt_id, item_id, response_json, duration_ms)`
- `rubrics(id, code, version, schema_json, status)`
- `competency_evidence(id, candidate_id, competency_id, source_type, source_id, score, confidence, rubric_version)`

### Simulation
- `simulation_definitions(id, code, title, sector, role_profile_id)`
- `simulation_versions(id, simulation_id, version, graph_json, rubric_id, published_at)`
- `simulation_attempts(id, candidate_id, simulation_version_id, status, started_at, submitted_at)`
- `simulation_events(id, attempt_id, seq, event_type, payload_json, client_time, server_time)`
- `simulation_scores(id, attempt_id, total_score, dimension_scores_json, explanation_json)`

### Voice and AI
- `voice_sessions(id, candidate_id, session_type, language, rubric_id, status)`
- `media_assets(id, owner_id, purpose, storage_key, mime_type, duration_ms, retention_class)`
- `transcripts(id, voice_session_id, provider, language, segments_json, confidence)`
- `ai_runs(id, use_case, model, prompt_version, input_hash, output_json, latency_ms, cost_minor, status)`
- `ai_evaluations(id, source_type, source_id, rubric_id, result_json, confidence, reviewer_status)`
- `score_appeals(id, candidate_id, score_source_type, score_source_id, reason, status, resolution)`

### Reliability Graph
- `reliability_events(id, candidate_id, event_type, scheduled_at, occurred_at, outcome, source_id)`
- `reliability_score_versions(id, version, model_json, validation_report_ref)`
- `candidate_reliability_scores(candidate_id, score_version_id, score_300_900, band, explanation_json, calculated_at)`

### Employer and Hiring
- `employers(id, legal_name, display_name, status)`
- `employer_members(id, employer_id, user_id, role)`
- `locations(id, employer_id, city_id, name, geo_json)`
- `job_requisitions(id, employer_id, role_profile_id, location_id, openings, status)`
- `requisition_requirements(id, requisition_id, competency_id, minimum_score)`
- `applications(id, candidate_id, requisition_id, source, status)`
- `shortlist_decisions(id, application_id, actor_type, reasons_json)`
- `interviews(id, application_id, scheduled_at, mode, status)`
- `offers(id, application_id, compensation_json, joining_date, status)`
- `employment_outcomes(id, offer_id, joined_at, day30_status, day60_status, day90_status)`

### Employer SOP
- `sop_programmes(id, employer_id, role_profile_id, name, status)`
- `sop_versions(id, programme_id, version, content_manifest_json, approved_by)`
- `sop_assignments(id, candidate_id, sop_version_id, requisition_id, status)`

### Phygital and Micro-Gigs
- `partner_centres(id, partner_id, location, capabilities_json, status)`
- `physical_assessment_slots(id, centre_id, assessment_type, starts_at, capacity)`
- `physical_assessment_results(id, candidate_id, slot_id, assessor_id, evidence_json, status)`
- Micro-gigs shipped as the "Shift Marketplace" (Phase OD-1) under
  different table names than proposed here — see
  `supabase/migrations/20260808000000_phase_od1_shift_marketplace.sql`:
  `shift_requests`, `shift_applications`, `shift_payouts`,
  `shift_grievances`, `candidate_shift_availability`. The
  `micro_gigs`/`micro_gig_assignments`/`wallet_ledger` names below were
  never built and should be read as superseded, not additional/pending.
  ~~`micro_gigs(id, employer_id, title, deliverable_json, stipend_minor, status)`~~
  ~~`micro_gig_assignments(id, gig_id, candidate_id, status, accepted_at, completed_at)`~~
  ~~`wallet_ledger(id, candidate_id, entry_type, amount_minor, currency, reference_type, reference_id)`~~

### Platform
- `notifications(id, user_id, channel, template, payload_json, status)`
- `audit_logs(id, actor_id, actor_type, action, resource_type, resource_id, before_json, after_json)`
- `outbox_events(id, aggregate_type, aggregate_id, event_type, payload_json, published_at)`
- `feature_flags(id, key, rules_json, status)`

## Indexing
- Composite indexes on tenant and status.
- Partial indexes for active jobs and pending work.
- Unique `(attempt_id, seq)` for simulation events.
- GIN indexes only for specific JSON querying patterns.
- Partition high-volume event and AI-run tables by time when needed.

## Retention
Audio, raw transcripts, identity documents, and AI inputs have separate retention classes. Revocation stops new processing and triggers policy-based deletion or anonymisation where legally permitted.
