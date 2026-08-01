# 03 — API Specifications

## Conventions
- Base path: `/v1`
- JSON over HTTPS; WebSocket/WebRTC for approved real-time voice flows.
- OAuth/session token for clients; service tokens for internal services.
- `Idempotency-Key` required for sensitive mutations.
- Cursor pagination.
- Errors use stable machine codes and human-readable messages.
- Every response includes `request_id`.
- OpenAPI is generated and version controlled.

## Standard Error
```json
{
  "error": {
    "code": "SIMULATION_ATTEMPT_ALREADY_SUBMITTED",
    "message": "This attempt has already been submitted.",
    "details": {},
    "request_id": "req_..."
  }
}
```

## Candidate APIs
- `POST /auth/otp/request`
- `POST /auth/otp/verify`
- `GET /me`
- `PATCH /me/profile`
- `GET /me/consents`
- `POST /me/consents`
- `DELETE /me/consents/{purpose}`
- `GET /roles`
- `POST /diagnostics/attempts`
- `POST /diagnostics/attempts/{id}/responses`
- `POST /diagnostics/attempts/{id}/submit`
- `GET /me/pathway`
- `GET /me/dashboard`
- `GET /me/evidence`

## Simulation APIs
- `GET /simulations/{id}/versions/current`
- `POST /simulation-attempts`
- `POST /simulation-attempts/{id}/events:batch`
- `POST /simulation-attempts/{id}/submit`
- `GET /simulation-attempts/{id}/result`
- `POST /simulation-attempts/{id}/appeals`
- `POST /workplace-simulation/attempts/{id}/sync`

Example event batch:
```json
{
  "events": [
    {"seq": 1, "type": "SCREEN_OPENED", "client_time": "...", "payload": {"screen":"inventory_check"}},
    {"seq": 2, "type": "ITEM_SCANNED", "client_time": "...", "payload": {"sku":"SKU-10"}}
  ]
}
```

### Workplace Simulation sync

`POST /workplace-simulation/attempts/{id}/sync` is the BFF persistence
boundary for the local-first Workplace Management Simulation controller. It
requires:

- `Authorization: Bearer <candidate JWT>`
- `Idempotency-Key`

The request body contains the already-produced controller state:

- `attempt` — lifecycle, timer, completed tasks, drafts, scoreable learner
  actions and unscored audit events
- `generatedScenario` — optional generated scenario snapshot
- `result` — optional deterministic result with generated evidence

The BFF derives `candidate_id` from the verified session and rejects mismatched
client-supplied candidate ids. `LearnerAction` remains the only scoreable
behaviour stream; technical or lifecycle events must be sent as
`AttemptAuditEvent`, and any learner action with `isTechnical: true` is
rejected.

## Voice APIs
- `POST /voice/sessions`
- `POST /voice/sessions/{id}/media-credentials`
- `POST /voice/sessions/{id}/turns`
- `POST /voice/sessions/{id}/turns/{turn_id}/upload-complete`
- `PATCH /voice/sessions/{id}/turns/{turn_id}/transcript`
- `POST /voice/sessions/{id}/complete`
- `GET /voice/sessions/{id}`
- `GET /voice/sessions/{id}/feedback`
- `POST /voice/sessions/{id}/human-review`
- `POST /voice/sessions/{id}/appeals`
- `DELETE /voice/sessions/{id}/media`

Voice media credentials are short-lived and candidate-authorised by the BFF.
They support resumable uploads to the private `voice-media` bucket. AI-provider
credentials and the Supabase service role are never returned to clients.
Transcripts must be candidate-reviewed before evaluation. Evaluation responses
include prompt version, rubric version, dimension evidence, confidence and
human-review status; they cannot perform autonomous rejection or shortlisting.

## Job APIs
- `GET /jobs`
- `GET /jobs/{id}`
- `POST /jobs/{id}/applications`
- `GET /jobs/applications` (implemented; returns the authenticated
  candidate's own applied job ids, scoped server-side by the auth token --
  originally specified as `GET /me/applications`, kept under `/jobs` to
  reuse the existing controller)
- `POST /applications/{id}/withdraw`
- `GET /me/interviews`
- `POST /interviews/{id}/response`

## Career Passport APIs
- `GET /career-passport/share/{token}` -- the public, unauthenticated
  surface behind a candidate-generated share link
  (`career_passport_grants`, `purpose = 'public_link'`). Resolves the
  token to a read-only HTML page of that candidate's evidence, or a
  clear "link unavailable" page (404) if the token is unknown, revoked,
  or past its `expires_at`. No account, session, or API key is required
  or accepted -- possessing the exact token is the only access control,
  by design. Every resolution attempt (allowed or denied, with reason)
  is recorded in `career_passport_grant_access_log`.

  Minting and revoking a link is candidate-authenticated but does not go
  through this API: the app writes directly to `career_passport_grants`
  via Supabase (RLS-scoped to `candidate_id = auth.uid()`), the same
  direct-write pattern already used for consent grants. A candidate has
  at most one active link at a time (enforced by a partial unique index),
  valid 30 days from creation.

