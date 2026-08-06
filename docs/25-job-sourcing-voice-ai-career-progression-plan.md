# Job Sourcing, Voice Interview AI, and Career Progression -- Execution Plan

Status: proposed execution plan for three independent workstreams, pending
per-phase approval before implementation. This is a planning document, not
an implementation authorisation -- each phase (H, I, J) still goes through
its own EnterPlanMode approval, build, test and PR cycle, exactly like
Phases A-G.

## 0. Why these three, and why now

The A-G roadmap (micro-lesson catalogue, WMS simulation across all 4
departments, certification exam, Role Readiness Dashboard) is fully shipped
and merged to `main` (`c1193df`). Per `docs/generated/current-state.md` and
`docs/23-ai-employability-infrastructure-platform.md`'s own explicit
self-description, everything beyond the candidate app is still
documentation/planning only -- no Career, Discovery, Employment-matching,
Placement, Partner, or Integration bounded context has any code. This plan
picks three concrete, bounded, high-value slices out of that much larger
target architecture -- it does **not** attempt to build the full DDD model
from `docs/23` in one pass, which that document itself says is not yet
authorised.

Audit findings that shaped this plan (see full detail in the two Explore
audits run 2026-08-06):

- **Jobs today**: `apps/api/src/jobs/` is a closed internal system. Candidates
  can list/apply to jobs; there is **no endpoint for an employer to create a
  job**. All jobs in the `jobs` table are seed data from a migration.
- **Employer identity today**: hashed API key per employer
  (`public.employers`), issued out-of-band, no login flow, no portal --
  employers can only *read* applicant evidence (`GET /employer/applicants`,
  `GET /employer/applicants/:candidateId/evidence`), never write.
- **Voice interview today**: real, shipped, on-device feature (mic capture,
  consent flow, transcript review) but scoring is a local keyword-heuristic
  engine -- explicitly documented as a placeholder for a real AI evaluator
  interface (`docs/17-claude-code-prompts.md:44`). No AI provider, no
  remote upload, no server-side evaluation exists.
- **Career progression today**: zero code. Distinct from Career Passport
  (`career_passport/`), which is purely an evidence ledger + Role Readiness
  summary -- it has no path, promotion, or matching logic.
- **Scraping vs Zoho decision** (confirmed with you): Zoho Recruit API,
  not scraping. Your own architecture doc explicitly prohibits screen
  scraping without official partner access
  (`docs/23-ai-employability-infrastructure-platform.md:752`).
- **What Zoho Recruit API actually is**: a standard per-employer OAuth2
  REST integration, not something gated behind a special partner program
  for what we need -- each employer explicitly connects their own Zoho
  Recruit account via a one-time OAuth consent. It only surfaces jobs from
  employers who already run Zoho Recruit and choose to connect it, so it's
  a pipe, not a volume source on its own.

## 1. Recommended build order

Independent workstreams, but sequenced by infra lift (smallest first) and
by what unblocks what:

1. **Phase H -- Job Sourcing** (direct employer posting + Zoho Recruit
   sync + Adzuna backstop). No dependency on the other two.
2. **Phase I -- Career Progression MVP**. Reuses Phase G's
   `RoleReadinessSummary`/`ReadinessCategory` directly -- smallest net-new
   surface area of the three, ships fast once H exists (career
   recommendations become much more useful once there are real job
   listings for them to point at, even though the domain logic itself has
   no hard dependency on H).
3. **Phase J -- Voice Interview AI Evaluation Backend**. Largest
   infrastructure lift (new AI provider account, remote audio/transcript
   upload and storage, new consent/retention considerations) -- best done
   last so it doesn't block the other two on external account
   provisioning.

You can reorder freely; there's no hard technical dependency between
phases. This order just minimises idle time waiting on external
account/API setup.

---

## Phase H: Job Sourcing

### Context

Today the "Jobs" tab shows only 3 seeded jobs. There is no way for a real
employer to post a job, and no external source of listings. The goal is
real job volume from three tiers, cheapest/lowest-risk first:

