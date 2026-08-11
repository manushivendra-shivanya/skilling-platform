# 11 — Admin Portal

**Status: target design, entirely unbuilt.** No admin portal UI, API
surface, or role/permission system exists anywhere in the repo — unlike
the Employer Portal (`docs/10-employer-portal.md`), which at least has a
narrow, real API surface behind it, nothing below has any implementation
to point to. Content authoring today happens by editing versioned JSON
directly in `apps/candidate-mobile/assets/` and Supabase migrations, not
through any admin tooling.

## Roles
Super admin, operations admin, curriculum author, simulation author, AI quality reviewer, employer success, candidate support, trust and safety, finance operations, analyst, and auditor.

## Functional Areas
- Candidate support timeline
- Employer and partner management
- Taxonomy and role management
- Learning content authoring
- Simulation authoring/versioning
- Rubric and prompt registry
- AI run inspection
- Human evaluation queue
- Appeals and grievance resolution
- Voice quality monitoring
- Physical centre and assessor management
- Micro-gig and wallet operations
- Notification templates
- Feature flags
- Policy and consent versions
- Integration health
- Audit and security events

## Admin Safety Controls
- Least privilege.
- Just-in-time elevated access.
- Reason required for sensitive actions.
- Audited candidate impersonation with visible banner.
- Four-eyes approval for prompt/rubric publication, wallet adjustments, and data exports.
- PII masking by default.

## Publishing Workflow
Draft → reviewer comments → validation checks → approval → scheduled publish → rollback to prior version.
