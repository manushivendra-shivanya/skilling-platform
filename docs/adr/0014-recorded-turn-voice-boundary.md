# ADR-0014: Recorded-Turn Voice and Consequential AI Boundary

- Status: Accepted
- Date: 2026-07-28
- Owners: Engineering

## Context

Phase 3 introduces microphone access, candidate voice media, transcription,
evaluation, feedback, and human review. These records are sensitive and an
evaluation may affect employment decisions. The approved architecture places
AI-provider, media-authorisation, employer, administrator, and
cross-candidate operations behind the planned NestJS backend-for-frontend
(BFF). The candidate still needs a testable low-connectivity voice foundation
before the production BFF and AI providers are configured.

## Decision

The first Phase 3 slice uses turn-based recording in Flutter. The application
requests microphone permission only after purpose-separated consent, records
one answer at a time, preserves interrupted state without penalty, lets the
candidate review or correct every transcript, and exposes deletion.

Until a transcription provider is connected, the candidate supplies or
corrects transcript text explicitly. A deterministic development evaluator
operates only on reviewed transcript content. It produces dimension-level
guidance with prompt and rubric versions and always marks the result for human
review. It cannot reject or shortlist a candidate.

JobSkills stores the server-side voice schema, a private media bucket, prompt
and rubric versions, review state, and audit boundaries. Candidate-owned
practice metadata may use RLS-protected Data API access. Raw media credentials,
transcription, AI runs, application interviews, employer visibility, and
reviewer actions remain BFF-only. Flutter never contains a service-role key or
AI-provider credential.

## Alternatives Considered

- Stream audio directly from Flutter to an AI provider. Rejected because it
  exposes provider and consequential-processing boundaries to the client.
- Score audio characteristics locally. Rejected because accent, emotion,
  personality, and protected-trait inference are outside the approved rubric.
- Wait for real-time voice infrastructure. Rejected because recorded turns
  provide an accessible, resumable low-bandwidth foundation.

## Consequences

- Candidates can test microphone and consent UX now, including offline and
  technical-failure states.
- The upload interface is resumable by contract, but production signed upload
  credentials remain a Phase 3 BFF deliverable.
- Development feedback is useful for practice but is not authoritative
  employment evidence.
- Prompt, rubric, transcript, evaluation, review, and deletion state are
  versioned and auditable before provider integration.

## Security/Privacy Impact

- Audio is treated as sensitive candidate data and uses a private bucket with a
  15 MB object limit.
- No authenticated `storage.objects` policy is exposed; the BFF will issue
  short-lived, candidate-authorised upload/download credentials.
- AI-run and audit tables are explicitly inaccessible to authenticated mobile
  clients.
- Technical failures are recorded separately and excluded from evaluation.
- Employer sharing is a separate optional consent and defaults to false.

## Migration/Rollback

The feature can be removed from navigation without changing Phase 1 or Phase 2
records. Database changes are additive and versioned under
`supabase/migrations`. Revoking voice consent and deleting local audio remain
available independently of provider connectivity.

## References

- `docs/01-system-architecture.md`
- `docs/03-api-specifications.md`
- `docs/05-ai-architecture.md`
- `docs/06-voice-architecture.md`
- `docs/13-security-privacy-compliance.md`
- `docs/20-codex-phase-execution.md`
