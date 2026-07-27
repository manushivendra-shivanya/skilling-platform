# Codex Phase Execution Plan

## Execution rules

Codex must:
1. Read AGENTS.md and the master context.
2. Inspect current code.
3. Work in small vertical slices.
4. Preserve the Android build.
5. Add tests.
6. Update generated documentation.
7. Commit only coherent, reviewable changes.

---

# Phase 1 — Production Mobile Foundation

## Objective

Replace the default Flutter counter application with a production-ready candidate app shell while keeping the build pipeline working.

## Phase 1.1 — Application architecture

Tasks:
- Remove Flutter counter demo
- Create feature-first folder structure
- Configure Riverpod
- Configure GoRouter
- Add application environment abstraction
- Add logging abstraction
- Add analytics abstraction
- Add error boundary
- Add shared result/failure models
- Add repository interfaces
- Add mock adapters
- Add test helpers

Suggested structure:

lib/
 app/
   ├── app.dart
   ├── bootstrap.dart
   ├── router/
   └── theme/
 core/
   ├── analytics/
   ├── config/
   ├── errors/
   ├── network/
   ├── storage/
   ├── widgets/
   └── utils/
 features/
   ├── splash/
   ├── onboarding/
   ├── authentication/
   ├── home/
   ├── coach/
   ├── learning/
   ├── practice/
   ├── jobs/
   └── profile/
 main.dart

Acceptance:
- App opens without the counter demo
- No runtime crash
- Router tests pass
- APK builds

## Phase 1.2 — Design system

Build:
- Colour tokens
- Typography
- Spacing
- Radius
- Elevation
- Icon strategy
- Buttons
- Text fields
- Cards
- Chips
- Progress
- Skeleton loaders
- Empty state
- Error state
- Offline banner
- Pending-sync banner
- Bottom sheet
- Dialog
- Snackbar

Acceptance:
- Components appear in a development gallery
- Components support accessibility
- Components support Hindi text expansion
- Widget tests cover core states

## Phase 1.3 — Splash and welcome

Screens:
- Splash
- Welcome
- Language selection
- Sign-in choice

Requirements:
- English
- Hindi
- Hinglish readiness
- Continue with phone
- Google sign-in shown as planned or disabled until configured
- Privacy and terms links
- Low-bandwidth-friendly assets

Acceptance:
- Navigation persists selected language
- Back behaviour works
- No dead buttons without explanation

## Phase 1.4 — Development authentication

Build:
- OTP interface
- Development mock OTP adapter
- Phone entry
- OTP entry
- Resend state
- Error and timeout states
- Session repository
- Secure session storage abstraction

Do not add production SMS credentials.

Acceptance:
- Candidate can complete development login
- Session survives app restart
- Logout clears session
- Tests cover success and failure

## Phase 1.5 — Candidate onboarding

Screens:
- Goal selection
- Personal information
- Location
- Education
- Experience
- Preferred roles
- Resume upload placeholder
- Voice introduction placeholder
- Consent centre
- Profile review
- Completion success

Acceptance:
- Draft is preserved locally
- Candidate can resume onboarding
- Consent versions are stored
- Required fields are validated
- Offline state is visible

## Phase 1.6 — Main navigation

Bottom tabs:
- Home
- Learn
- Practise
- Jobs
- Me

Global:
- AI Coach entry
- Notifications placeholder
- Deep-link-ready routes

Acceptance:
- Tab state is preserved
- Android back navigation works
- Router tests pass

## Phase 1.7 — Home dashboard

Build with mock repositories:
- Greeting
- Readiness progress
- Daily mission
- Recommended next step
- Learning progress
- Practice recommendation
- Job match summary
- Application status
- AI Coach card
- Pending sync

Acceptance:
- Loading, empty, error and populated states
- Pull to refresh
- Accessibility labels
- Analytics events

## Phase 1.8 — AI Coach shell