- `GET /career-passport/applied-employers` -- candidate-authenticated
  (`CandidateAuthGuard`, same as the Job APIs). Every employer behind one
  of the candidate's non-withdrawn job applications, deduplicated
  (`{id, name}`). Exists only because `public.employers` has no
  client-facing Supabase policy, so this one join the client can't do
  directly. Whether each employer currently has an active review grant is
  *not* returned here -- the app derives that itself from
  `career_passport_grants` (RLS already scopes reads to the candidate's
  own rows). Granting/revoking a specific employer's access likewise goes
  straight to Supabase, not through this API, once the app has an
  employer id in hand.

## Employer APIs
The list below is the aspirational full employer-portal surface from the
target architecture proposal -- none of it is implemented yet. Two narrower,
already-implemented routes exist ahead of it as part of the Employer
Evidence Review MVP (see `docs/generated/current-state.md`):

- `GET /employer/applicants` -- the requesting employer's own job
  applicants (candidate id, job id/title, application status), excluding
  withdrawn applications. No evidence, not audited.
- `GET /employer/applicants/{candidateId}/evidence` -- read-only Career
  Passport evidence for one candidate, gated on candidateId having an
  active (non-withdrawn) application to one of the requesting employer's
  jobs, plus active `employer_sharing` consent AND an active,
  employer-specific `career_passport_grants` row
  (`purpose = 'employer_review'`, scoped to this exact employer --
  replaced an earlier single global `career_passport_sharing` toggle that
  granted every applied-to employer the same access at once). Every call
  is recorded in `employer_evidence_access_log`, allowed or denied. The
  response always carries the disclaimer ("Flora provides simulation
  evidence, not certification.") and the decision-boundary copy
  ("Employer reviews evidence and decides.") alongside the evidence, each
  item labelled with its provenance (`verificationStatus`) and freshness
  (`active`/`superseded`/`stale`). Evidence is returned newest-first;
  nothing is ranked, scored, or auto-shortlisted.

Both routes are guarded by `EmployerAuthGuard`: a per-employer API key
(hashed, seeded directly into `public.employers` -- no employer login flow,
no employer portal UI) sent as `Authorization: Bearer <key>`.

Covered by a real, live-database end-to-end suite --
`apps/api/test/employer-evidence-review.e2e-spec.ts`, run with
`npm run test:e2e` -- rather than only mocked unit tests: own-applicants
scoping, the full application+consent access rule, audit logging on both
allowed and denied outcomes, and cross-employer isolation. It seeds and
tears down its own fixtures and only runs when `SUPABASE_URL`/
`SUPABASE_SERVICE_ROLE_KEY` are set.

`GET /dev/employer-review` is a separate, internal-only manual QC page for
these two routes (API key input, applicant list, evidence cards, the
required disclaimer and decision-boundary copy) -- not part of this API
surface, not the employer portal, and 404s whenever `NODE_ENV=production`.

The full future surface:
- `POST /employer/requisitions`
- `GET /employer/requisitions`
- `GET /employer/requisitions/{id}/matches`
- `POST /employer/applications/{id}/shortlist`
- `POST /employer/interviews`
- `POST /employer/offers`
- `POST /employer/outcomes`
- `POST /employer/sop-programmes`
- `POST /employer/sop-programmes/{id}/versions`
- `POST /employer/sop-assignments`

## Admin APIs
- `POST /admin/simulations`
- `POST /admin/simulations/{id}/versions`
- `POST /admin/rubrics`
- `POST /admin/prompts`
- `POST /admin/content/publish`
- `GET /admin/ai-runs`
- `POST /admin/ai-evaluations/{id}/review`
- `GET /admin/appeals`
- `POST /admin/appeals/{id}/resolve`

## Integration APIs
- `POST /integrations/{provider}/connections`
- `POST /integrations/{provider}/sync`
- `POST /webhooks/{provider}`
- `GET /integrations/{provider}/health`

## Events
Canonical events include:
- `candidate.registered`
- `diagnostic.completed`
- `simulation.submitted`
- `competency.evidence.created`
- `voice.feedback.ready`
- `application.created`
- `candidate.shortlisted`
- `offer.accepted`
- `candidate.joined`
- `employment.day90_recorded`

## API Security
- Resource-level authorisation on every endpoint.
- Tenant ID derived from claims, never trusted from request body.
- Signed webhooks with replay protection.
- Rate limits by identity, tenant, IP, and endpoint risk.
- No raw AI provider credentials in clients.
