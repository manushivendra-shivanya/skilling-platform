# 16 — Sprint-by-Sprint Development Plan (Superseded)

**This plan was never followed and is kept for history only.** Actual
development went by `docs/20-codex-phase-execution.md`'s phase structure
(Phase 1 — mobile shell, Phase 2 — candidate intelligence, and onward
through the phases recorded in `docs/generated/current-state.md`), not the
sprint numbering below. The two were never reconciled: this file plans web
portals in Sprint 9–10 and an ATS integration in Sprint 15, none of which
exist, while `docs/20` and `current-state.md` reflect a mobile-first,
API-second build order that shipped a real Career Passport, Shift
Marketplace, and job sourcing pipeline nothing here anticipated by name.

Treat `docs/20-codex-phase-execution.md` and `docs/generated/current-state.md`
as authoritative for what to build next and what already exists. This file
is left below only as a record of the original two-week-sprint plan drafted
before Phase 1 started.

---

Two-week sprints. Dates begin when the team starts.

## Sprint 0 — Foundation
- Finalise ADRs and stack.
- Scaffold monorepo.
- CI, environments, secrets, observability.
- Design tokens and basic component libraries.
- Database migrations and seed framework.
- Authentication spike.

Exit: all apps build, preview deploys work, baseline security checks pass.

## Sprint 1 — Candidate Identity and Onboarding
- OTP login.
- candidate profile.
- language/location/experience.
- consent centre.
- mobile navigation and analytics.

Exit: candidate completes onboarding and resumes session.

## Sprint 2 — Role Taxonomy and Diagnostic
- role profiles and competencies.
- diagnostic authoring format.
- assessment runtime.
- result and pathway recommendation.

Exit: logistics diagnostic produces explainable competency gaps.

## Sprint 3 — Learning Pathway
- pathway home.
- daily mission.
- content player.
- checks and progress.
- offline content basics.

## Sprint 4 — Simulation Runtime v1
- simulation schema.
- event ingestion.
- state machine.
- deterministic scoring.
- inventory discrepancy simulation.

## Sprint 5 — Simulation Authoring and Evidence
- admin builder v1.
- rubric versions.
- evidence profile.
- second and third logistics simulations.
- attempt review.

## Sprint 6 — Voice Capture and Transcription
- permissions/audio check.
- recorded-turn sessions.
- media upload.
- transcription.
- transcript review and deletion.

## Sprint 7 — Voice Interview and Evaluation
- dialogue manager.
- structured interview plan.
- rubric evaluation.
- coaching feedback.
- quality review queue.

## Sprint 8 — Candidate Jobs
- job feed/details.
- consented application.
- application tracker.
- interview reminders.

## Sprint 9 — Employer Portal v1
- tenant/team setup.
- requisition creation.
- candidate matches.
- evidence profile.
- shortlist and interview scheduling.

## Sprint 10 — Employer SOP Academy
- document upload.
- AI-assisted draft.
- employer review/publish.
- candidate assignment and completion.

## Sprint 11 — Offers and Outcomes
- offer/joining tracker.
- 30/60/90-day outcomes.
- candidate onboarding missions.
- employer retention dashboard.

## Sprint 12 — Reliability Dimensions v1
- reliability event taxonomy.
- candidate explanation UI.
- employer view with consent.
- fairness and calibration dashboard.

## Sprint 13 — Phygital Pilot
- centre/assessor setup.
- slots and booking.
- physical assessment evidence.
- verification badge.

## Sprint 14 — Micro-Gig Pilot
- gig creation and assignment.
- deliverable evidence.
- dispute workflow.
- stipend ledger and payment-provider adapter.

## Sprint 15 — Integration Framework
- canonical integration model.
- connection management.
- webhooks and reconciliation.
- first approved ATS adapter.

## Sprint 16 — Hardening and Pilot Launch
- performance and load tests.
- accessibility pass.
- security review.
- AI regression suite.
- support runbooks.
- pilot analytics dashboard.

## Phase Gates
Each sprint requires demo, acceptance evidence, test report, documentation update, and rollback plan. Sector expansion begins only after employer and candidate outcome review.
