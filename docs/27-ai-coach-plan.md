# 27 — AI Career Coach: Scope, Architecture, and Backlog

Status: v1 (chat connection) shipped. This doc records the scope decisions
made when connecting the AI Coach chat screen to a real backend, the
architecture that came out of them, and the Phase 2 backlog deliberately
left out of v1. Update this file, not a chat log, when the coach's scope
changes.

## 0. What existed before this pass

`apps/candidate-mobile/lib/features/coach/` already had a fully-built chat
UI (`coach_screen.dart`) wired to `CoachController`, but every reply was a
single hardcoded string -- a 100%-local demo with no AI behind it at all.

## 1. Provider decision: Gemini primary, Claude Sonnet 5 fallback

The initial plan (Claude Sonnet 5 only) was revised once it was clear the
user would obtain a Gemini API key first: **Gemini is the active/default
provider; Claude Sonnet 5 is built and tested to the same standard but
held as a switchable fallback**, not wired to any traffic by default.

This is implemented as a `CoachAiProvider` interface
(`apps/api/src/coach/coach-ai-provider.ts`) with two implementations --
`GeminiCoachProvider` (`@google/genai`, model `gemini-2.5-flash`) and
`AnthropicCoachProvider` (`@anthropic-ai/sdk`, model `claude-sonnet-5`,
`thinking: {type: "disabled"}` for low-latency conversational replies).
`COACH_MODEL_PROVIDER` (`.env`, default `gemini`) selects which one
`coach.module.ts`'s factory constructs and injects into `CoachService`.
Switching the active provider is a one-line env change, not a deploy of
new code -- see `apps/api/.env.example`.

If neither provider's key is set, `UnconfiguredCoachProvider` steps in so
the endpoint fails cleanly (`503 COACH_UNAVAILABLE`) instead of crashing
the whole API at boot, unlike `SupabaseService`'s required vars. This
matters in practice: as of this pass, no `GEMINI_API_KEY` has been
obtained yet, so the coach endpoint is wired end-to-end but not yet live
in any real environment.

## 2. Persistence: ephemeral (confirmed decision)

The backend keeps no coach conversation state at rest. Every
`POST /v1/coach/message` call is stateless -- the mobile app resends its
full visible transcript as `history` on each turn, the server rebuilds a
provider-native message list and discards it after the reply. The only
server-side state is an in-memory per-candidate-per-day message counter
for rate limiting (`CoachService`), which resets on redeploy -- an
accepted v1 trade-off, since what it guards against is runaway API spend,
not a hard entitlement.

## 3. System prompt scope (confirmed decision)

v1 scoping is **system-prompt-level only**:

- Platform name/mission (Saksham, "Skills se rozgaar tak").
- The candidate's active sector pack -- only `warehouseLogistics` is
  wired into the shipped app (see `docs/26-sector-pack-rollout.md`), so
  that is the only one meaningfully prompted for today, though the prompt
  builder (`coach.system-prompt.ts`) already accepts `lastMileDelivery`
  for when a second pack goes live.
- An explicit skill list as hard boundaries -- see
  `coach.system-prompt.ts` for the exact allow/deny list (may explain
  lesson/simulation/exam concepts, workplace safety, interview prep,
  general career encouragement; may not give assessment answers, medical/
  legal/financial advice, job-outcome guarantees, or real-time
  safety-critical instructions; must not solicit sensitive personal data).

**Explicitly out of v1**: deep per-candidate context injection (learning
progress, exam history, Career Passport evidence). That's real
personalization and deserves its own pass once this plain connection is
proven solid -- flagged as the sharpest scope cut in this v1, open to
revisiting once the base chat quality is validated.

## 4. What "connect AI coach" actually shipped

- `apps/api/src/coach/` -- `CoachModule`, `CoachController`
  (`POST /v1/coach/message`, `CandidateAuthGuard`-protected),
  `CoachService` (validation, per-candidate-per-day rate limiting,
  provider dispatch, error mapping to the `AppError` envelope),
  `GeminiCoachProvider`, `AnthropicCoachProvider`, `UnconfiguredCoachProvider`.
- `apps/api/.env.example` -- `COACH_MODEL_PROVIDER`, `GEMINI_API_KEY`,
  `ANTHROPIC_API_KEY`, each with a self-serve-signup pointer.
- Mobile: `CoachRepository` interface, `ApiCoachRepository` (real backend,
  Dio + Supabase bearer token, same pattern as `ApiJobsRepository`),
  `LocalDemoCoachRepository` (config-gated fallback, same posture as
  `LocalMockJobsRepository` -- keeps the screen usable in a pure
  local/mock build). `coachRepositoryProvider` in `dependencies.dart`
  picks between them the same way `jobsRepositoryProvider` does.
- `CoachController` (presentation) now holds a `CoachState` (`messages`,
  `isSending`) and calls the repository asynchronously; `coach_screen.dart`
  shows a typing indicator while awaiting a reply, disables the composer
  mid-send, and its banner text is honest about whether the active
  repository is live (`isLiveData`) rather than permanently claiming
  "Local demo only".