1. **Direct employer posting on Flora** -- zero third-party dependency,
   fully consistent with the platform's existing "employer reviews
   evidence and decides" design (`EMPLOYER_DECISION_BOUNDARY` constant in
   `employer.service.ts`). This is the real gap today: there's no `POST`
   job-creation endpoint at all.
2. **Zoho Recruit sync** -- for employers who already run Zoho Recruit,
   read their `JobOpenings` module via OAuth2 and mirror into `jobs`.
   Optional v2: write candidate applications back into their Zoho pipeline
   (`Candidates` module + job-opening association) so their recruiter sees
   Flora applicants inside the ATS they already use.
3. **Adzuna as a volume backstop** -- a genuinely open, self-serve,
   licensed job-search API (not scraping) so the Jobs tab has real listings
   from day one, while employer/Zoho adoption ramps from zero.

Indeed/LinkedIn/Naukri are explicitly excluded: none currently offer viable
non-gated self-serve APIs (Indeed closed new-publisher access years ago;
LinkedIn requires their Partner Program; Naukri has no public API). Using
any of them today would mean scraping, which is off the table per your own
decision and your architecture doc's stated policy.

### Design decisions

- **`jobs.source` column** (`'flora' | 'zoho' | 'adzuna'`, default
  `'flora'`) distinguishes provenance without changing the shape candidates
  see -- the existing `JobsService.listPublishedJobs()` and the mobile
  `Job` model need one new field, not a rework.
- **External-source jobs are read-only mirrors.** `jobs.external_id` +
  unique `(source, external_id)` constraint makes sync idempotent
  (upsert-by-external-id, same pattern as the existing
  `(job_id, candidate_id)` unique constraint on `job_applications`).
  Candidates always apply *through Flora* (existing `POST
  /jobs/:id/applications` flow, unchanged) -- Flora never redirects a
  candidate off-platform to apply, keeping the existing consent-gated
  application flow as the single path regardless of where the listing
  came from.
- **Direct employer posting is a new, narrowly-scoped `POST
  /employer/jobs` endpoint**, guarded by the existing `EmployerAuthGuard`
  (same API-key model already built for evidence review -- no new employer
  identity system needed). Employer submits title/description/
  location/role_profile_id; job is created in `status: 'draft'`, and a
  second `POST /employer/jobs/:id/publish` flips it live -- mirrors the
  existing `draft`/`published`/`closed` states already in the schema, no
  new state machine.
- **Zoho OAuth is per-employer, not platform-wide.** An employer with a
  Zoho Recruit account visits a connect link (`GET
  /employer/integrations/zoho/connect`), authorizes via Zoho's OAuth
  consent screen, we store their `access_token`/`refresh_token` encrypted
  against their `employer_id`. A scheduled sync job then pulls their
  `JobOpenings` on their behalf -- this is why it needs zero special Zoho
  partnership: it's the standard "each customer connects their own
  account" OAuth pattern, not a marketplace-wide integration.