Build:
- Conversation list
- Text composer
- Microphone control
- Audio upload placeholder
- Image/document upload placeholder
- Suggested prompts
- Consent notice
- Error and retry
- Local mock responses

Do not claim production AI is connected.

Acceptance:
- Text conversation works with mock adapter
- Recording button has a permission-safe placeholder
- Attachment routes are clear
- Conversation can be reset

## Phase 1.9 — Learning shell

Build:
- Pathway overview
- Daily mission
- Lesson cards
- Progress
- Download indicator
- Lesson detail placeholder
- Completion state

Acceptance:
- Mock content renders
- Offline/download states are represented
- Progress is not falsely authoritative

## Phase 1.10 — Practice shell

Build:
- Simulation catalogue
- Recommended simulation
- Attempt history
- Simulation introduction
- Inventory discrepancy placeholder flow
- Voice practice entry

Acceptance:
- Clear distinction between demo and scored assessment
- Technical failure messaging included

## Phase 1.11 — Jobs shell

Build:
- Job feed
- Search
- Filters
- Job details
- Match explanation
- Apply confirmation
- Application tracker
- Interview placeholder

Acceptance:
- Employer sharing consent appears before application
- Mock application persists locally
- Empty and error states included

## Phase 1.12 — Profile shell

Build:
- Candidate details
- Career goals
- Skills
- Experience
- Education
- Evidence placeholder
- Consent and privacy
- Language
- Notifications
- Support
- Logout
- Delete account request placeholder

Acceptance:
- Editable fields persist through repository abstraction
- Privacy controls are visible

## Phase 1 exit criteria

- Default Flutter demo completely removed
- Production app shell available
- All five tabs functional
- Mock onboarding works end-to-end
- Mock authentication works
- Home, Coach, Learning, Practice, Jobs and Profile shells work
- Flutter analyse passes
- Tests pass
- Debug APK builds in GitHub Actions
- APK manually installs and launches
- current-state and block-diagram updated

---

# Phase 2 — Core Candidate Intelligence

## Scope
- Supabase project configuration
- Environment separation
- Production-ready authentication abstraction
- Candidate profile persistence
- Consent persistence
- Role taxonomy
- Competency model
- Diagnostic runtime
- Explainable diagnostic results
- Recommended pathway
- Learning content model
- Progress sync
- Offline content basics
- Simulation engine v1
- Event batching
- Deterministic scoring
- Evidence generation
- Resume parsing adapter
- Analytics events

## Exit criteria
Candidate can authenticate, create a persistent profile, complete a logistics diagnostic, receive an explainable pathway, complete learning content and perform at least one scored simulation.

---

# Phase 3 — Voice, Jobs and Employer Operations

## Scope
- Audio permissions
- Microphone test
- Recorded-turn interview
- Resumeable media upload
- Transcription adapter
- Transcript review
- AI prompt registry
- Structured evaluator output
- Human review queue
- Candidate feedback
- Job matching
- Job application APIs
- Application tracking
- Employer portal v1
- Admin portal v1
- Audit records
- Operational dashboards

## Exit criteria
Candidate completes a voice interview, receives structured explainable feedback, applies to a job with consent, and an employer can review evidence and shortlist through tenant-isolated workflows.

---

# Codex start command

Implement Phase 1 only.

Start with architecture, design system, routing and production mobile shell. Do not implement production OTP, Supabase, AI provider calls, voice evaluation or employer features yet.

Before editing:
- Read AGENTS.md
- Read README.md
- Read docs/19-codex-master-context.md
- Read docs/20-codex-phase-execution.md
- Read docs/09-candidate-mobile-app.md
- Inspect apps/candidate-mobile
- Inspect .github/workflows/build-apk.yml

Then:
1. Summarise current state
2. Propose the exact Phase 1 slice
3. Implement
4. Test
5. Build
6. Update documentation
7. Report changed files and verification
