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

## Employer APIs
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