- **Adzuna requires no employer relationship at all** -- it's a
  market-wide feed. Jobs sync in with `source: 'adzuna'`,
  `employer_id: null`. These jobs are visibly excluded from the Employer
  Evidence Review flow (an "Adzuna job" has no connected employer to grant
  evidence access), so `employer.service.ts`'s existing evidence-scoping
  logic (candidate must have applied to *that employer's* job) needs a
  guard: Adzuna-sourced applications simply never appear in any employer's
  applicant list, which is already implied by the existing employer-scoped
  query -- confirm with a test, no code change likely needed.
- **No automated matching/ranking in this phase** -- per your master plan's
  explicit non-goal ("no automated hiring decisions"), sourced jobs are
  just listed chronologically like today's seed data. Matching against
  Career Passport evidence or Career Progression (Phase I) is future work,
  not this phase.

### New/changed files

**Database** (`supabase/migrations/`):
- New migration: `jobs.source` (text, default `'flora'`, check constraint),
  `jobs.external_id` (text, nullable), unique index on
  `(source, external_id) where external_id is not null`.
- New table `employer_zoho_connections` (employer_id, encrypted
  access_token, encrypted refresh_token, zoho_org_id, connected_at,
  last_synced_at). Service-role only, same RLS posture as `employers`.
- New table `job_sync_runs` (source, started_at, completed_at, jobs_seen,
  jobs_upserted, error) -- lightweight audit trail so a bad sync is
  debuggable, mirrors the existing audit-everything posture of
  `employer_evidence_access_log`.

**Backend** (`apps/api/src/`):
- `jobs/jobs.service.ts`: extend `Job` interface with `source`; no change
  to `listPublishedJobs`/`applyToJob` logic.
- `employer/employer-jobs.controller.ts` (new): `POST /employer/jobs`,
  `POST /employer/jobs/:id/publish`, `GET /employer/jobs` (employer's own
  jobs + application counts) -- guarded by existing `EmployerAuthGuard`.
- `employer/employer-jobs.service.ts` (new): create/publish logic, reuses
  `SupabaseService` exactly like `JobsService`.
- `integrations/zoho/` (new module): `zoho-oauth.controller.ts` (connect/
  callback routes), `zoho-recruit-client.ts` (thin typed wrapper around
  Zoho's `JobOpenings` REST endpoints + token refresh), `zoho-sync.service.ts`
  (maps a Zoho job opening to a `jobs` upsert).
- `integrations/adzuna/` (new module): `adzuna-client.ts` (typed wrapper
  around Adzuna's search endpoint, India country code), `adzuna-sync.service.ts`.
- `integrations/job-sync.scheduler.ts` (new): uses `@nestjs/schedule`
  (new dependency -- not currently installed) to run Zoho sync (per
  connected employer) and Adzuna sync (platform-wide, rate-limited) on a
  cron interval; writes a `job_sync_runs` row per execution.
- `.env.example`: add `ZOHO_CLIENT_ID`, `ZOHO_CLIENT_SECRET`,
  `ZOHO_REDIRECT_URI`, `ADZUNA_APP_ID`, `ADZUNA_APP_KEY`,
  `JOB_TOKEN_ENCRYPTION_KEY` placeholders.

**Mobile** (`apps/candidate-mobile/lib/features/jobs/`):
- `domain/job.dart`: add `source` field (display-only -- e.g. a small
  "via Zoho" / "via Apex Consumer Products" caption on the job card,
  matching the existing evidence-provenance transparency pattern used
  elsewhere in the app).
- No change to the apply flow.

### Tests

- `jobs.service.spec.ts`: `source` field round-trips correctly.
- `zoho-sync.service.spec.ts`: maps a fixture Zoho `JobOpenings` payload to
  a correct upsert; re-running with the same fixture is a no-op (idempotency).
- `adzuna-sync.service.spec.ts`: same idempotency shape.
- `employer-jobs.controller.spec.ts`: create -> draft -> publish flow;
  an employer cannot publish another employer's job (authorization check).
- Migration test: unique `(source, external_id)` constraint holds.
- Mobile: `job_card_test.dart` shows the source caption correctly.

### Explicitly out of scope for Phase H

- No write-back of applications into Zoho Recruit's `Candidates` module
  (v2, only after read-only sync is proven).
- No employer self-serve web portal UI -- `POST /employer/jobs` is an API
  surface only; a minimal harness page (same pattern as the existing
  employer evidence-review dev harness) is a nice-to-have, not required
  for the phase to be useful.
- No automated candidate-to-job matching or ranking.
- No sources beyond Zoho Recruit and Adzuna (no Indeed/LinkedIn/Naukri --
  not viable without scraping or a partner deal).
- No National Career Service (NCS) integration in v1 -- flagged as a
  strong future candidate (government-sanctioned, mission-aligned) but its
  current API status needs verification before committing engineering
  time; not blocking this phase.

---

## Phase I: Career Progression MVP

### Context

"Career progression" is completely unbuilt today -- distinct from Career
Passport, which only stores evidence. The full target design in `docs/23`
(`Industry`/`Occupation`/`Role`/`CareerPath`/`RoleCompetencyRequirement`
aggregates) is explicitly not yet authorised and is a much larger lift than
is justified right now. Instead of building that from scratch, this phase
reuses Phase G's `ReadinessCategory` (Receiving/Processing/Dispatch/
Supervisor) as the career-ladder's node set -- the same low-risk,
pure-derivation pattern that made Phase G a one-day build.

### Design decisions

- **Static, hand-authored career-ladder content**
  (`assets/career_progression/warehouse_career_ladder.json`), same pattern
  as `competencies.json` -- an ordered list of roles per
  `ReadinessCategory`, each with a `minReadinessLevel` (reusing
  `ReadinessLevel` from Phase G) and a short description of what the next
  role actually does day-to-day.
- **`deriveCareerRecommendations(readiness: List<RoleReadinessSummary>)`**
  -- another pure function, same shape as `deriveRoleReadiness` itself: for
  each category, find the highest-tier role the candidate's current
  readiness level qualifies for, plus the *next* role and what's blocking
  it (which competencies need more evidence). No new evidence source, no
  new network call -- it's a second derivation layered on data Phase G
  already computes.
- **New `CareerProgressionSection` widget**, placed on the Profile tab
  near `RoleReadinessSection` (or the Home dashboard's existing "Your
  career pathway" copy, which today is static UI text with no real logic
  behind it -- confirmed by the audit -- this phase gives it a real
  backing model for the first time).
- **If Phase H has shipped**, the "next role" card can optionally link to
  matching open jobs (simple category-string match, e.g. a Processing
  career-ladder entry links to jobs whose `role_profile_id` maps to
  Processing) -- this is a nice-to-have cross-link, not a hard dependency;
  Phase I ships fully useful without it.

### New/changed files

- `assets/career_progression/warehouse_career_ladder.json` (new content).
- `lib/features/career_progression/domain/career_progression.dart` (new):
  `CareerLadderRole`, `CareerRecommendation`,
  `deriveCareerRecommendations()`.
- `lib/features/career_progression/presentation/career_progression_section.dart`
  (new): `ConsumerWidget`, reads `careerPassportControllerProvider`
  (same provider Phase G's `RoleReadinessSection` already reads) plus the
  static ladder asset.
- `lib/features/profile/presentation/profile_screen.dart`: embed the new
  section.
- Optional: `home_dashboard_screen.dart`'s existing static "Your career
  pathway" copy gets replaced with real data from this section.

### Tests

- `career_progression_test.dart` (domain): recommendation logic per
  readiness level, "next role" blocking-competency logic, an Unknown-level
  category recommends the entry-level role.
- `career_progression_section_test.dart` (widget): mirrors
  `role_readiness_section_test.dart`'s harness.

### Explicitly out of scope for Phase I

- No full `Industry`/`Occupation`/`Role` taxonomy from `docs/23` -- single
  hand-authored warehouse/logistics ladder only, matching the domain this
  platform already covers end-to-end.
- No automated promotion decisions or employer-visible "readiness for
  promotion" signal -- candidate-facing only, same evidence-not-certification
  posture as Phase G.
- No cross-sector career paths (e.g. warehouse -> retail) -- non-goal per
  `docs/00-master-plan.md`'s "more than one sector" exclusion.

---

## Phase J: Voice Interview AI Evaluation Backend

### Context

The voice interview feature is real and shipped on-device (mic capture,
consent, transcript review), but scoring is a local keyword-heuristic
engine (`voice_evaluation_engine.dart` looks for words like "recount",
"escalate", "sla") -- explicitly documented as a placeholder for a real AI
evaluator. This phase swaps that placeholder for a real model call,
server-side (never call an AI provider directly from the mobile client --
that would expose API keys and bypass consent/audit logging).

### Design decisions

- **Server-side evaluation, not on-device.** New `POST
  /voice-interviews/:id/evaluate` endpoint in `apps/api`: candidate app
  uploads the reviewed transcript (text only in v1 -- no audio upload,
  keeping scope and storage/privacy surface small); backend calls an AI
  provider with a structured prompt, gets back structured scores.
- **Structured, not freeform, model output** -- matching your master
  plan's stated design (`docs/00-master-plan.md` §5): separate scores for
  content, clarity, structure, and job knowledge, each with a short
  explanation -- not a single opaque number. This keeps the feature
  "explainable," consistent with the whole evidence-not-certification
  posture of the rest of the platform.
- **Evaluation results become Career Passport evidence**, same pattern as
  the certification exam: a new `EvidenceType.voiceInterview`, one
  `EvidenceRecord` per competency the interview question targeted, scored
  from the structured evaluation. This is the biggest design win of this
  phase -- it means voice interviews stop being an isolated feature and
  start feeding the same evidence ledger everything else does.
- **English only in v1.** Vernacular/multi-language voice AI is explicitly
  a later-phase item in `docs/00-master-plan.md` -- out of scope here.
- **Retry/failure handling**: if the AI call fails, the existing "request
  human review" flag (already in the domain model) becomes the fallback --
  no new failure UX needed, reuse what's there.

### New/changed files

**Backend** (`apps/api/src/`):
- `voice-interviews/` (new module): `voice-interviews.controller.ts`
  (`POST /voice-interviews/:id/evaluate`), `voice-interviews.service.ts`
  (calls the AI provider, parses structured output, persists result).
- `voice-interviews/voice-evaluation-evidence.service.ts`: maps an
  evaluation result to `EvidenceRecord`s, mirrors
  `CertificationExamEvidenceGenerationService`'s exact shape.
- New Supabase table `voice_interview_evaluations` (attempt_id,
  candidate_id, per-dimension scores, explanations, model_version,
  evaluated_at) -- `model_version` recorded explicitly so future
  re-evaluation/audit is possible.
- `.env.example`: add the AI provider API key placeholder.

**Mobile** (`apps/candidate-mobile/lib/features/voice/`):
- `data/`: new repository method to upload the transcript and fetch the
  evaluation result (replaces the local call to
  `voice_evaluation_engine.dart`, or keeps it as an instant local preview
  with the server result arriving shortly after -- worth a quick UX call
  during planning, not a blocker).
- `presentation/`: result screen shows the 4 structured scores +
  explanations instead of the current heuristic summary.

### Tests

- `voice-interviews.service.spec.ts`: mocked AI provider response ->
  correct structured parse; malformed/unexpected model output -> graceful
  fallback to human-review flag, not a crash.
- `voice-evaluation-evidence.service.spec.ts`: mirrors
  `certification_exam_evidence_generation_service_test.dart`'s shape.
- Mobile: transcript upload + result display widget test.
- Extend `wms_career_passport_repository_test.dart` with a voice-interview
  evidence case, same as the certification-exam precedent.

### Explicitly out of scope for Phase J

- No audio upload/storage in v1 -- text transcript only.
- No vernacular/multi-language support.
- No live/real-time evaluation during recording.
- No change to the existing on-device consent, permission, or deletion
  flows -- those stay exactly as shipped.

---

## Cross-phase notes

- Every phase follows the same discipline the A-G roadmap already proved
  out: branch from latest `origin/main`, `EnterPlanMode`-approved plan
  before code, full `flutter analyze`/`flutter test`/`flutter build apk
  --debug` (mobile) and `npm test` (API) before shipping, PR ->
  `build-apk.yml` CI -> merge.
- None of these three phases touch the WMS simulation engine, the
  certification exam, or Career Passport's core derivation logic --
  Phase I only *adds* a new derivation alongside `deriveRoleReadiness`,
  and Phase J only *adds* a new `EvidenceType`, matching how Phase G
  and the certification exam were each added without modifying what came
  before them.
- Phase H and Phase J both need new secrets (Zoho OAuth client, Adzuna
  API key, AI provider key) -- these should be provisioned in whichever
  secret store `apps/api` already uses for `SUPABASE_SERVICE_ROLE_KEY`,
  not committed to `.env.example` beyond placeholder names.