- A failed reply (network, rate limit, provider outage) surfaces as a
  coach-authored message carrying the failure's own text, rather than a
  full-screen error state -- consistent with a chat UI where the
  conversation itself is the primary surface.

## 5. Phase 2 backlog (explicitly deferred)

Raised while scoping v1: write job-application emails, build a resume,
generate a PDF, search jobs -- all from inside the coach conversation.
Decision: ship the plain chat connection first, add these as coach
**tool-call skills** afterward, in roughly this order (cheapest/most
already-built-on first):

1. **Job search tool call** -- near-free. `apps/api/src/jobs` already has
   a full multi-source job search (Adzuna, Careerjet, Greenhouse, Jooble,
   Lever adapters) and a mobile Jobs tab. This would just be a coach tool
   call fronting the existing `JobsService`, not new search infrastructure.
2. **Job-application email drafting** -- near-free. Pure text generation
   from the same coach LLM call, using Career Passport evidence + a job
   listing as context. No new infrastructure.
3. **Resume builder** -- a real new feature. Shapes
   `CareerPassportService`'s aggregated verified evidence into a resume
   document/template. (Note: `ResumeParsingRepository` already exists on
   mobile, but it parses an *uploaded* resume into fields -- the opposite
   direction from building one.)
4. **PDF export** -- a real new backend capability (no PDF renderer
   exists anywhere in the codebase today). Would serve both the resume
   builder above and could upgrade the Career Passport share link, which
   is currently server-rendered HTML only (`career-passport-page.ts`).

None of the four are started. This section exists so the next pass at
the coach doesn't have to re-derive this reasoning from a chat transcript.

## 6. UI redesign: global chrome, topic threads, contextual entry

The shipped chat screen was never actually designed -- default
`TextField`/`Container` bubbles, described in a widget tree rather than
drawn. Two corrections shaped the rebuild, both worth keeping in mind for
any future coach UI work:

- **Coach is global chrome, not a sector widget.** A first design pass
  gave it a warehouse-specific identity (industrial signage type, a
  radio-dispatch metaphor). Wrong: `docs/adr/0020-sector-pack-abstraction.md`
  scopes sector-specific visual identity to widgets that explicitly opt
  into one trade's world, and Coach is reachable by every candidate
  regardless of active sector -- including banking, pharma, and field
  sales, none of which have Flutter screens yet (see `docs/26`'s
  cross-sector notes). It draws from the app's own shared, sector-blind
  system (`AppColors`, `AppTypography`'s system-font scale) instead.
- **First-principles pass: Coach isn't only a destination.** Every screen
  that could prompt a question already knows the context and previously
  threw it away -- a candidate stuck on a lesson had to leave, open a
  blank chat, and re-explain what the app already had on screen. The
  contextual "Ask" affordance (`ask_coach_affordance.dart`) fixes that:
  a small floating control, seeded with what the candidate is looking at,
  that answers in place via a bottom sheet without full navigation.
  "Continue in Coach" is the only path into the full destination.

What shipped:

- **`CoachMark`** (`app/theme/coach_mark.dart`) -- a custom guided-path
  glyph replacing `Icons.auto_awesome` (the generic "this is AI" sparkle
  every product uses) everywhere `AppIcons.coach` used to appear: splash,
  sign-in, onboarding welcome, the global nav shell's FAB, the dev-tools
  icon gallery, and both Coach screens below.
- **Topic threads** (design option B from the v4 design pass) replaced
  the single endless-scroll conversation: `CoachThread`
  (`domain/coach_thread.dart`), `CoachThreadRepository` /
  `SecureCoachThreadRepository` (on-device only -- local browsing
  history, not the server-side "coach data at rest" the ephemeral-history
  decision above rules out), `CoachThreadsController`
  (`AsyncNotifier<CoachThreadsState>`, one `sendingThreadIds` set so
  threads send independently), `CoachThreadsScreen` (the list + empty
  state with starter prompts) and `CoachThreadScreen` (one open
  conversation). The network contract is unchanged -- still one
  stateless `CoachRepository.sendMessage(message, history)` call per
  message; a thread's `messages` list *is* that history.
- **`AskCoachAffordance`** -- wired into `MicroLessonPlayerScreen` first
  (`floatingActionButton`), tagging new threads with a `contextRef` (e.g.
  `micro_lesson:clip_putaway_dairy_002`) for future use. **Text-first, not
  voice-first**, unlike the design reference: this app has no
  speech-to-text provider anywhere (`voice_interview_screen.dart`'s own
  "A transcription provider is not connected" state is the precedent) --
  a live waveform and partial transcript would have been fabricated UI.
  The mic control degrades the same honest way the old standalone
  composer already did ("Voice input is not active"). A live-transcription
  provider is real future scope, not evaluated here.
- Router: `/coach` now serves `CoachThreadsScreen`; `/coach/:threadId`
  (new) serves one thread. Both stay on the root navigator, matching the
  old single `/coach` route's registration.

Not done in this pass: only `MicroLessonPlayerScreen` has the contextual
affordance -- Practice, Certification, and Jobs are natural next hosts
once this one proves out. Thread deletion is also out of scope; threads
only accumulate for now.
