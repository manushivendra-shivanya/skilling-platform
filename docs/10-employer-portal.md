# 10 — Employer Portal

**Status: target design, no employer portal UI exists.** Every capability
below is aspirational, same framing as `docs/03-api-specifications.md`'s
Employer APIs section, which this doc should be read alongside rather than
in place of. What's actually shipped is API-only, no UI, guarded by a
per-employer API key (`EmployerAuthGuard`) with no employer login flow at
all: the Employer Evidence Review MVP
(`GET /employer/applicants`, `GET /employer/applicants/{candidateId}/evidence`)
and, from Phase OD-1, direct job and shift posting
(`POST /employer/jobs`, `POST /employer/jobs/:id/publish`,
`GET /employer/jobs`, `POST /employer/shifts`,
`POST /employer/shifts/:id/publish`, `GET /employer/shifts`) — see
`docs/generated/current-state.md` for both. An employer today calls these
directly with an API key; nothing in this document's "Core Capabilities"
list has a screen behind it yet.

## Users
Recruiter, hiring manager, operations manager, SOP owner, interviewer, analyst, and employer administrator.

## Core Capabilities
- Organisation and team setup
- Role/requisition templates
- Competency and evidence thresholds
- Local candidate matching
- Candidate evidence review
- Consent-aware exports/integrations
- Interview scheduling and scorecards
- Offer and joining tracking
- Employer SOP academy
- 30/60/90-day outcome capture
- Analytics and audit

## Candidate Profile View
- candidate-approved identity/contact information,
- location and availability,
- verified competencies,
- simulation evidence,
- voice readiness dimensions,
- reliability band with data window,
- physical verification,
- SOP completion,
- score confidence and recency.

Employers cannot see protected or irrelevant personal attributes.

## Matching
Matching considers explicit job requirements, candidate location/availability, verified competency, evidence recency, and candidate consent. Reliability can be used as one explainable factor but must not become an unreviewable rejection gate.

## SOP Academy
Employer uploads approved source material, defines target audience, assigns reviewers, and publishes a version. The platform can draft content with AI, but employer approval is mandatory.

## Outcomes
Employers provide structured reasons for shortlist, rejection, no-show, offer, joining, and retention. These outcomes improve product analytics but are monitored for biased patterns.
