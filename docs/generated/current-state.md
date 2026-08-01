# Current Repository State

Last updated: 2026-08-01

## Status

### Built and manually verified
- Flutter candidate application scaffold
- Android debug APK GitHub Actions workflow
- Android APK installation on Samsung S24 Ultra
- Application launch without crash
- Phase 1.3 Saksham entry flow installation and launch confirmed during device
  QC
- Phase 1.6 arm64 QC APK installed and launched through Wireless ADB on Samsung
  S24 Ultra; visual navigation QC is pending candidate confirmation
- Cumulative Phase 1.1-1.12 arm64 QC APK installed as an in-place update and
  launched through Wireless ADB on Samsung S24 Ultra
- Phase 2 core candidate intelligence implementation and JobSkills database
  migrations; GitHub build and ARM64 APK distribution passed
- Phase 3.1 recorded-turn voice foundation and JobSkills voice schema; GitHub
  build, ARM64 APK publication, clean installation and launch passed
- WMS remote persistence foundation applied to the live JobSkills Supabase
  project
- WMS BFF sync boundary implemented for candidate-owned attempt lifecycle,
  scoreable learner actions, unscored audit events, results and generated
  evidence
- Flutter WMS now uses an offline-first sync adapter when both Supabase and
  `API_BASE_URL` are configured: local encrypted writes remain authoritative,
  while BFF sync failures create a persistent pending-sync snapshot for retry

### Current UI
- Phase 1.1 application foundation replaces the default Flutter counter demo
- Router-backed startup screen with loading, recoverable error, retry, and
  low-data-mode representations
- Phase 1.2 Material 3 design system with shared tokens and production widgets
- Phase 1.3 branded splash, welcome, English/Hindi/Hinglish selection, and
  sign-in choice flow
- Development-only component gallery accessible from the welcome screen in
  development and staging configurations
- Phone OTP is clearly marked for Phase 1.4; Google sign-in is visibly planned
  and disabled until configured
- Phase 1.4 development phone entry, mock OTP verification, resend/expiry
  states, secure session restoration, and logout
- Phase 1.5 resumable candidate onboarding with encrypted local drafts,
  required-field validation, versioned consent, review, and completion
- Phase 1.6 protected, persistent five-tab navigation with global AI Coach and
  notification placeholder routes
- Phase 1.7 mock-backed Home dashboard with refresh and explicit readiness,
  progress, daily-mission, and pending-sync states
- Phase 1.8 local scripted Coach with text conversation, reset, and honest
  microphone and attachment boundaries
- Phase 1.9 local Learning catalogue with offline, download, and completion
  states
- Phase 1.10 interactive unscored Practice demonstrations with transparent
  feedback and failure messaging
- Phase 1.11 searchable mock Jobs catalogue with consent-gated, encrypted local
  application records
- Phase 1.12 Profile summary, editable local details, privacy controls, help,
  deletion-request boundary, and working logout
- Environment-gated Supabase phone authentication and candidate-owned profile,
  consent, diagnostic, learning, simulation, score, and evidence sync
- Secure local development and offline fallback remains available when
  Supabase configuration is absent
- Resume parsing remains a provider-neutral adapter contract
- Voice interview practice now provides permission education, real microphone
  capture, reviewed transcripts, explainable development feedback, human-review
  request, local deletion, and explicit offline/pending-upload states
- A UI-neutral Workplace Management Simulation v0.2 backbone provides
  versioned local content, deterministic scenarios, mission state, action
  validation, scoring, critical errors, remediation and evidence
- Approved WMS Screens 01–06 are available from Practice, with controller-owned
  progression through entry, briefing, overview, document review, receiving
  count and physical inspection (carton inspection + barcode scanning against
  the already-authored `physical-inspection` stage content)

### Android configuration
- compileSdk 36
- targetSdk 36
- Java 17
- Gradle 9.1.0
- Android Gradle Plugin 9.0.1
- Kotlin 2.3.20
- Unused jni dependency removed

### Active branch
main

### Latest verified milestone
The Receiving and Put Away WMS missions are complete end to end locally, and
the live JobSkills database now has candidate-owned WMS persistence tables for
attempt lifecycle, scoreable learner actions, unscored audit events, results
and generated evidence. The NestJS BFF now exposes an idempotent WMS sync
endpoint for those tables. The Flutter app now wraps the local WMS repository
with a best-effort BFF sync adapter when remote configuration is present.

### Phase 1.1 validation record
- `flutter pub get` — passed
- `dart format .` — passed; 25 files checked with no outstanding changes
- `flutter analyze` — passed with no issues
- `flutter test --reporter expanded` — passed; 4 tests
- `flutter build apk --debug` — attempted locally, but Gradle 9.1.0 exits
  before project settings evaluation with `The settings are not yet available
  for build`. This occurred before Dart or Android source compilation and also
  reproduced with Java 17 and the direct Gradle task. GitHub Actions remains
  the authoritative APK validator for this repository.
- GitHub Actions **Build Candidate Mobile APK** — passed for `e879e7d`:
  dependency resolution, static analysis, debug APK build, and artifact upload
  all completed successfully.

### Phase 1.2 implementation
- Brand, semantic colour, typography, spacing, radius, elevation, and icon
  tokens
- Accessible primary, secondary, text, destructive, loading, and disabled
  button states
- Shared text field, card, status chip, progress, and static skeleton widgets
- Empty, error, offline, pending-sync, bottom-sheet, dialog, and snackbar
  patterns
- Development-only component gallery covering every Phase 1.2 component
- Production configuration omits the component gallery route and entry point

### Phase 1.2 local validation record
- `flutter pub get` — passed
- `dart format .` — passed; 46 Dart files checked
- `flutter analyze` — passed with no issues
- `flutter test --reporter expanded` — passed; 13 tests
- Hindi text expansion — widget test passed at 320 logical pixels and 1.6x
  text scaling
- `flutter build apk --debug` — attempted locally and reached the unchanged
  Gradle build, which exited before project settings evaluation with the same
  documented Gradle 9.1.0 host error. GitHub Actions is the authoritative APK
  validator.
- GitHub Actions **Build Candidate Mobile APK** — passed for `78a96e7`:
  dependency resolution, static analysis, debug APK build, and
  `candidate-mobile-debug-apk` artifact upload all completed successfully.

### APK distribution correction
- A tester screenshot showed Flutter's original counter template, which is
  absent from the local and remote Phase 1.2 source. Repeated downloads used
  the generic `app-debug.apk` filename, making a stale APK easy to install.
- The current GitHub credentials cannot update Actions workflow files, so the
  artifact still contains the generic filename. Testers must uninstall the old
  app and remove previously downloaded or extracted `app-debug.apk` files
  before installing the APK from the verified Phase 1.2 workflow run.

### Phase 1.3 implementation
- Low-bandwidth branded splash with startup loading, recoverable error, retry,
  and automatic welcome navigation
- Responsive welcome screen with an accessible primary language action
- English, Hindi, and Hinglish language choices with repository-backed
  selection preserved across forward and back navigation
- Local analytics event for language selection with no candidate PII
- Localised sign-in-choice copy for all three language modes
- Phone sign-in action explains the Phase 1.4 boundary; Google sign-in is
  disabled with an explicit availability message
- Working privacy and terms summary sheets
- Loading and recoverable storage error states

### Phase 1.3 local validation record
- `flutter pub get` — passed
- `dart format .` — passed; 55 Dart files checked
- `flutter analyze --no-pub` — passed with no issues
- `flutter test --no-pub --reporter expanded` — passed; 19 tests
- Hindi text expansion — onboarding flow passed at 320 logical pixels and 1.4x
  text scaling
- `flutter build apk --debug` — attempted locally and reached the unchanged
  Gradle build, which exited before project settings evaluation with the
  documented Gradle 9.1.0 host error. GitHub Actions remains authoritative.
- GitHub Actions **Build Candidate Mobile APK** — passed for `db4ec52`:
  dependency resolution, static analysis, debug APK build with secure-storage
  plugin registration, and artifact upload all completed successfully.
- GitHub Actions **Build Candidate Mobile APK** — passed for `cad63f9`:
  dependency resolution, static analysis, debug APK build, and
  `candidate-mobile-debug-apk` artifact upload all completed successfully.

### Phase 1.4 implementation
- Provider-neutral development authentication contract with a local mock
  adapter; no production SMS provider or credentials
- Indian mobile-number validation and explicit offline development notice
- Six-digit OTP UI with the documented development code `123456`
- Incorrect-code, expired-code, resend countdown, loading, and retry states
- Candidate sessions serialized without phone numbers and persisted through a
  secure key-value abstraction backed by `flutter_secure_storage`
- Startup restores an authenticated session and skips the sign-in flow
- Logout clears secure session state and returns to welcome
- Authentication analytics record request/completion events without phone
  numbers or other PII
- Standard Flutter CocoaPods wiring retained for secure storage on iOS/macOS;
  stale generated `jni` plugin references removed from Linux/Windows

### Phase 1.4 local validation record
- `flutter pub get` — passed
- `dart format .` — passed; 66 Dart files checked
- `flutter analyze --no-pub` — passed with no issues
- `flutter test --no-pub --reporter expanded` — passed; 27 tests
- `flutter build apk --debug` — attempted locally and reached the unchanged
  Gradle build, which exited before project settings evaluation with the
  documented Gradle 9.1.0 host error. GitHub Actions remains authoritative.

### Phase 1.5 implementation
- Ten-step candidate profile setup followed by a completion-success screen:
  goal, personal information, location, education, experience, preferred
  logistics roles, resume placeholder, voice-introduction placeholder,
  consent centre, and profile review
- Feature-first candidate onboarding domain model and repository contract
- Candidate-isolated drafts serialized to the existing encrypted secure
  key-value adapter; step position and entered data survive app reconstruction
- Explicit validation for name, city/state, six-digit PIN code, education,
  experience, preferred role, goal, and both required consent notices
- Platform terms and privacy notice stored independently with immutable
  purpose, version, and UTC acceptance timestamp
- Offline banner explains that each completed step remains securely on device;
  the normal state also states that saving occurs after every step
- Resume and voice steps are honest placeholders: no file access, microphone
  permission, recording, or upload occurs
- Non-PII analytics for onboarding start, saved step number, and completion
- Loading, recoverable storage error, validation error, review, and completion
  states

### Phase 1.5 local validation record
- `flutter pub get` — passed
- `dart format .` — passed; 73 Dart files checked
- `flutter analyze --no-pub` — passed with no issues
- `flutter test --no-pub --reporter expanded` — passed; 34 tests
- Draft round-trip, candidate isolation, required validation, resume position,
  offline visibility, versioned consent, end-to-end completion, and narrow
  320-pixel/1.4x text-scale coverage passed
- `flutter build apk --debug --no-pub` — attempted locally and reached the
  unchanged Gradle build, which exited before project settings evaluation with
  the documented `The settings are not yet available for build` host error.
  GitHub Actions remains authoritative.

### Phase 1.5 authoritative build and distribution
- GitHub Actions **Build Candidate Mobile APK** run `30290605615` — passed for
  source commit `e24b960`: dependency resolution, static analysis, universal
  debug APK build, and artifact upload completed successfully
- The Actions universal debug APK is 148 MB because it includes Flutter debug
  runtime binaries for arm64, armv7, and x86_64
- A Samsung/arm64 QC APK was derived from that verified universal binary by
  removing only the armv7 and x86_64 native-library directories, then
  zip-aligning and re-signing with the project Mac debug certificate
- The 80 MB arm64 APK contains only `arm64-v8a`, passes Android APK Signature
  Scheme v2/v3 verification, and is published in GitHub prerelease
  `phase-1.5-qc`
- Arm64 QC APK SHA-256:
  `12bc584c84c8d82403473972f97292e64a15f39ab41482e2d02e7f4953c51bc9`

### Phase 1.6 implementation
- GoRouter `StatefulShellRoute.indexedStack` with persistent Home, Learn,
  Practise, Jobs, and Me branches
- Completed candidates enter Home automatically after startup; onboarding
  completion now has a working **Go to home** action
- Candidate-session and onboarding-completion route policy protects the five
  tab roots, AI Coach, notifications, and onboarding from invalid direct entry
- Named root paths (`/home`, `/learn`, `/practise`, `/jobs`, `/me`) establish
  deep-link-ready destinations
- Global `/coach` and `/notifications` routes open above the selected tab and
  clearly state their placeholder boundaries
- Android Back returns global routes to the selected tab and returns a
  non-Home root tab to Home
- Selecting the active tab resets that branch to its root; switching branches
  preserves each branch widget/navigation state
- Accessible Material 3 navigation labels, notification tooltip, and global
  AI Coach action
- Non-PII analytics record selected tab names and opened global actions
- Honest per-destination Phase 1.7–1.12 previews; no future dashboard, AI,
  learning, practice, job, or profile capability is presented as connected

### Phase 1.6 local validation record
- `flutter pub get` — passed
- `dart format .` — passed; 77 Dart files checked
- `flutter analyze --no-pub` — passed with no issues
- `flutter test --no-pub --reporter expanded` — passed; 40 tests
- Five destinations, retained tab UI state, onboarding-to-Home, protected
  signed-out deep links, completed-candidate direct links, global-route Back,
  non-Home Back-to-Home, analytics, and narrow 320-pixel/1.4x text-scale
  coverage passed
- `flutter build apk --debug --no-pub` — attempted locally and reached the
  unchanged Gradle build, which exited before project settings evaluation with
  the documented `The settings are not yet available for build` host error.
  GitHub Actions remains authoritative.

### Phase 1.6 authoritative build and distribution
- GitHub Actions **Build Candidate Mobile APK** run `30292966735` — passed for
  source commit `ecff5ad`: dependency resolution, static analysis, universal
  debug APK build, and artifact upload completed successfully
- The Actions universal debug APK remains 148 MB because it contains Flutter
  debug runtime binaries for arm64, armv7, and x86_64
- The successful Actions artifact was downloaded with verified parallel byte
  ranges after the single GitHub connection slowed to approximately 40 KB/s;
  the reconstructed ZIP passed archive integrity validation
- A Samsung/arm64 QC APK was derived by removing only armv7 and x86_64 native
  libraries, then zip-aligning and re-signing with the same project Mac debug
  certificate used for the Phase 1.5 arm64 APK
- The 80.5 MB APK contains only `arm64-v8a`, passes Android APK Signature
  Scheme v2/v3 verification, and is published in GitHub prerelease
  `phase-1.6-qc`
- Arm64 QC APK SHA-256:
  `5ec2638cfd80b80bd7ac395c369438e29889410699058a4bd2a647cdf9d6afbe`
- Wireless ADB identified the test device as Samsung `SM-S928B`
- In-place installation was rejected because the phone contained an older
  debug certificate. After explicit tester approval, only
  `com.example.candidate_mobile` was removed; this cleared that test app's
  local session and onboarding draft.
- Clean arm64 installation completed successfully in 4.9 seconds, Android
  launched the package, and process `com.example.candidate_mobile` remained
  active. Screen-content capture was not performed; visual device QC remains
  pending.

### Phase 1.7-1.12 implementation
- Home loads through a feature-first repository and controller, supports
  loading, recoverable error, empty, refresh, populated, offline, and
  pending-sync representations, and labels practice readiness as local mock
  guidance rather than an employer score
- Coach keeps a local scripted conversation, records only non-PII analytics,
  supports reset confirmation, and clearly avoids microphone, file access,
  uploads, and a production AI provider
- Learning uses fixed mock units with local download and completion state,
  offline messaging, empty and error recovery, and non-authoritative progress
- Practice offers an interactive recommendation discrepancy exercise and
  catalogue while explicitly keeping demonstrations unscored and separating
  technical failure from candidate reliability
- Jobs uses a searchable mock catalogue, transparent demo match explanations,
  details sheets, explicit application consent, and candidate-isolated applied
  identifiers in the encrypted secure-storage abstraction
- Profile reads the encrypted onboarding draft, edits name and city locally,
  exposes versioned terms and privacy records, keeps employer visibility and
  notifications as local controls, and provides working secure-session logout
- The persistent Phase 1.6 shell now hosts all six feature implementations;
  state remains available while switching tabs and global Coach navigation
  remains above the active branch

### Phase 1 completion local validation record
- `flutter pub get` — passed
- `dart format .` — passed; 94 Dart files checked with no changes
- `flutter analyze` — passed with no issues
- `flutter test` — passed; 46 tests
- Home populated/empty/error/refresh, Coach messaging/reset, Learning
  offline/download/completion, Practice interaction, Jobs consent/persistence,
  Profile editing/logout, retained tab state, protected routing, onboarding,
  secure storage, accessibility, and narrow-screen coverage passed
- `flutter build apk --debug` — attempted locally and reached the unchanged
  Gradle build, which exited before project settings evaluation with
  `The settings are not yet available for build`. GitHub Actions remains the
  authoritative Android build validator.

### Phase 1 completion authoritative build and distribution
- GitHub Actions **Build Candidate Mobile APK** run `30295690458` — passed for
  commit `334152c`: dependency resolution, static analysis, universal debug APK
  build, and artifact upload completed successfully
- The 77,094,449-byte Actions artifact passed ZIP integrity validation after
  parallel-range download
- The universal 155 MB debug APK was reduced to an 84,468,608-byte Samsung
  package by removing only armv7 and x86_64 native libraries; `arm64-v8a` is
  the sole packaged ABI
- The ARM64 APK passes zip alignment and Android APK Signature Scheme v2/v3
  verification and is published in GitHub prerelease `phase-1-complete-qc`
- ARM64 QC APK SHA-256:
  `4f430a605fe4a88381c732e4dfc5118d403c6619d75f9ae191b986620e5bc0cf`
- Wireless ADB updated `com.example.candidate_mobile` in place on Samsung
  `SM-S928B` in 6.2 seconds, launched it, and confirmed the application process
  remained active
- Visual feature QC remains with the tester; automated validation and Android
  installation/launch validation are complete

### Phase 2 implementation
- Environment-gated Supabase initialization accepts only a project URL and
  modern `sb_publishable_` client key; no secret or service-role credential is
  stored in Flutter
- Supabase phone OTP and candidate profile/consent repositories implement the
  existing provider-neutral contracts, while secure local adapters remain the
  default when remote configuration is absent
- Immutable, versioned role, competency, diagnostic, pathway, learning, and
  simulation definitions seed a logistics candidate-intelligence foundation
- The accessible career diagnostic records four competency signals and
  returns explainable role gaps and a recommended learning pathway; it does
  not use personality scoring or automated rejection
- Learning units now include real local lesson/checkpoint content, download
  state, completion state, and local-first progress synchronization
- Practice includes a scored inventory-discrepancy simulation with ordered
  events, deterministic accuracy/escalation/sequence scoring, transparent
  feedback, attempt history, and generated competency evidence
- Technical interruption events are stored for reliability analysis and
  explicitly excluded from candidate scores
- Profile shows generated evidence and pending synchronization state
- Resume parsing is represented by a provider-neutral repository contract; no
  resume processor, credential, file upload, or unsupported accuracy claim was
  introduced
- Non-PII analytics cover diagnostic completion, learning progress, and
  simulation submission
- ADR-0013 preserves the planned NestJS BFF for privileged, consequential,
  employer, administrator, AI, resume-processing, and cross-candidate
  operations

### Phase 2 JobSkills database
- Applied three versioned migrations to the separate Supabase project
  `JobSkills` (`qoairksjpwkhwqxeollj`); no ZHealth project or files were
  accessed
- Added 17 public tables for candidate profiles, consent, taxonomy,
  diagnostics, pathways, learning, simulations, scores, evidence, and
  resume-parse job metadata
- All public tables have row-level security enabled; candidate records require
  `auth.uid()` ownership and published reference definitions are read-only to
  mobile clients
- Simulation events use ordered, idempotent persistence and scores reference
  their attempt
- Revoked client execution of the pre-existing
  `public.rls_auto_enable()` security-definer function and added missing
  foreign-key indexes
- Supabase Security Advisor reports zero findings; Performance Advisor reports
  only expected unused-index informational findings while the new tables are
  empty

### Phase 2 validation record
- `flutter pub get` — passed
- `dart format .` — passed; 110 files checked with no changes
- `flutter analyze --no-pub` — passed with no issues
- `flutter test --no-pub --reporter expanded` — passed; 55 tests
- Diagnostic, deterministic scoring, secure repository, offline learning,
  simulation evidence, existing Phase 1 navigation, authentication,
  onboarding, accessibility, and narrow-screen flows all passed
- Supabase migrations — applied successfully to JobSkills
- Supabase Security Advisor — passed with zero findings
- `flutter build apk --debug --no-pub` — attempted locally and reached the
  unchanged Gradle 9.1 host failure, `The settings are not yet available for
  build`, before source compilation
- GitHub Actions **Build Candidate Mobile APK** run `30324795201` — passed for
  commit `568afe8`: dependency resolution, analysis, debug APK build, and
  artifact upload completed successfully

### Phase 2 APK verification
- The 79,403,186-byte Actions artifact passed ZIP integrity validation and
  contained a 157,601,739-byte universal debug APK
- The Samsung QC package was derived from that verified APK by removing only
  armv7 and x86_64 native libraries, retaining `arm64-v8a`, zip-aligning, and
  re-signing with the same project debug certificate used for earlier QC
  builds
- The ARM64 APK passes Android APK Signature Scheme v2/v3 verification
- ARM64 QC APK SHA-256:
  `c8215600a8f68af447052dcaf93ca7c39e708bc44fb6c82eb4717c928acfe679`
- The 86,803,328-byte ARM64 APK is published in GitHub prerelease
  `phase-2-complete-qc`
- Connected-device installation was attempted, but ADB reported no USB device
  and the previous Wireless Debugging endpoint `192.168.1.5:45367` refused the
  connection; installation and visual device QC remain pending a current ADB
  connection
- The complete Phase 2 implementation is also present in the later cumulative
  Phase 3.1 APK, which was clean-installed and launched successfully

### Phase 3.1 implementation
- Added a feature-first recorded-turn voice interview route from Home with
  loading, recoverable error, offline, pending-upload and completed states
- Added purpose-separated consent for recording, transcription, evaluation and
  optional employer sharing; sharing defaults to disabled
- Added microphone permission education, readiness check and real AAC-LC
  recording through platform microphone APIs
- Added three versioned logistics interview questions, per-turn controls,
  interruption recovery and local audio deletion
- Added a resumable media-upload repository contract and local queue;
  production signed credentials and transfer remain behind the planned BFF
- Added candidate-reviewed transcript entry because no production transcription
  provider is configured; the app never fabricates transcript text
- Added deterministic transcript-only development feedback across relevance,
  operational correctness, structure, clarity and safe escalation
- Evaluation records prompt `P-VOICE-EVALUATOR-001@1.0.0` and rubric
  `voice-logistics-v1`, reports low confidence, and always requires human review
- Accent, vocal emotion, personality, protected traits and technical failures
  are excluded; no evaluation can reject or shortlist a candidate
- Added non-PII analytics for consent, recorded turns, feedback and review
  requests
- ADR-0014 documents the recorded-turn, media and consequential AI boundary

### Phase 3.1 JobSkills database
- Applied two additive migrations to the separate JobSkills project; no ZHealth
  project or files were accessed
- Added 13 voice tables for versioned prompts/rubrics, consent, sessions, turns,
  media metadata, transcripts, AI runs, evaluations, human review, feedback,
  appeals and audit records
- Added private `voice-media` storage with a 15 MB object limit and approved
  audio MIME types
- Deliberately exposed no authenticated `storage.objects` policy: the planned
  BFF must authorise short-lived media credentials
- Candidate tables use ownership RLS and least-privilege grants; AI-run and
  audit tables remain closed to mobile clients
- Supabase Security Advisor reports zero findings; Performance Advisor reports
  only expected unused-index notices while the new tables contain no traffic

### Phase 3.1 validation record
- `flutter pub get` — passed
- `dart format .` — passed; 120 files checked
- `flutter analyze --no-pub` — passed with no issues
- `flutter test --no-pub` — passed; 59 tests
- Voice evaluation, secure interruption recovery/deletion and the complete
  consent-to-human-review widget flow passed
- Supabase migrations — applied successfully to JobSkills
- Supabase Security Advisor — passed with zero findings
- `flutter build apk --debug --no-pub` — attempted locally and reached the
  unchanged Gradle 9.1 host failure, `The settings are not yet available for
  build`, before Android source compilation; GitHub Actions remains
  authoritative
- GitHub Actions **Build Candidate Mobile APK** run `30327701922` — passed for
  commit `f3c9fab`: dependency resolution, static analysis, debug APK build and
  artifact upload completed successfully

### Phase 3.1 APK verification
- The 79,597,027-byte Actions artifact matched GitHub's SHA-256 digest and
  passed ZIP integrity validation
- The 150 MB universal debug APK was reduced to an 87,014,555-byte Samsung
  package by removing only armv7 and x86_64 native libraries; `arm64-v8a` is
  the sole packaged ABI
- The ARM64 APK passes zip alignment and Android APK Signature Scheme v2/v3
  verification
- ARM64 QC APK SHA-256:
  `9cf7ddedbe19109496e8382036641920f6175ec88d59e7a787589179bdb9735b`
- The APK is published in GitHub prerelease `phase-3.1-voice-qc`
- Wireless ADB connected to Samsung `SM-S928B` at `192.168.1.5:34801`;
  clean incremental installation completed successfully in 9.1 seconds
- Android launched `com.example.candidate_mobile/.MainActivity`, and the
  application process remained active; visual feature QC remains with the
  tester

### Workplace Management Simulation v0.2 backbone
- Added industry-neutral, typed pack, workplace, role, competency, mission,
  task, resource, scenario, scoring, critical-error, remediation, attempt,
  action, result and evidence contracts
- Added a versioned logistics content pack and first receive-shipment mission
  with six workstations, eleven tasks, six carton templates, five deterministic
  issue types, weighted scoring and six critical-error rules
- Added deterministic scenario generation keyed by mission version and seed
- Added an explicit state machine, candidate-action validation, content-driven
  evaluation, progress calculation, deterministic scoring, critical-error
  handling, remediation and competency evidence
- Added candidate-isolated encrypted local attempts with append-only,
  continuously sequenced audit actions and fresh retry identifiers
- Added a UI-neutral Riverpod controller behind stable content and attempt
  repository interfaces
- Preserved the existing Phase 2 production Practice simulation; no WMS route,
  production screen, Supabase migration, BFF, Redis, AI or voice dependency
  was introduced
- ADR-0015 records the additive engine and deferred-presentation decision

### Workplace Management Simulation v0.2 local validation
- `dart format .` — passed; no outstanding changes
- JSON content syntax validation — passed for all five content documents
- `flutter analyze --no-pub` — passed with no issues
- Focused WMS test suite — passed; 16 tests covering content references,
  deterministic variation, state transitions, append-only ownership,
  validation, scoring, critical errors, evidence and controller retry
- Full Flutter suite — 73 of 75 tests passed. The two failures are existing
  Home-navigation expectations and reproduce unchanged at prior released
  commit `bc11641`; neither test imports or exercises the WMS feature
- `flutter build apk --debug --no-pub` — attempted locally and reached the
  unchanged Gradle 9.1 host failure, `The settings are not yet available for
  build`, before Android source compilation
- GitHub Actions **Build Candidate Mobile APK** run `30373557367` — passed for
  commit `96607e2`: dependency resolution, static analysis, debug APK build
  and artifact upload completed successfully

### Workplace Management Simulation v0.2 APK verification
- The 79,648,286-byte Actions artifact matched GitHub's SHA-256 digest and
  passed ZIP integrity validation
- The 151 MB universal debug APK was reduced to an 87,080,706-byte Samsung
  package by removing only armv7 and x86_64 native libraries; `arm64-v8a` is
  the sole packaged ABI
- The ARM64 APK passes zip alignment and Android APK Signature Scheme v2/v3
  verification
- ARM64 QC APK SHA-256:
  `9393264ea00734d04506d694f8df2200eae7315ff377ed5fcd3109d6a1d8631c`
- The APK is published in GitHub prerelease `wms-v0.2-backbone-qc`
- No ADB device or Wireless Debugging service was discoverable, so installation
  remains pending; the APK contains no new WMS production screen by design

### WMS Screen 01–02 implementation
- Added a state-aware Workplace Simulation card and professional Simulation
  Entry route under the existing `/practise` hierarchy with workplace,
  role, mission, progress, objectives, Mission Details and a single state-aware
  Start, Continue or Retry action
- Added Supervisor Briefing with role-based supervisor identity, shipment
  summary, approved message, responsibilities, workplace rules, mandatory
  acknowledgement and disabled/loading Begin Shift states
- Added protected entry, briefing and temporary workplace-handoff routes
  without changing the approved five-tab navigation
- Added persisted `createdAt`, `briefingAcknowledgedAt`, `shiftStartedAt`,
  `pausedAt`, `timerResumedAt`, `completedAt`,
  `elapsedSimulationSeconds` and typed `timerStatus` lifecycle state; reading
  and paused time are excluded from elapsed simulation time
- Added candidate-owned, append-only, continuously sequenced unscored audit
  events with attempt, mission/version, screen, optional target, event type,
  elapsed duration, occurrence time and JSON-compatible non-sensitive payload
- Kept `LearnerAction` as the only scoreable behavioural stream; audit events
  have no scoring or critical-error dependency
- Added typed Begin Shift outcomes, in-flight duplicate protection and an
  atomic repository start operation so the timer and `shiftStarted` audit
  event cannot be partially persisted
- Added fresh retry seeds, audit-backed local analytics, offline messaging,
  48 dp controls, logical semantics, restrained motion and reduced-motion
  handling
- Screen 03 operational floor remains explicitly unimplemented; the handoff
  states that no workstation UI has been invented

### WMS Screen 01–02 local validation
- `dart format .` — passed with no outstanding changes
- `flutter analyze --no-pub` — passed with no issues
- Focused WMS, routing and Phase 2 regression suite — passed; 25 tests,
  including injected persistence failure rollback
- Complete entry-to-briefing-to-shift widget flow passed at 200% text scaling
- Full Flutter suite — 79 of 81 tests passed. The two remaining
  `Today’s mission` Home-navigation expectations are unchanged baseline
  failures reproduced at `bc11641`; neither exercises WMS
- `flutter build apk --debug --target-platform android-arm64` — attempted
  locally after successful dependency resolution and failed in Gradle 9.1
  settings evaluation with `The settings are not yet available for build`
  before Android source compilation
- GitHub Actions remains the authoritative Android build and is recorded after
  the source commit is pushed
- GitHub Actions **Build Candidate Mobile APK** run `30381388413` — passed for
  cumulative source commit `0d85f00`: dependency resolution, analysis,
  universal debug APK build and artifact upload completed successfully
- The verified universal artifact digest is
  `a4d654da682c2f2ab6b30ef2b5780d95ec60ac631ee114556fa0442ac36bd0b5`
- The 87,174,914-byte Samsung QC package retains only `arm64-v8a`, passes ZIP
  alignment and Android APK Signature Scheme v2/v3 verification, and is
  published in prerelease `wms-screen-01-02-qc`
- ARM64 QC APK SHA-256:
  `f6a14f0a341f88f91e87b2f8b3ca7aeaf318ae6e803f2d116f701e54b4c00f93`

### WMS Screens 03–06 implementation
- Replaced the Screen 03 handoff with a responsive, accessible Workplace
  Overview whose progress, station status, locked reasons and deterministic
  recommendation come from the application controller
- Added typed workstation-open and save-and-exit outcomes, atomic pause/resume
  and exit persistence, and unscored workstation/lifecycle audit events
- Added persisted, revisioned Document Review and Receiving Count drafts with
  typed add, update, remove, save and submit commands
- Added append-only draft and final learner-action evidence while keeping
  correctness evaluation separate from structural process completion
- Added Screen 04 Purchase Order/Delivery Note comparison and multiple editable
  findings without answer reveal
- Added Screen 05 shipment identity confirmation, per-carton counts, revision
  metadata, partial progress and structural validation without exposing
  expected physical quantities
- Added canonical dynamic `/practise/workplace-simulation/:missionId/...`
  routes and controlled locked-state handling for direct route access
- Added the agreed Screen 06 Inspection Zone placeholder only; inspection,
  barcode, quarantine, office, decision, reporting and results remain deferred
- The application-level operational commit persists aggregate, progress,
  actions and audits as one encrypted local value. A database transaction
  adapter remains deferred until remote persistence is introduced.

### WMS Screens 03–06 local validation
- `dart format .` — passed; 155 Dart files checked
- JSON syntax validation — passed for all WMS logistics documents
- `flutter analyze --no-pub` — passed with no issues
- Focused WMS and routing suite — passed; 26 tests covering content,
  deterministic scenarios, scoring regression, typed commands, progression,
  draft persistence, append-only streams, locked access, large text and the
  Screen 01–03 flow
- Full Flutter suite — 80 of 82 tests passed. The two unchanged
  `Today’s mission` Home-navigation expectations remain the documented
  baseline failures and do not import or exercise WMS.
- `flutter build apk --debug --target-platform android-arm64 --no-pub` —
  attempted locally, but the managed workspace denied Gradle’s lock-file write
  under the user Gradle cache before project compilation. GitHub Actions
  remains the authoritative Android build path.
- GitHub Actions **Build Candidate Mobile APK** run `30395600323` — passed for
  cumulative source commit `b6799a8`: dependency resolution, analysis,
  universal debug APK build and artifact upload completed successfully
- The verified universal APK was reduced to an 87,269,122-byte Samsung package
  by removing only armv7 and x86_64 native libraries; `arm64-v8a` is the sole
  packaged ABI
- The arm64 APK passes ZIP alignment and Android APK Signature Scheme v2/v3
  verification and is published in prerelease `wms-screen-03-06-qc`
- ARM64 QC APK SHA-256:
  `5467f2e3f9e64eeb4591b6e286561f68d8fedf756640a09b71884b7f26f8ccf8`
- Wireless ADB updated `com.example.candidate_mobile` in place on Samsung
  `SM-S928B` in 5.8 seconds, launched it and confirmed process `26108` remained
  active; visual workflow QC remains with the tester

### WMS Screen 06 Inspection Zone implementation
- Replaced the Screen 06 handoff placeholder with a real Inspection Zone
  screen implementing the already-authored `physical-inspection` stage from
  `receive_shipment_mission.json`: `inspect-cartons` (record a finding —
  compliant, packaging damage, near expiry, incorrect SKU, quantity shortage,
  or unreadable barcode — per carton) and `scan-barcodes` (record
  readable/unreadable per carton), both against the same six cartons
- Added a persisted `InspectionDraft` (per-carton inspection and scan entries,
  each independently editable/removable pre-submission with revision
  numbers), mirroring the existing Document Review and Receiving Count draft
  pattern
- Added typed record/update/remove/save-draft/submit commands and controller
  methods for both tasks; individual edits emit unscored draft audit actions,
  final submission applies the real scored `inspect_item`/`record_issue`/
  `scan_barcode` actions per carton against the mission's existing evaluation
  rules — no new scoring logic was invented
- Submission requires every one of the six cartons to have both an inspection
  finding and a barcode scan recorded before it validates; unlocks Quarantine
  Zone (not yet built — tapping it shows the existing "coming next" message,
  unchanged from how every other not-yet-built workstation already behaves)
- Fixed a pre-existing bug discovered while cross-checking the separately
  delivered `flora-sim-v3` content package: that package's screen numbering is
  a different, independently authored breakdown of the same Receiving
  workflow and does not correspond 1:1 to this app's actual
  `receive_shipment_mission.json` stages; this implementation follows the
  mission JSON actually wired into the app, not that package

### WMS Screen 06 local validation
- `dart format .` — passed; 4 files reformatted (own new/changed files)
- `flutter analyze --no-pub` — passed with no issues
- `flutter test --no-pub --reporter expanded` — 82 of 84 tests passed; the
  two failures are the unchanged pre-existing `Today's mission`
  Home-navigation baseline failures (documented since the WMS Screens 03–06
  milestone) and do not import or exercise WMS
- `flutter build apk --debug --no-pub --target-platform android-arm64` —
  succeeded locally (Android SDK Platform 34 auto-installed during the run),
  producing an 87,271,939-byte `app-debug.apk`; this is the first WMS
  milestone where the documented Gradle 9.1 host failure did not reproduce.
  GitHub Actions remains the authoritative Android build validator for CI.

### WMS Receiving mission completion (Quarantine Zone, Receiving Office, Performance Feedback)
- Replaced the remaining not-yet-built portion of the Receiving mission with
  real screens, completing the mission end to end from Screen 01 through
  results: **Quarantine Zone** (`assign-dispositions` — per-carton
  disposition with a reason required for anything except Accept, matching
  `task_validation_service`'s reason requirement; `confirm-quarantine`),
  **Receiving Office** (`complete-discrepancy-report` — five-flag recall
  form; `make-receiving-decision` — accept/partially-accept/reject;
  `notify-supervisor`), and **Performance Feedback** (renders the real
  `SimulationResult` from the existing scoring engine — status, overall
  score, category scores, competency evidence, critical errors, missed
  issues, correct actions, recommended remediation — no fabricated content)
- Added `DispositionDraft`/`DispositionEntry` and `DiscrepancyReportDraft`
  domain models, typed commands/controller methods, and a `completeMission()`
  wrapper around the existing `submit()` scoring call
- Inspection Zone and Quarantine Zone now navigate forward to the next
  unlocked screen on successful submission (previously Inspection Zone
  returned to the overview, since Quarantine Zone did not exist yet)
- **Correctness fix found and fixed during implementation:** `make-receiving-
  decision` is a non-repeatable task with only one scored-correct payload
  (`partially_accept`); an incorrect decision (accept/reject) leaves it out
  of `completedTaskIds` with no way to retry (engine-level, one shot per
  non-repeatable task). The `notifySupervisor` gate originally required that
  task's *completion*, which would have permanently stranded a learner who
  picked wrong with no way to finish the shift or see results. Changed the
  gate to require only that the task was *attempted*— the learner can always
  finish the shift; the scoring engine already correctly reflects a wrong
  decision via `mandatoryTasksCompleted`/`status` without any screen-level
  dead end. Covered by a dedicated test
  (`a wrong receiving decision still lets the learner finish the shift`)
- **Second correctness fix:** initially recorded discrepancy-report checkbox
  edits as a draft `LearnerAction` against the same non-repeatable
  `complete-discrepancy-report` task id used by the real scored submission —
  `task_validation_service` forbids a second action on a non-repeatable task
  regardless of whether the first was a draft edit, so the real submission
  always failed. Fixed by recording draft edits as an audit event instead of
  a `LearnerAction` (mirrors how `confirm-quarantine`/`notify-supervisor`,
  which are also non-repeatable single-shot tasks, were built with no
  intermediate draft action at all)
- Removed three `ActionType` values added but never actually constructed
  (`inspectionSubmitted`, `dispositionsSubmitted`,
  `discrepancyReportFlagsUpdated`) rather than leave dead enum entries

### WMS Receiving mission completion — local validation
- `dart format .` — passed
- `flutter analyze --no-pub` — passed with no issues
- Focused WMS suite — 25/25 passed, including a full mission run from
  Document Desk through `completeMission()` with `mandatoryTasksCompleted:
  true` and zero critical errors, plus the wrong-decision stuck-state
  regression test
- Full Flutter suite — 83 of 85 tests passed; the two failures are the
  unchanged pre-existing `Today's mission` Home-navigation baseline failures
  and do not import or exercise WMS
- `flutter build apk --debug --no-pub --target-platform android-arm64` —
  succeeded locally, producing a 110,134,994-byte `app-debug.apk`. GitHub
  Actions remains the authoritative Android build validator for CI.

### Put Away mission — runtime wiring
- Put Away's content (`put_away_mission.json`, workstations, competencies,
  remediation) previously proved "zero engine changes" only via a headless
  test that bypassed the app's repository/controller and loaded mission JSON
  directly. This milestone wires it into the real app so it is reachable and
  playable through actual navigation, not just proven by a bypass test.
- `AssetSimulationContentRepository.getMission()` was hardcoded to always
  load `receive_shipment_mission.json` regardless of the requested
  `missionId` (the id was only used for a post-load equality check). Replaced
  with a `missionId -> file name` map and a per-mission cache so any mission
  id with a registered content file resolves correctly.
- `workplaceSimulationControllerProvider` converted from a plain
  `AsyncNotifierProvider` (one mission, globally) to
  `AsyncNotifierProvider.family<..., String>`, keyed by `missionId`. Screens
  and tests now read `workplaceSimulationControllerProvider(missionId)`
  instead of a single shared instance.
- **Correctness gap found and fixed:** `SimulationEntryScreen` and
  `SupervisorBriefingScreen` never accepted a `missionId` constructor
  parameter at all, even though the router already extracted
  `state.pathParameters['missionId']` for their routes — latent because only
  one mission ever existed. Added the parameter to both and threaded it from
  `app_router.dart`.
- **Correctness fix (department-scoping leak):** `workplaceOverview` built
  its workstation list from every workstation across every department in
  `workplace.json` rather than filtering by the current mission's
  department. Harmless with one department; once Put Away's four
  workstations were added to the shared `workplace.json`, they leaked into
  the Receiving mission's own Workplace Overview screen. Fixed by filtering
  on `station.departmentId == current.mission.departmentId`, and fixed an
  adjacent `departments.first.name` lookup (only correct by ordering luck)
  to look up the department by id.
- `PracticeScreen.onOpenWorkplaceSimulation` changed from `VoidCallback` to
  `void Function(String missionId)`; the Practice tab now renders two
  Workplace Simulation cards — Receive an Incoming Shipment and Put Away
  Incoming Stock — each independently watching its own family-provider
  instance and opening its own mission by id.
- **What is and is not playable yet:** a candidate can now open either
  mission from Practice, go through Simulation Entry, acknowledge the
  Supervisor Briefing, start the shift, and reach Workplace Overview showing
  Put Away's real four workstations (Staging Area, Location Planning,
  Transport & Placement, Putaway Office) with correct locked/available
  state. `WorkplaceOverviewScreen` still routes taps to five hardcoded
  Receiving-only screen callbacks, so tapping a Put Away workstation has
  nowhere to go yet — the four Put Away workstation screens (mirroring the
  Receiving Document Desk / Receiving Dock / Inspection Zone pattern, built
  on the existing generic `recordAction()` controller method rather than
  bespoke per-task wrapper methods) are the next stacked increment needed
  for genuine end-to-end completion of the Put Away mission.

### Put Away mission — runtime wiring — local validation
- `dart format .` — passed
- `flutter analyze --no-pub` — passed with no issues
- Focused WMS suite — 29/29 passed
- Full Flutter suite — 86 of 89 tests passed; the three failures are the
  same pre-existing baseline flakes as prior milestones (`Today's mission`
  Home-navigation ordering flakiness across `main_navigation_test.dart`,
  `phase_one_shells_test.dart`, `candidate_onboarding_flow_test.dart`),
  confirmed unrelated by reproducing them on the unmodified base branch
  before this change; none import or exercise WMS
- `flutter build apk --debug --no-pub --target-platform android-arm64` —
  succeeded locally, producing a 110,140,295-byte `app-debug.apk`. GitHub
  Actions remains the authoritative Android build validator for CI.

### Merge to main
PRs #5 (Screen 06 Inspection Zone), #6 (Receiving content specification), #7
(Quarantine Zone/Receiving Office/Performance Feedback) and #9 (Put Away
runtime wiring) were merged in sequence into `feature/flutter-foundation`
(one real merge conflict on `workplace.json` between #6's and #9's additions
to the `receiving`/`put-away` department entries, resolved by keeping both).
`feature/flutter-foundation` was then merged into `main` via PR #2 after its
CI build passed — the first time this Flutter app foundation has been live
on `main`. PR #8 (Put Away content-only) was closed as superseded, since #9
was cut before #8 merged and carries the same content forward alongside the
runtime wiring.

### Put Away mission — the four workstation screens
Built **Staging Area** (`open-putaway-list` — read-only task list review),
**Location Planning** (`assign-storage-zone` — per-item zone assignment
across 6 items with plain-language handling notes instead of exposed issue
flags, mirroring how Inspection Zone withholds findings; `record-location-
exception` — optional capacity-exception flag), **Transport and Placement**
(`transport-and-place-items` move → `scan-items-to-bins` scan → `confirm-
quantities-placed` count, sequenced per item), and **Putaway Office**
(`complete-putaway-report` form → `make-putaway-decision` → `notify-
supervisor`, with the same "gate on attempted, not completed" pattern used
for Receiving's decision task so a wrong putaway decision still lets the
learner finish the shift). A learner can now complete an entire Put Away
shift from Practice through Performance Feedback with real competency
evidence, not just navigate to Workplace Overview.

**Architecture fix applied while building these, per the flagged reusable-
architecture gap:** none of the four screens have their own bespoke
controller methods. Every task submission calls the existing generic
`recordAction()` directly with the task's real `ActionType` and payload —
the same validate/evaluate/score/persist path Receiving uses — instead of
adding ~15 more one-task-one-method wrappers like Receiving's `record
CartonCount`/`updateCartonCount`/`removeCartonCount` triplet pattern.
Progress ("3 of 6 items zoned") is read directly off `attempt.actions` and
`attempt.completedTaskIds` rather than a new per-screen draft model.

**Real bug found and fixed, not just Put Away's:** `WorkplaceOverviewScreen`
routed workstation taps through five `VoidCallback onOpen*` constructor
parameters, hardcoded to Receiving's five screens — replaced with a single
`void Function(String workstationId) onOpenWorkstation`, resolved
content-generically in `app_router.dart` via a `workstationId -> path`
lookup (`workstationPath()`) that already extends to Put Away and any future
department by adding one map entry, not new screen wiring. Separately —
and more seriously — `WorkplaceSimulationController.openWorkstation()` had
its *own*, different hardcoded route-existence check
(`_workstationRoute()`), listing only `document-desk`, `receiving-dock` and
`inspection-zone`. This silently returned `routeUnavailable` for **Quarantine
Zone and Receiving Office too** whenever a candidate returned to Workplace
Overview and tapped an already-unlocked station directly instead of using a
prior screen's forward-navigation callback — a latent bug in the already-
shipped Receiving mission, not something introduced by Put Away. The backing
`WorkstationViewModel.route` field the check fed was dead — never read by
any screen. Removed the check and the field entirely; `openWorkstation()`
now gates purely on `unlockRequirements`-derived lock status, which was
already the correct source of truth. Caught by a Put Away widget test that
tapped a station card from Overview rather than only testing forward-chained
navigation.

**Correction to a citation carried across the last two milestones' "Next
implementation" notes:** the WebGL/3D viewer deferral was attributed to
"ADR-001." No such file exists in `docs/adr/` (only ADR-0013 through
ADR-0017, none about a 3D viewer). This citation should not be repeated
until the real source is found or the reference is dropped.

### Put Away mission — the four workstation screens — local validation
- `dart format .` — passed
- `flutter analyze --no-pub` — passed with no issues
- Focused WMS suite — 31/31 passed, including a full Put Away playthrough
  through the real family-provider controller (`recordAction()`/
  `completeMission()`, the same calls the screens make) asserting workstation
  unlock order and a final `SimulationResult` with `status: passed`,
  `mandatoryTasksCompleted: true`, zero critical errors — plus a widget test
  covering all four screens' locked-state rendering and the Staging Area
  interaction end to end
- Full Flutter suite — 88 of 91 tests passed; the three failures are the
  same pre-existing baseline flakes as prior milestones, unrelated to WMS
- `flutter build apk --debug --no-pub --target-platform android-arm64` —
  succeeded locally. GitHub Actions remains the authoritative Android build
  validator for CI.

### API (BFF) — Phase 3.2 first slice
Per `docs/20-codex-phase-execution.md`, Phase 3.2 (job application
operations) does not require the doc 23 bounded-context approval gates —
those gate only Career/Competency Passport/Employer/Placement
Partner/Government platform code. Phase 3.2 is already-scoped work waiting
on the BFF existing, so it proceeded independently of that larger,
still-unresolved architecture question.

Added `apps/api`, a NestJS service at the path the README's proposed
monorepo layout already specifies — the first backend service in the repo
(previously only `apps/candidate-mobile` existed). Implements the one real vertical
slice `docs/03-api-specifications.md` specifies:
`POST /v1/jobs/{id}/applications` — consent-gated (checks an active
`employer_sharing` `consent_grants` row, reusing the same purpose string the
voice interview feature already uses for the same real-world concept, rather
than inventing a second consent mechanism), idempotent (an `Idempotency-Key`
header is required; a repeat call for the same candidate and job returns the
existing application rather than erroring or duplicating — enforced by a
`unique (job_id, candidate_id)` database constraint, not just an
application-level check, so concurrent requests are actually safe), and
authenticated by verifying the bearer token against Supabase Auth directly
(`auth.getUser()`) rather than decoding the JWT locally, so a revoked
session is correctly rejected. `GET /v1/jobs` (published jobs only) exists
as the minimal supporting read needed to make the write endpoint
exercisable, not as the "authoritative job matching" scope doc 20
describes — that remains unbuilt.

Added `supabase/migrations/20260729182817_phase_three_job_applications.sql`
(`jobs`, `job_applications`, RLS, three seeded published jobs) — not yet
applied to any live project. The repository's Supabase MCP connection was
found to be scoped only to an unrelated project (`nutridiet`); the real
project (`qoairksjpwkhwqxeollj`) needs its own project-scoped MCP connection
added and authenticated from a terminal before this can be applied directly
in a session.

Errors follow `docs/03-api-specifications.md`'s envelope exactly —
`{"error": {"code", "message", "details", "request_id"}}` — verified by
booting the service against a syntactically-valid but unreachable Supabase
URL and confirming both the 401 status and the exact JSON shape over a real
HTTP request, not just unit-tested.

**Local validation:** `npx tsc --noEmit` — passed. `npx eslint` — passed, no
issues. `npx jest` — 7/7 passed (consent gating, idempotent create, 404 on
unpublished jobs, revoked-consent rejection — all against a hand-built fake
Supabase client, no live database needed). `npx nest build` then
`node dist/main.js` — boots, maps both routes, fails loudly and exits (does
not hang) when Supabase env vars are missing; with placeholder env vars
boots clean and returns the correct error envelope over real HTTP for both
an invalid and a missing bearer token. A `.github/workflows/build-api.yml`
(install, build, test on push to `main` under `apps/api/**`) was written
locally but not pushed with this milestone -- the push token in use lacks
the `workflow` scope GitHub requires to add or modify Actions files. It
needs adding through the GitHub UI or a token with that scope.

### Jobs — job-applications migration applied; Apply wired to the real BFF endpoint
The migration is now applied to the real project (`qoairksjpwkhwqxeollj`),
but not from this session. This remote session's own `Supabase` MCP
connector remained scoped to only the unrelated `nutridiet` project all the
way through this milestone — `get_project`/`list_tables` for
`qoairksjpwkhwqxeollj` kept returning "You do not have permission to perform
this action" no matter how many times connector authentication was redone,
and direct `psql` (including via the Supavisor session pooler, to work
around `db.*.supabase.co` being IPv6-only) was a dead end too: this
sandbox's network policy silently drops any outbound TCP that isn't port
80/443, so raw Postgres connections cannot be made from here at all,
independent of Supabase. Both are environment/connector limitations of this
particular session, not fixable from inside it.

The candidate's separate local Claude Code session had its own, differently
-scoped `supabase` MCP connection with real access, and applied it directly
from there. In doing so it found and fixed a real bug this migration shipped
with: `role_profile_code text references role_profiles(code)` cannot work
because `role_profiles` is versioned (primary key `id`, unique constraint on
`(code, version)`, no unique constraint on `code` alone) — the first apply
attempt failed with `ERROR 42830: there is no unique constraint matching
given keys for referenced table "role_profiles"`. Fixed by matching the
pattern every other table in the schema already uses
(`role_competency_requirements`, `learning_pathways`,
`simulation_definitions`): `jobs.role_profile_id uuid references
role_profiles(id)`, with the seed insert resolving each role code to its
published profile's id via a join instead of storing the code directly.
`apps/api/src/jobs/jobs.service.ts` never selected the role-profile column,
so no API code change was needed. The originally-committed migration file
was renamed from `20260729180000_...` to `20260729182817_...` to match the
version the server actually recorded (otherwise a future `supabase db push`
would try to run it again), and a follow-up
`20260729182917_phase_three_job_applications_advisor_remediation.sql` adds
`jobs_role_profile_id_idx` — the Performance Advisor's unindexed-foreign-key
finding on the new `role_profile_id` column, fixed the same way the existing
`*_advisor_remediation` migrations already fix that class of finding.
Reported from that session: both migrations applied; Security Advisor clean
(no lints); remaining Performance Advisor lints are all "unused index" INFOs
expected for tables with no query traffic yet; all three seeded jobs present
with correct role-profile links (Apex → `warehouse_associate`, Meridian →
`inventory_executive`, Northstar → `dispatch_executive`). That verification
was performed by the other session against the live database, not by this
one — this session still has no working path to query
`qoairksjpwkhwqxeollj` directly and could not independently re-verify it.
The fix commit was pushed to `origin/api-phase-3-2-job-applications` and
cherry-picked into this branch clean (no conflicts).

That blocker not being fixable from here didn't gate the client side, so
this milestone separately wired apps/candidate-mobile's Jobs "Apply" action
to the real `POST /v1/jobs/:id/applications` endpoint, intentionally leaving
job listing on mock data:
- Added `ApiJobsRepository`, composing over the untouched
  `LocalMockJobsRepository` for `loadJobs()` and `readAppliedJobIds()`, and
  overriding only `saveApplication()` to `POST` to the BFF with
  `Authorization: Bearer <Supabase access token>` and a deterministic
  per-(candidate, job) `Idempotency-Key` header, then persisting the same
  local applied-id record on success so the existing "already applied" chip
  and button state keep working unchanged.
- Added `API_BASE_URL` as a new dart-define-gated `AppConfig` field (mirrors
  the existing `SUPABASE_URL`/`SUPABASE_PUBLISHABLE_KEY` gating) and a
  `hasApiConfiguration` getter; `jobsRepositoryProvider` only swaps in
  `ApiJobsRepository` when both Supabase and API configuration are present,
  otherwise it stays on the plain `LocalMockJobsRepository` default exactly
  as before.
- Mapped 401→`AuthenticationFailure`, 403→`PermissionFailure`,
  400/404→`ValidationFailure`, and connection/timeout errors→
  `NetworkFailure`, surfacing the server's `error.message` where available —
  consistent with the app's existing `AppFailure` taxonomy, no new failure
  type introduced.
- Corrected two Jobs-screen strings that were only true while
  `saveApplication` was 100% local ("No data leaves this device.",
  "Demo application saved securely on this device."); nothing else about the
  screen's mock-data framing changed.
- **Known limitation by design of this milestone's scope:** the mock job ids
  (e.g. `warehouse-lucknow`) do not match the real seeded UUIDs in the target
  database, so an Apply tap against a real, fully configured backend is
  expected to fail today (not a valid UUID, so a Postgres error is more
  likely than a clean 404) until job listing itself is wired to real data.
  This milestone proves the request/auth/idempotency/error-mapping wiring,
  the same "prove the mechanism before the data" split already used for the
  BFF endpoint itself in the prior milestone — it does not claim a working
  end-to-end apply flow.

**Local validation:** this remote session's container has no Flutter/Dart
SDK installed at all (`flutter`/`dart` are not on `PATH`, and no install was
found anywhere on disk) — unlike prior milestones, where `dart format`,
`flutter analyze`, and `flutter test` all ran locally and only the Android
Gradle build itself failed on-host. No local Dart command could be run this
session; every edit was instead reviewed by hand against existing repository
conventions (line width, the existing `AppFailure`/`Result` patterns, and
Dio 5.x's public API, which was already a declared but previously-unused
dependency). Followed the existing precedent of not writing a dedicated unit
test for Supabase-touching repositories — `SupabasePhoneAuthRepository`,
`SupabaseCandidateOnboardingRepository`, and
`OfflineFirstCandidateIntelligenceRepository` have none either, since
constructing a real `SupabaseClient` in a unit test isn't set up in this
codebase. The existing widget test that exercises the Jobs Apply flow
overrides `jobsRepositoryProvider` with an explicit `LocalMockJobsRepository`
and is unaffected by this change. GitHub Actions' **Build Candidate Mobile
APK** workflow remains the authoritative validator and has not yet run
against this change.

### Content deepening — NPC dialogue and a scenario catalog
Closed the runtime-capability gap `docs/24-receiving-department-content-
specification.md` section 4.1 flagged: `ResourceType` had no `person`
variant and `ActionType` had no `speak`, so none of the pre-authored NPC
dialogue in that doc could be loaded as content at all. Both are additive
enum values — zero risk to existing content, since `SimulationResource`
already carries arbitrary `content` for any resource type.

Added the **Receiving Supervisor** as a real `person` resource on
`receive_shipment_mission.json` (mission-start greeting, near-expiry
guidance, an anti-shortcut line if the learner tries to skip inspection, a
shift-report acknowledgement — all guidance-only, matching the doc's own
constraint that NPCs never reveal findings or the correct disposition).
Screen-level UI to actually surface this dialogue (a chat bubble, an NPC
tap target) is explicitly not part of this pass — the ask was the runtime
capability plus real content ready to slot in, not the presentation layer;
proven by a schema-level test rather than a widget test.

Also added a real **scenario catalog** — section 3.3's proposal, which
needs `MissionDefinition` to support multiple named, independently
selectable `variationRules` sets rather than one fixed set per mission.
`MissionDefinition.scenarios` (optional, defaults to empty so no existing
content is affected), `ScenarioGenerator.generate(..., scenarioId: ...)`,
`SimulationAttempt.scenarioId`, and `startMission(scenarioId: ...)` are all
additive and back-compatible; `attempt.scenarioId` persists so a resumed
attempt regenerates the same scenario it started with, not the default —
proven directly by a test that simulates a reload through the same
persisted-attempt path a real app restart goes through, not just checked at
creation time. Authored one real catalog entry, `perfect-delivery`: empty
variation rules, so every carton is physically clean, testing whether the
learner still runs full inspection discipline once nothing looks visibly
wrong. Its `pedagogicalIntent` is explicit that this does *not* produce a
fully clean shipment end-to-end — the PO/DN paperwork mismatch (SKU-1002
short by 2, unauthorised SKU-1094) is fixed mission content, not
scenario-varied, so document verification is still exercised regardless of
which scenario is selected.

**Deliberately not attempted this pass**: the doc's other three proposed
scenarios. `multi-exception-shipment` needs `ScenarioGenerator` to allow
more than one issue per resource — it currently enforces at most one
(`assignedTargets` excludes a resource from every subsequent rule once any
rule has claimed it), a real generator change, not a content-only addition.
`wrong-supplier-delivery` needs a new issue type with its own task/
evaluation-rule authoring. `clerical-only-discrepancy` needs new resource
content. All three are catalog-ready once someone writes that follow-up
work; the mechanism to select and score against them already exists now.

### Content deepening — local validation
- `dart format .` — passed
- `flutter analyze --no-pub` — passed (same 4 pre-existing info-level hints
  in `api_jobs_repository.dart`, unrelated to this change)
- Focused WMS suite — 36/36 passed, including new tests: the supervisor
  resource loads as `ResourceType.person` with guidance-only dialogue; a
  named scenario generates independently of the mission default; an unknown
  scenario id fails clearly; and the controller-level reload-persistence
  test described above
- Full suite — 93 of 96 passed; the three failures are the same
  pre-existing baseline flakes as every prior milestone, confirmed
  unrelated
- `flutter build apk --debug --no-pub --target-platform android-arm64` —
  succeeded locally

### Receiving controller refactor — shared guard/persist helpers
Removed the duplicated boilerplate across Receiving's 25 bespoke draft/
submit methods (`document findings`, `receiving count`, `physical
inspection` — carton inspections and barcode scans, `dispositions` and
`confirm quarantine`) in `workplace_simulation_controller.dart`. Every one
of those methods shared the exact same four-part shape: (1) guard on an
active, in-progress attempt (and, for the four `submit*`/`confirm*`
methods, also require a generated scenario), (2) domain-specific
validation, (3) a mutation wrapped in try/catch that returns `success` or
`persistenceFailure`, and sometimes (4) an `onCaught` side-effect (an audit
event) before returning failure.

Extracted three private helpers rather than forcing all four draft types
(and the two standalone confirm actions) into one generic
`recordAction()`-style entry-CRUD abstraction:
- `_activeAttempt()` — returns `(state, attempt)` or `null` if there's no
  in-progress attempt
- `_activeAttemptWithScenario()` — same, plus the generated scenario,
  for the methods that need it (all `submit*`/`confirm*` methods)
- `_tryPersist(action, {onSuccess, onFailure, onCaught})` — runs the
  mutation, returns the typed result, and optionally runs a caught-side
  audit event before returning failure

Each of the 25 methods was rewritten to use these helpers in place of its
manual guard clause and try/catch block, with no change to validation
order, error cases, payload shapes, or audit/event side effects — this is
a pure internal refactor, not a behavior change.

**Deliberately not attempted**: collapsing the four draft types (document
findings, receiving counts, carton inspections + barcode scans,
dispositions) into one generic entry-CRUD method. They're structurally
identical at the guard/persist level (now shared via the helpers above)
but differ in per-entry validation, payload construction, and submission
scoring logic in ways that would make a single generic method more
complex to read than the current explicit per-group methods — three
similar methods beat one deeply-parameterized one here.

### Receiving controller refactor — local validation
- `dart format .` — passed
- `flutter analyze --no-pub` — passed (same 7 pre-existing info-level
  hints: 4 in `api_jobs_repository.dart`, 3 pre-existing
  `curly_braces_in_flow_control_structures` hints in this same file,
  unrelated to this change)
- Focused WMS suite — 36/36 passed, run after each of the four refactored
  groups (document findings, receiving count, physical inspection,
  disposition) to confirm zero regression incrementally, not just at the
  end
- Full suite — 93 of 96 passed; the three failures are the same
  pre-existing baseline flakes as every prior milestone (navigation back
  button, phase-one shells, onboarding versioned consent), confirmed
  unrelated
- `flutter build apk --debug --no-pub --target-platform android-arm64` —
  succeeded locally

### Supervisor NPC dialogue — screen-level UI
Closed the remaining gap from the content-deepening pass: the
`receiving-supervisor` person resource and its `content.dialogue` array
were loadable content with no screen consuming them. Added a shared
`presentation/widgets/supervisor_dialogue.dart` (`npcDialogueLines()` to
parse a resource's dialogue array, `showSupervisorLines()` and
`showAskSupervisorMenu()` bottom-sheet presenters built on the existing
`showAppBottomSheet` helper) and wired all three `trigger` kinds actually
authored in `receive_shipment_mission.json` to the screen where they're
contextually relevant:
- `mission_start` — Document Desk shows the supervisor's greeting
  automatically, once, the first time the screen builds with an
  in-progress attempt.
- `learner_asks` (`near_expiry_policy`, `skip_inspection`) — Inspection
  Zone gained an "Ask the supervisor" AppBar action that opens a topic
  menu; tapping a topic shows its guidance-only answer.
- `supervisor_notified` (`shift_report_acknowledged`) — Receiving Office
  shows the supervisor's acknowledgement line right after
  `notifySupervisor()` succeeds.

All guidance-only per the content spec's own constraint — none of this
reveals a finding, a disposition or scoring information; it's flavor and
policy reinforcement layered on top of the existing draft/submit flow,
with no controller or domain changes required (the person resource was
already loaded into `scenario.resources`/`mission.resources`, just
unrendered).

**Deliberately not attempted**: a general-purpose "chat with any NPC"
system. Only the specific triggers actually present in this mission's
content were wired up; extending to other NPCs/missions is straightforward
once that content exists, but there's no other content to build against
yet.

### Supervisor NPC dialogue — local validation
- `dart format .` — passed
- `flutter analyze --no-pub` — passed (same 7 pre-existing info-level
  hints, unrelated)
- Three new widget tests (one screen each, `supervisor_dialogue_greeting_
  test.dart`, `supervisor_dialogue_ask_test.dart`, `supervisor_dialogue_
  acknowledgement_test.dart`) proving each trigger actually renders on its
  screen and shows the real JSON-authored line, not just that the schema
  parses. **Split into three files, one `testWidgets` each** — every other
  WMS widget-test file in this codebase already follows that one-per-file
  convention, and a single combined file with three `testWidgets` blocks
  reproducibly hung the second and third test for the full 10-minute
  runner timeout when run together, while each passed in seconds when run
  standalone or in its own file. Root cause not further isolated (matching
  existing convention resolved it without needing to); worth remembering
  if this pattern is hit again.
- Focused WMS suite — 39/39 passed (36 previous + 3 new)
- Full suite — 96 of 99 passed; the three failures are the same
  pre-existing baseline flakes as every prior milestone, confirmed
  unrelated
- `flutter build apk --debug --no-pub --target-platform android-arm64` —
  succeeded locally; installed and manually confirmed on a connected
  device (Samsung SM-S928B) via `adb install -r`

### Doc 23 architecture gates — all 9 resolved
Reviewed section 18's 9 gates against actual repo state and closed all of
them:
- **Gate 8 (mobile architecture conformance, ADR-0016) — satisfied.**
  Flutter remains the candidate platform; the Android build pipeline is
  untouched by anything non-conformant.
- **Gate 9 (route conformance, ADR-0017) — satisfied.** The canonical
  `/practise` Workplace Simulation hierarchy has no `/practice` aliases
  anywhere in the app.
- **Gates 1–7 (product boundary, canonical taxonomy, evidence semantics,
  readiness policy, sharing model, employer decision boundary, partner
  authority matrix) — approved and recorded as
  `docs/adr/0018-flora-evidence-and-employability-governance.md`.** Headline
  decisions: Flora is an evidence/decision-support provider, never a
  certification authority (every evidence surface must carry a disclaimer
  string); Flora owns a canonical internal taxonomy with external standards
  as versioned mappings, not primary identifiers; evidence is append-only,
  provenance-labelled (`systemObserved`/`issuerVerified`/`partnerAttested`/
  `candidateReported`/`unverified`) and freshness-aware — retakes accumulate,
  corrections supersede, nothing is deleted; readiness is a 4-outcome,
  time-bound projection (`demonstrated`/`developing`/`insufficientEvidence`/
  `staleEvidence`) that must never silently read as "not ready," and the WMS
  pilot's safest label is "Simulation benchmark demonstrated," never
  "job ready"; sharing is candidate-controlled, purpose-bound, time-limited,
  revocable and audited (DPDP-aligned); automated candidate ranking is
  prohibited in the employer-portal MVP — Flora presents evidence, the
  employer decides; and cross-partner fact conflicts trigger a reconciliation
  case rather than last-write-wins, per a per-fact authority matrix.
- This ADR governs layers that don't exist yet (Competency Passport,
  Employer Portal, partner integrations) — it doesn't authorise building them,
  and WMS's existing controller/action/audit/timing/scoring boundaries are
  unaffected. It's the constraint those future features must be built against,
  recorded now so it isn't decided ad hoc later.

### WMS remote persistence foundation
- Applied two additive migrations to the live JobSkills Supabase project
  (`qoairksjpwkhwqxeollj`):
  `20260731042608_wms_remote_persistence_foundation` and
  `20260731155145_wms_remote_persistence_grant_remediation`
- Added five `public.wms_*` tables:
  `wms_attempts`, `wms_learner_actions`,
  `wms_attempt_audit_events`, `wms_attempt_results` and
  `wms_competency_evidence`
- `wms_attempts` stores the WMS aggregate and operational timer lifecycle:
  `timer_status`, `created_at`, `briefing_acknowledged_at`,
  `shift_started_at`, `paused_at`, `timer_resumed_at`, `submitted_at`,
  `completed_at`, `elapsed_simulation_seconds`, generated scenario snapshot,
  completed task ids and draft JSON
- `wms_learner_actions` is the only scoreable behaviour stream; it enforces
  append ordering with `unique (attempt_id, sequence_number)` and rejects
  technical events through `check (is_technical = false)`
- `wms_attempt_audit_events` is the unscored lifecycle/analytics stream, also
  append-ordered per attempt
- `wms_attempt_results` and `wms_competency_evidence` store deterministic
  result/evidence payloads without claiming regulated certification authority
- All five WMS tables have RLS enabled, candidate ownership policies, indexed
  candidate/query paths and least-privilege authenticated grants after the
  grant-remediation migration
- This is a persistence foundation only: no Flutter repository adapter, BFF
  transaction endpoint, APK change, Career Passport governance or
  employer-facing evidence review was introduced in this slice

### WMS remote persistence validation
- Supabase migration history — verified on JobSkills; both WMS migrations are
  recorded
- Supabase catalog check — verified five `wms_*` public tables
- Supabase RLS check — verified RLS enabled on all five WMS tables
- Supabase policy check — verified candidate read/create/update policies for
  attempts and candidate read/append/create policies for action, audit, result
  and evidence tables
- Supabase grant check — initial broad grants were found and corrected; final
  authenticated privileges are limited to `select/insert/update` on attempts
  and `select/insert` on action, audit, result and evidence tables
- Supabase CLI is not installed in this environment, so migrations were
  created locally and applied through the Supabase connector rather than
  `supabase migration new` / `supabase db push`

### Wrong-supplier-delivery scenario — content-authored early completion
Shipped the one cleanly-scoped deferred scenario. Turned out to need more
than the original note suggested — this delivery's pedagogical intent
(`docs/24-receiving-department-content-specification.md`) is specifically
to be caught at delivery confirmation on Receiving Dock, *before* any
counting or inspection effort, not as a carton-inspection finding. That
meant fixing a real gap: `confirmShipmentIdentity` already captured the
candidate's true/false answer, but `submitReceivingCount` required
`shipmentConfirmed == true` just to proceed and then hardcoded the scored
outcome to "matches" regardless — there was no path for a candidate who
correctly said "no" to go anywhere except being permanently stuck.

Added, content-authored rather than special-cased in code:
- `MissionDefinition.earlyCompletionRules` (new, additive, empty by
  default) — a rule an mission can author to declare "if this task's
  action resolves this way, the mission ends here as a successful
  outcome," matched by `MissionScoringService` **before** its normal
  mandatory-task-completeness check, never touching how any other mission
  or scenario is scored. `receive_shipment_mission.json` authors exactly
  one: correctly rejecting the wrong-supplier delivery scores using only
  the categories/tasks touched before the terminal action (not penalised
  for the downstream work the mission never expected this branch to
  reach), and returns `status: passed`.
- `ReceivingCountDraft.shipmentConfirmed` is now `bool?` (`null` =
  undecided, distinct from an explicit `false` rejection — previously a
  plain `bool` couldn't tell "not yet acted" from "confirmed wrong").
- New controller method `rejectShipmentIdentity()`: records the real
  scored confirm-delivery-identity outcome, then submits the mission
  immediately.
- New critical error `accepted-wrong-supplier-delivery` (declarative, via
  the existing `criticalErrorRules` mechanism, no new code): accepting a
  wrong-supplier delivery and continuing is `criticalFailure` regardless
  of how the rest of the shift goes, per policy — correctly stopping bad
  work early is success; wrongly continuing past it is a critical process
  error.
- Receiving Dock's identity-confirmation UI replaced a single checkbox
  (which couldn't express "explicitly rejected") with two explicit
  buttons plus a distinct, confirmation-gated "Reject shipment & end
  shift" action, since one is now mission-ending and irreversible.

**Deliberately not attempted**: `multi-exception-shipment` and
`clerical-only-discrepancy` remain on hold — scoping surfaced they need
their own real design work (a stacked-issue carton needs
`RecordCartonInspectionCommand.finding` to become a list, not a single
value, since it's currently unreportable by the candidate even if
generated; a meaningfully distinct clerical-only scenario needs documents
to become scenario-swappable, which they aren't today, or it's just a
duplicate of `perfect-delivery`). Both explicitly deferred pending a
decision on whether the redesign is worth it, not silently dropped.

### Wrong-supplier-delivery — local validation
- `dart format .` — passed
- `flutter analyze --no-pub` — passed (same 7 pre-existing info-level
  hints, unrelated)
- Two new controller-level tests added to
  `workplace_simulation_controller_test.dart`, run against the real
  content/generator/scoring pipeline (not mocked): correctly rejecting
  ends the mission as `passed` with `mandatoryTasksCompleted: true` and
  none of the downstream tasks touched; wrongly accepting and continuing
  through `submitReceivingCount` + `completeMission` produces
  `criticalFailure` with `accepted-wrong-supplier-delivery` in
  `criticalErrors`
- Fixed 3 pre-existing scoring tests that hardcoded the old
  `matchesExpectedDelivery` wire value now that `confirm-delivery-identity`
  carries real points (10, up from 0) — normal-scenario weighted-score math
  is otherwise unchanged, confirmed by these same tests passing at their
  original expected values once the payload was corrected
- Focused WMS suite — 41/41 passed (39 previous + 2 new)
- Full suite — 98 of 101 passed; the three failures are the same
  pre-existing baseline flakes as every prior milestone, confirmed
  unrelated
- `flutter build apk --debug --no-pub --target-platform android-arm64` —
  succeeded locally

### WMS BFF sync boundary
- Added `POST /v1/workplace-simulation/attempts/:attemptId/sync` to
  `apps/api`
- The endpoint requires a verified candidate JWT and `Idempotency-Key`
  header, derives `candidate_id` from the authenticated session and rejects
  mismatched client-supplied candidate ids
- The BFF persists the already-produced controller state to the new `wms_*`
  tables: attempt lifecycle/timer/draft/scenario state, scoreable learner
  actions, unscored audit events, optional deterministic result and optional
  generated competency evidence
- `LearnerAction` remains the only scoreable behavioural stream; the service
  rejects `isTechnical: true` learner actions so technical/lifecycle events
  stay in `AttemptAuditEvent`
- Repeated sync requests are idempotent for existing action, audit and
  evidence ids; attempt and result aggregates are upserted by their stable
  keys
- This is a backend persistence boundary only: no Flutter repository adapter,
  no UI change, no scoring engine change, no DB schema change and no APK
  change were introduced in this slice
- Known temporary limitation: WMS sync is application-level ordered
  persistence rather than a single Postgres transaction/RPC wrapper

### WMS BFF sync validation
- `npm install` in `apps/api` — passed using the existing lockfile
- `npm test -- --runInBand workplace-simulation.service.spec.ts` — passed;
  4 focused tests cover full aggregate sync, idempotent repeated sync,
  technical-event rejection from learner actions and candidate-id mismatch
  rejection
- `npm run build` in `apps/api` — passed
- `npm run lint` in `apps/api` — passed

### Flutter WMS offline-first sync adapter
- Added an API-gated `OfflineFirstSimulationAttemptRepository` wrapper around
  the existing local WMS repository
- When `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` and `API_BASE_URL` are
  configured, WMS writes still persist locally first and then call
  `POST /v1/workplace-simulation/attempts/:attemptId/sync` with the verified
  Supabase access token
- If the BFF is offline, the user is unauthenticated, or the sync call fails,
  the local controller mutation still succeeds and an encrypted pending-sync
  snapshot remains queued for retry
- The pending snapshot stores the latest attempt aggregate and preserves an
  already-queued result/evidence payload across later attempt-only writes,
  matching the controller's submit flow (`saveResult` followed by final
  `saveAttempt`)
- The sync client maps BFF/network/auth failures into the existing
  `AppFailure` taxonomy and uses deterministic idempotency keys
- Default local development remains unchanged: without Supabase/API config, the
  app keeps using `LocalSimulationAttemptRepository` only
- Known limitation: the optional generated scenario snapshot is still not sent
  by Flutter because the current `SimulationAttemptRepository` contract does
  not carry a `GeneratedScenario`; syncing that snapshot requires a separate
  domain-contract widening slice

### Flutter WMS sync validation
- Added focused repository tests for local-first queueing, retry flush,
  result/evidence sync and preserving queued result payloads across later
  attempt-only writes
- Direct Dart formatter
  (`/opt/homebrew/share/flutter/bin/cache/dart-sdk/bin/dart format .`) —
  passed; 174 files checked
- Direct Dart analyzer
  (`/opt/homebrew/share/flutter/bin/cache/dart-sdk/bin/dart analyze`) —
  passed with the same 7 pre-existing info-level hints in `api_jobs_repository`
  and `workplace_simulation_controller`
- `flutter analyze --no-pub`,
  `flutter test --no-pub test/features/workplace_simulation/offline_first_attempt_repository_test.dart`
  and other Flutter wrapper commands are still blocked in this sandbox by the
  local Flutter SDK trying to write under
  `/opt/homebrew/share/flutter/bin/cache` (`Operation not permitted`)
- API regression check after this slice: `npm test -- --runInBand`,
  `npm run build` and `npm run lint` in `apps/api` all passed

### Multi-exception-shipment and clerical-only-discrepancy — the last two
### scenario-catalog entries
Both held entries are shipped, closing out the scenario-catalog work
started with `perfect-delivery` and `wrong-supplier-delivery`.

**`multi-exception-shipment`** needed the domain/UI change flagged when it
was deferred: a carton can now carry more than one finding.
- `CartonInspectionEntry.finding` (a single `CartonFinding`) is now
  `findings` (`List<CartonFinding>`), threaded through
  `RecordCartonInspectionCommand`/`UpdateCartonInspectionCommand`. The
  controller validates findings are non-empty, contain no duplicates, and
  never mix `compliant` with another finding
  (`invalidFindings` on both result enums).
- `submitInspection` fans out one scored `LearnerAction` per finding
  instead of one per carton, so a carton with two issues earns credit for
  both against the existing per-issue-type evaluation rules — no
  evaluation-rule changes needed, each fanned-out action is scored
  independently exactly like before.
- New `ScenarioVariationRule.allowStackedTarget` (additive, defaults
  false): lets a rule assign its issue to a resource an earlier rule this
  generation already claimed. Every rule authored before this field
  existed is unaffected — a resource still gets at most one issue unless a
  rule opts in.
- Inspection Zone's editor replaced the single-select finding dropdown
  with a checklist (compliant mutually exclusive with everything else).
- New scenario: carton-001 carries `packaging_damage` + `near_expiry`
  simultaneously, no other carton has an issue.

**`clerical-only-discrepancy`** shipped as the reporting-only distinction
explicitly chosen over the larger alternative (making PO/DN documents
scenario-swappable, which today they aren't — Document Desk reads them
from static mission JSON, and document-finding scoring runs against fixed
synthetic side-resources, not the PO/DN content itself). Same generated
content as `perfect-delivery` (empty variation rules), a separate
scenarioId so instructors/analytics can track and label runs assigned
under this framing. Documented as a deliberate tradeoff, not an oversight.

### Multi-exception and clerical-only — local validation
- `dart format .` — passed
- `flutter analyze --no-pub` — passed (same 7 pre-existing info-level
  hints, unrelated)
- New generator-level test: `multi-exception-shipment` assigns exactly two
  issues to carton-001 and nothing to any other resource
- New controller-level tests: a carton with two findings earns 7 correct
  `inspect-cartons` outcomes across 6 cartons (5 compliant + carton-001's
  2 findings), covering both feedback codes; recording an empty findings
  list or `compliant` mixed with another finding is rejected as
  `invalidFindings`
- Focused WMS suite — 44/44 passed (41 previous + 3 new)
- Full suite — 101 of 104 passed; the three failures are the same
  pre-existing baseline flakes as every prior milestone, confirmed
  unrelated
- `flutter build apk --debug --no-pub --target-platform android-arm64` —
  succeeded locally

### WMS pending-sync UI and generated-scenario snapshot sync
Closed both remaining items from the offline-sync slice.

**Pending-sync UI exposure.** `pendingSyncCount`/`flushPendingSyncs` existed
only on the concrete `OfflineFirstSimulationAttemptRepository`, unreachable
through the interface-typed provider without an unsafe cast. Added both to
the `SimulationAttemptRepository` interface itself — trivial for
`LocalSimulationAttemptRepository`/`InMemorySimulationAttemptRepository`
(`pendingSyncCount` always 0, `flushPendingSyncs` a no-op; there's no
remote to be behind), real logic unchanged in the offline-first
implementation. `WorkplaceSimulationState.pendingSyncCount` is refreshed on
controller `build()` and via a new `refreshPendingSyncStatus()` method; a
new `retryPendingSyncs()` flushes the queue then refreshes the count.
Workplace Overview shows a banner ("N updates waiting to sync" + Retry)
whenever the count is above zero, hidden entirely otherwise — invisible
when the app isn't built with Supabase/API dart-defines, since the count
is always 0 in that configuration.

**Generated-scenario snapshot sync.** The BFF's `WmsSyncRequest` already
had an unused `generatedScenario?` field wired straight to the
`wms_attempts.generated_scenario` column — nothing to change on the BFF.
The gap was entirely on the Flutter side: `_scenarioGenerator.generate()`
only ever landed in transient Riverpod state, never reached any repository
method. `SimulationAttemptRepository.createAttempt` gained an optional
`GeneratedScenario? generatedScenario` parameter (local repositories
accept and ignore it — they already regenerate deterministically from
`scenarioSeed`/`scenarioId`); `startMission()` now generates the scenario
*before* calling `createAttempt` and passes it through once, instead of
generating a second, redundant copy afterward purely for in-memory state.
`OfflineFirstSimulationAttemptRepository`'s snapshot model retains the
generated scenario across subsequent writes exactly like it already
retained `result` — captured once at creation, resent on every later sync
without the controller needing to pass it again.

### Pending-sync and scenario-snapshot — local validation
- `dart format .` — passed
- `flutter analyze --no-pub` — passed (same 7 pre-existing info-level
  hints, unrelated)
- New repository-level test: the generated-scenario snapshot queues while
  offline, retains across a later attempt-only write, and flushes to the
  remote client once connectivity recovers
- New controller-level test: `pendingSyncCount` reaches 1 after
  `startMission()` against a failing remote, `retryPendingSyncs()` drains
  it to 0 once the remote recovers, and the flushed sync call actually
  carried a `GeneratedScenario`
- Focused WMS suite — 50/50 passed (48 previous + 2 new)
- Full suite — 107 of 110 passed; the three failures are the same
  pre-existing baseline flakes as every prior milestone, confirmed
  unrelated
- `flutter build apk --debug --no-pub --target-platform android-arm64` —
  succeeded locally

### Real Jobs catalogue
Wired the Jobs feature to the real backend end to end. More of the backend
already existed than expected -- `GET /jobs` was already live against a
real, migrated `jobs` table; the gap was entirely on the Flutter side and
one missing BFF endpoint.

- `ApiJobsRepository.loadJobs()`/`readAppliedJobIds()` now call the real
  BFF instead of delegating to `LocalMockJobsRepository`. That delegation
  is gone entirely -- `ApiJobsRepository` no longer takes a `local`
  constructor param.
- New BFF endpoint `GET /jobs/applications` (`JobsController.
  myApplications`/`JobsService.listApplicationsForCandidate`), scoped to
  the authenticated candidate via the existing `CandidateAuthGuard` --
  there was previously no way to read a candidate's own applications back,
  only to create one.
- Found and fixed a real, previously-undetectable bug on the way: the
  Apply flow's "share this profile" checkbox never actually granted
  `employer_sharing` consent server-side, and the real `applyToJob`
  requires an active grant in `consent_grants` or it rejects with
  `CONSENT_REQUIRED`. This was invisible until now because mock job ids
  never matched the real `jobs` table, so a real apply call always failed
  for an unrelated reason first. `ApiJobsRepository.saveApplication` now
  upserts the consent grant directly against Supabase (mirroring
  `SupabaseCandidateOnboardingRepository`'s existing upsert pattern)
  immediately before the apply call it gates.
- `JobOpportunity.matchReason` renamed to `description` -- the real `jobs`
  table has no personalized "why this matched you" field, only a plain job
  description, so the field (and now the UI heading "About this role" in
  live mode) says what it actually holds instead of implying personalized
  matching that doesn't exist.
- `isSupervisorRole` (drives a real filter toggle) has no backing field in
  `jobs`/`role_profiles` either -- derived via a visible, testable
  title-keyword heuristic (`jobTitleLooksLikeSupervisorRole`: contains
  "supervisor"/"lead"/"manager"), not fabricated per-job data.
- `JobsRepository.isLiveData` (false for the mock fallback, true for the
  real one) drives the UI: "Demo opportunities" copy, "(Demo)" employer
  suffixes, and "mock feed" disclaimers only ever show when the app
  genuinely is running against the config-gated mock fallback (missing
  Supabase/API dart-defines) -- never alongside real data.

### Real Jobs catalogue — local validation
- `dart format .` / `flutter analyze --no-pub` (Flutter) — passed (same 6
  pre-existing info-level hints, unrelated)
- New unit tests for `jobTitleLooksLikeSupervisorRole` (case-insensitive
  match, individual-contributor titles correctly excluded)
- Full Flutter suite — 110 of 113 passed; the three failures are the same
  pre-existing baseline flakes as every prior milestone, confirmed
  unrelated
- `flutter build apk --debug --no-pub --target-platform android-arm64` —
  succeeded locally
- New BFF test: `listApplicationsForCandidate` scopes strictly to the
  requesting candidate
- `npm test -- --runInBand`, `npm run build`, `npm run lint` in `apps/api`
  — all passed (12/12 tests, including the new one)

### Next implementation
The still-unresolved "learning experience broken, not clear" report — the
user's device has been offline every time this was raised this session, so
it's never actually been seen.

## Career Passport v0.1 — candidate evidence governance
The first slice of ADR-0018 that actually surfaces evidence to a candidate,
scoped deliberately narrow: a governed view of WMS evidence in Profile, not
an employer-facing product.

- New `lib/features/career_passport/` feature. `EvidenceVerificationStatus`
  (in `workplace_simulation/domain/simulation_runtime.dart`, next to the WMS
  `EvidenceRecord` it labels) carries ADR-0018's exact provenance vocabulary
  -- `systemObserved`/`candidateReported`/`partnerAttested`/
  `issuerVerified`/`unverified`. `EvidenceGenerationService` now assigns
  `systemObserved` (WMS evidence is Flora's own deterministic simulation
  output) instead of the placeholder literal `system_verified_local` it used
  before this slice.
- Freshness is derived, never stored: `deriveCareerPassportEntries` (pure,
  unit-tested) groups evidence by competency, marks the newest record
  `active` (or `stale` past a 180-day window), and marks every older record
  for that competency `superseded` -- retakes accumulate and correct, they
  never overwrite or delete.
- Evidence source for v0.1: the candidate's current attempt result on each
  of the two known WMS missions (`receive-incoming-shipment-01`,
  `put-away-incoming-stock-01`), read through the existing
  `SimulationAttemptRepository` (`getActiveAttempt` + `getResult`) -- the
  same local-first/offline-synced path the missions themselves already use.
  Deliberately not a new BFF read endpoint or a direct
  `wms_competency_evidence` query: those become worth building once
  cross-attempt history (not just "your latest result") is an actual
  requirement.
- Visibility is a new, purpose-bound consent grant --
  `career_passport_sharing` -- distinct from the `employer_sharing` grant
  Jobs uses per application, reusing `consent_grants` (no schema change) and
  the Jobs feature's upsert pattern, plus a revoke path
  (`update ... set revoked_at = now()`) that no existing feature needed
  before this one. Private by default; local-only (unconfigured) builds
  render the toggle disabled with an explanatory subtitle instead of a
  broken one, since there is nowhere to record a grant.
- Profile now shows a "Career Passport" section (between "Readiness
  evidence" -- the unrelated legacy intelligence-quiz evidence stream, left
  untouched -- and "Privacy and consent") with the required disclaimer
  ("Flora provides simulation evidence, not certification."), a
  view-details sheet listing every entry with provenance/freshness/score
  chips, the shareable-with-employers toggle, and fixed "share with
  employer" boundary copy explaining that turning sharing on does not push
  anything anywhere -- there is no employer portal yet to receive it.
- All decisions stay human-owned: nothing in this slice ranks, scores, or
  certifies a candidate; freshness and provenance are informational labels,
  not gates.
- Explicitly out of scope, per direct instruction: employer portal,
  government/NCVET integration, AI scoring, credential/certificate issuing.

### Career Passport v0.1 — local validation
- `dart format .` / `flutter analyze --no-pub` (Flutter) — passed (same
  pre-existing info-level hints, unrelated)
- New unit tests: `deriveCareerPassportEntries` (active/superseded/stale
  across competencies, staleness window), `competencyDisplayName`, and
  `WmsCareerPassportRepository.loadEvidence` (completed-vs-in-progress
  attempts, both known missions) plus its local-only sharing branch
  (`canManageSharing` false, `setShareable` fails clearly without a
  Supabase client)
- Full Flutter suite — same three pre-existing baseline flakes as every
  prior milestone (confirmed by reproducing them against `main` before this
  change), no new failures
- `flutter build apk --debug --no-pub --target-platform android-arm64` —
  succeeded locally; installed on the connected Samsung device

## Career Passport evidence history
Closed the gap v0.1 documented and deliberately deferred: evidence now
accumulates across every attempt on a mission, not just the current one.

- `SimulationAttemptRepository` gained `listResults(candidateId, missionId)`
  -- every result ever saved for that candidate/mission, newest first.
  Implemented in all three conformers: `LocalSimulationAttemptRepository`
  (new append-only history index of attempt ids per candidate/mission,
  alongside the existing active/counter/result keys), its
  `InMemorySimulationAttemptRepository` delegate, and
  `OfflineFirstSimulationAttemptRepository` (delegates straight to local --
  this reads the current device's history only, not merged with whatever
  the BFF holds from other devices, which is documented on the method
  rather than silently assumed away).
- `WmsCareerPassportRepository.loadEvidence` now branches on configuration
  instead of always going through `SimulationAttemptRepository`: when
  Supabase is configured it reads the candidate's full
  `wms_competency_evidence` history directly (the `evidence` jsonb column
  already stores the original camelCase payload, so it parses straight
  through `EvidenceRecord.fromJson` with no column-mapping code) -- true
  cross-device, cross-attempt history, not just this device's. Local-only
  builds fall back to the new `listResults` path across both known
  missions.
- `deriveCareerPassportEntries` (from v0.1) needed no change -- it was
  already written to group and rank an arbitrary number of records per
  competency, so retake evidence now correctly resolves to one `active` (or
  `stale`) record per competency with the rest `superseded`, exactly as
  designed, once it started receiving more than one record per competency.

### Career Passport evidence history — local validation
- `dart format .` / `flutter analyze --no-pub` (Flutter) — passed (same
  pre-existing info-level hints, unrelated)
- New tests: `LocalSimulationAttemptRepository.listResults` (empty with no
  history, excludes un-scored attempts, returns retakes newest-first) and
  `WmsCareerPassportRepository` retake accumulation (two scored attempts on
  the same mission surface as two evidence records, not one)
- Full Flutter suite — 121 of 124 passed; the three failures are the same
  pre-existing baseline flakes as every prior milestone, confirmed
  unrelated
- `flutter build apk --debug --no-pub --target-platform android-arm64` —
  succeeded locally; installed on the connected Samsung device

## Employer Evidence Review MVP
The first employer-facing surface of any kind in this codebase, built
deliberately narrow: a read-only API, not an employer portal (no employer
login, no UI). No Flutter change was needed or made -- this is entirely
`apps/api`.

- **No employer identity existed anywhere** before this slice (`jobs.
  employer_name` was always a plain text label, nothing else). Resolved by
  asking the product owner rather than guessing: a new `public.employers`
  table (id, name, hashed API key, seeded out-of-band -- no signup/login
  flow) is the entire employer identity model for this MVP, enforced by a
  new `EmployerAuthGuard` mirroring `CandidateAuthGuard`'s shape (`Authorization:
  Bearer <key>`, hash-compared server-side, never trusts a client-supplied
  employer id).
- **Access rule**, per explicit product direction (application/employer-scoped,
  not a blanket global toggle): an employer may view a candidate's evidence
  only if that candidate has a non-`withdrawn` application to one of *this*
  employer's jobs (`jobs.employer_id`, new nullable FK, backfilled for the
  three existing seeded jobs) **and** both `employer_sharing` and
  `career_passport_sharing` consent are currently active. There is no
  browsing, no query across all "shareable" candidates, and no path from
  the API back to a candidate an employer hasn't been applied to by.
- **Audit**: every evidence read -- allowed or denied, and why -- is written
  to a new append-only `public.employer_evidence_access_log` before the
  response is returned; a failed audit write fails the request rather than
  silently disclosing evidence unaudited.
- **Governance parity, not duplication**: `deriveEvidenceFreshness` in
  `apps/api/src/employer/employer-evidence.ts` is a direct TypeScript port
  of the Flutter `deriveCareerPassportEntries` logic (same grouping/ranking
  rule, same 180-day staleness window) -- an employer and a candidate can
  never see a different freshness verdict on the same evidence. Every
  response carries the required disclaimer ("Flora provides simulation
  evidence, not certification.") and decision-boundary copy ("Employer
  reviews evidence and decides.") as data, not just UI copy, since there is
  no UI. Evidence is always returned newest-first -- no score-based
  ranking, no shortlist field, no "certified" language anywhere in the
  response shape.
- Two new routes, both behind `EmployerAuthGuard`: `GET /employer/applicants`
  (roster of this employer's own non-withdrawn applicants, no evidence, not
  audited) and `GET /employer/applicants/{candidateId}/evidence` (the gated,
  audited evidence read). See `docs/03-api-specifications.md`.
- Explicitly out of scope, per direct instruction: employer portal UI,
  automated rejection, any scoring change, government/NCVET integration.

### Employer Evidence Review MVP — local validation
- `npm test -- --runInBand`, `npm run build`, `npm run lint` in `apps/api`
  — all passed (22/22 tests, including 10 new: 4 `deriveEvidenceFreshness`
  parity tests and 6 `EmployerService` access-rule/audit tests)
- No Flutter changes in this slice, so no APK build/install was needed or
  performed

### Migration applied to JobSkills (2026-08-01)
`supabase/migrations/20260801100000_employer_evidence_review_mvp.sql` was
initially left unapplied: the Supabase MCP connector available in the
authoring session only had access to an unrelated project (`nutridiet`,
`rspyrkcdzariizvqookp`), not `JobSkills` (`qoairksjpwkhwqxeollj`) that WMS,
Jobs and Career Passport actually run on, so applying it there would have
hit the wrong project entirely. It was applied out-of-band instead, and
confirmed live:

- Migration history on `JobSkills` shows both
  `20260801044049_employer_evidence_review_mvp` and a follow-up
  `20260801044629_employer_evidence_review_mvp_advisor_remediation`
  (revoked stray anon/authenticated grants on the two new employer-only
  tables; added a missing FK index on
  `employer_evidence_access_log.job_id`).
- Verified live: `public.employers` (3 seeded rows), `public.jobs.employer_id`
  backfilled on all 3 existing seeded jobs, `public.employer_evidence_access_log`
  created, RLS enabled on both new tables with zero client-facing grants
  (intentional -- both are BFF/service-role only).
- Remaining Supabase advisor notices (RLS-enabled-no-policy on the two
  employer tables; other pre-existing unused-index warnings) are expected
  for this slice's design, not new issues.
- Not independently re-verified by the authoring session itself (its own
  Supabase MCP connector still only reaches `nutridiet`) -- taken on a
  direct report from whoever applied it. `EmployerAuthGuard` and the two
  employer routes should now work end-to-end against `JobSkills`.

## Employer Evidence Review E2E validation + minimal internal QC surface
Closes the loop on the Employer Evidence Review MVP: a real (not mocked)
end-to-end test suite, a manual QC page, and candidate-side copy that
matches what the API actually enforces.

- **New `apps/api/test/employer-evidence-review.e2e-spec.ts`** -- boots the
  real `AppModule` with `@nestjs/testing` + `supertest`, and seeds/tears
  down its own throwaway employers, jobs, a candidate and consent/evidence
  rows directly against whatever `SUPABASE_URL`/`SUPABASE_SERVICE_ROLE_KEY`
  point at, no mocks. Covers: an employer key lists only that employer's
  own applicants; evidence is returned (with disclaimer, decision
  boundary, freshness labels, and no ranking/shortlist/certified fields)
  only when the candidate applied to that employer's job **and** both
  `employer_sharing` and `career_passport_sharing` consent are active;
  denial is audited with the correct reason (`NO_ACTIVE_APPLICATION` /
  `SHARING_NOT_ACTIVE`); one employer can never read another's applicant's
  evidence. New `npm run test:e2e` script and `test/jest-e2e.json`.
  **Not runnable from the authoring session** -- same Supabase-project
  access gap as the migration above (only `nutridiet` is reachable here).
  It compiles clean and correctly `describe.skip`s (not "passes") without
  live credentials; running it for real against `JobSkills` is the
  verification step this milestone still needs from whoever has that
  access.
- **`GET /v1/dev/employer-review`** -- a single self-contained, dependency-free
  HTML/JS page (`apps/api/src/dev/employer-review-harness.html`) for manual
  QC: employer API key input, applicant list, evidence detail as both
  rendered cards and raw JSON, disclaimer and decision-boundary text shown
  prominently, clearly labelled "not the employer portal." Served
  same-origin (default API base `/v1`) so no CORS configuration was
  needed. Hard-gated: 404s whenever `NODE_ENV=production`, verified in the
  browser against the real compiled route (not just reasoned about).
  Fixed a real, pre-existing build gap while wiring this up: this repo had
  no `tsconfig.build.json`, so `nest build` was silently compiling `test/`
  files into the production `dist/` output and mis-inferring `rootDir`,
  which put compiled controllers one directory level away from their
  copied static assets. Added the standard Nest CLI `tsconfig.build.json`
  (excludes `test`, matches the framework's own scaffold) -- fixes the
  asset path and, as a side effect, stops shipping test code in the build.
- **Candidate-side sharing copy, `career_passport_section.dart`**: the
  toggle is now labelled "Shared with employers where you applied" (not
  the old generic "Shareable with employers"), with on/off subtitles that
  state the real rule as fact -- "Employers you've applied to can review
  your Career Passport evidence for that application... Turn this off any
  time to immediately stop new access" / "Employers cannot see your Career
  Passport evidence, even for jobs you've applied to." The details-sheet
  boundary copy and human-decision line were tightened to match the
  employer-side wording ("the employer reviews your evidence and
  decides"). Also removed the old decorative "Employer profile visibility"
  switch from Profile's "Privacy and consent" section (`profile_screen.
  dart`) -- it was never wired to anything and, now that a real toggle
  exists in the Career Passport section, having two employer-visibility-ish
  switches on the same screen was actively confusing, not just redundant.
  Replaced with a plain pointer row.

### This milestone -- local validation
- `dart format .` / `flutter analyze --no-pub` -- passed (same
  pre-existing info-level hints, unrelated)
- `npm run build` / `npm run lint` / `npm test -- --runInBand` in
  `apps/api` -- all passed (22/22 unit tests, unchanged)
- `npm run test:e2e` -- compiles and correctly skips (7 skipped, not
  passed) without live Supabase credentials; not executed against
  `JobSkills` from this session, see above
- Manually verified the dev harness renders correctly and its error path
  works end-to-end (harness -> fetch -> `EmployerAuthGuard` -> Supabase ->
  `AppExceptionFilter` -> error surfaced in the page) against a locally
  running server with placeholder Supabase credentials; the happy-path
  rendering (applicant rows, evidence cards) was not exercised against
  real data for the same access-gap reason
- Removing the profile screen's dead switch shifted page layout enough to
  break two existing widget tests that scrolled by a fixed pixel delta
  instead of calling `ensureVisible` before tapping
  (`phase_one_shells_test.dart`); fixed by adding `ensureVisible` calls,
  confirmed against a clean `main` baseline first to be sure it was a real
  regression and not a pre-existing flake
- Full Flutter suite -- 121 of 124 passed; the three failures are the same
  pre-existing baseline flakes as every prior milestone, confirmed
  unrelated
- `flutter build apk --debug --no-pub --target-platform android-arm64` --
  succeeded locally; **not yet installed** -- no device was connected to
  this machine when this milestone finished

## WMS Barcode Station -- a real dedicated workstation
First slice of the "WMS remaining gameplay depth" phase. Closes a gap the
content itself already flagged: `workplace.json` has defined a full
`barcode-station` workstation (map position, unlock chain requiring
`inspect-cartons`, `quarantine-zone` in turn requiring `scan-barcodes`)
since the Receiving department was built, but no mission stage or screen
ever pointed at it -- `docs/24-receiving-department-content-specification.md`
explicitly flagged this as an open decision for the runtime team. Chose to
build it as a real, separately-gated station rather than merge the orphan
workstation away.

- **Content**: `scan-barcodes` moved out of Inspection Zone's
  `physical-inspection` stage into a new `barcode-scan` stage
  (`workstationId: barcode-station`) in `receive_shipment_mission.json`.
  The task itself, its target cartons and its evaluation rules are
  unchanged -- only which stage/screen owns it moved, so existing scoring
  for correctly recording readable/unreadable barcodes is untouched.
- **Draft model split**: `barcodeScans` moved out of `InspectionDraft` into
  a new dedicated `BarcodeScanDraft` (mirroring the existing
  one-draft-per-workstation pattern already used for
  `DispositionDraft`/`ReceivingCountDraft`/etc.), with its own
  `SimulationAttempt.barcodeScanDraft` field and its own
  save/submit commands (`SaveBarcodeScanDraftCommand`/
  `SubmitBarcodeScanCommand`). This was the load-bearing decision: genuine
  sequential gating (finish Inspection -> unlock Barcode Station -> finish
  scanning -> unlock Quarantine) requires two independent submit actions,
  not one shared draft submitted once for both. `submitInspection` no
  longer scores or requires scans; a new `submitBarcodeScan` scores them
  on its own, called from the new screen.
- **Richer interaction, not just relocation**: `BarcodeScanEntry` gained
  `scanAttempts`, `resolutionMethod` (`scanned`/`manualEntry`/`flagged`)
  and an optional `manualCode`. A scan's readable/unreadable outcome is now
  deterministic from the scenario's own `unreadable_barcode` issue data
  (a real scanner is a mechanical device, not a judgment call) rather than
  a free-choice dropdown; what's actually assessed is how the candidate
  *responds* to a failed scan -- retry (capped at 2 extra attempts, since a
  physically damaged label doesn't fix itself), manual code entry, or
  flagging for verification. Scoring itself is unchanged (still keyed on
  final `barcodeStatus`, matching the existing "unreadable barcodes require
  hold or escalation" workplace rule) -- the new fields are audit-trail
  richness for this slice, not new scoring surface.
- New route `GET /practise/workplace-simulation/:missionId/barcode-station`,
  new `BarcodeStationScreen`, new `AttemptAuditEventType` values
  (`barcodeStationOpened`/`Exited`, `barcodeScanSubmissionRequested`,
  `barcodeScansSaved`/`SaveFailed`, `barcodeScanDraftSaved`) for audit-trail
  parity with every other WMS screen.

### WMS Barcode Station -- local validation
- `dart format .` / `flutter analyze --no-pub` -- passed (same
  pre-existing info-level hints, unrelated)
- Updated `content_and_scenario_test.dart` (mission now has 8 stages, not
  7) and `workplace_simulation_controller_test.dart` (the existing
  full-mission-playthrough test now drives `submitBarcodeScan` as its own
  step and asserts `barcode-station` reaches `WorkstationStatus.completed`
  independently of `inspection-zone` and `quarantine-zone`); added a
  locked-state render check for `BarcodeStationScreen` to
  `workplace_operational_screens_test.dart`, mirroring the existing
  Inspection Zone / Quarantine Zone checks
- Full Flutter suite -- 121 of 124 passed; the three failures are the same
  pre-existing baseline flakes as every prior milestone, confirmed
  unrelated
- `flutter build apk --debug --no-pub --target-platform android-arm64` --
  succeeded locally; installed on the connected Samsung device
- Not covered: a widget-level test that actually taps through the new scan
  dialog's retry/manual-entry/flag branches. The original dropdown-based
  scan editor this replaces was never widget-tested either (only
  exercised via direct controller calls in
  `workplace_simulation_controller_test.dart`, which is what now covers
  the new flow's scoring-relevant behaviour) -- matching that precedent
  rather than a gap specific to this change, but noted plainly rather than
  left implicit.

## WMS Quarantine supervisor-approval release step
Second slice of "WMS remaining gameplay depth." Quarantine already had a
complete disposition/reason/confirm-separation flow; the one gap the
content itself flagged as intentionally deferred was releasing held stock
back to available inventory, per `workplace.json`'s own escalation-path
rule: an associate may quarantine or hold stock on their own judgment, but
release requires supervisor sign-off. Added exactly that step, kept inside
the existing Quarantine Zone screen rather than a new station.

- **New task `request-quarantine-release`** (stage `exception-handling`,
  third task alongside `assign-dispositions`/`confirm-quarantine`, same
  screen). For every carton disposed as `quarantine` or
  `holdForVerification`, the candidate recommends a `ReleaseDecision`
  (`releaseToStock`/`continueHold`/`returnToSupplier`/`disposeOnSite`) with
  a required justification -- modelled as a request for supervisor
  approval, not a unilateral action. New `QuarantineReleaseDraft`/
  `QuarantineReleaseEntry` (mirroring `DispositionDraft`'s shape) and
  `recordReleaseDecision`/`submitQuarantineRelease` commands.
- **A real architectural snag, not a corner cut**: this task's true target
  set (which cartons need a release decision) is dynamic -- it depends on
  the disposition draft, which varies by scenario -- while
  `MissionProgressService`'s shared repeatable-task completion check
  requires every one of the task's static `targetResourceIds` to have a
  recorded action. Rather than changing that shared, widely-used service,
  `submitQuarantineRelease` auto-records a system-only
  `ReleaseDecision.notApplicable` action (never a candidate choice, never
  shown as an option) for cartons that were never quarantined or held, so
  the mission's progress tracking stays consistent for every task without
  asking the candidate to "recommend" something for stock that was never
  on hold. Scored too: 3 new evaluation rules reward correctly recognizing
  that rejected/escalated/accepted stock needs no release decision at all
  (mirroring `inspect-cartons`'s existing compliant-carton rule), so
  `maximumPoints` for this task is 30 (6 cartons x 5), not 15.
- **Correct-answer basis**: `packaging_damage` -> return to supplier;
  `unreadable_barcode` / `quantity_shortage` -> continue hold. No scenario
  currently authors a genuinely release-eligible item -- deliberately: it
  reinforces the mission's own stated rules ("Damaged goods cannot enter
  available inventory," "Unverified goods must remain on hold").
  `release_to_stock`/`dispose_on_site` exist as real, selectable options
  and are scored as incorrect for every currently-authored issue, not
  removed -- future scenarios can introduce a genuinely release-eligible
  case without further runtime changes.
- New critical error `release-damaged-stock`: recommending `release to
  stock` for damaged goods is a 20-point, pass-preventing critical error,
  mirroring `accept-damaged-stock`'s existing severity for the same
  underlying policy violation at an earlier stage.
- Receiving Office's unlock requirement moved from `assign-dispositions`
  to `request-quarantine-release` -- it was already the more accurate gate
  in intent (the office screen's own copy already said dispositions must
  be settled first); now the map matches the real flow.

### WMS Quarantine release -- local validation
- `dart format .` / `flutter analyze --no-pub` -- passed (same
  pre-existing info-level hints, unrelated, plus one new one in the same
  pre-existing style at `workplace_simulation_controller.dart:2606`)
- Updated `evaluation_and_scoring_test.dart`'s synthetic "perfect run"
  helper to include the new task (a real architectural signal worth
  noting: without it, `MissionScoringService` computes each category's
  *available* points from the mission's task definitions regardless of
  whether an outcome was ever recorded, so a missing task silently drags
  every numeric score down -- this surfaced as four failing exact-score
  assertions before the helper was fixed, not primarily as new-behavior
  bugs)
- Updated `content_and_scenario_test.dart` (14 tasks now, not 13),
  `workplace_simulation_controller_test.dart` (playthrough now drives
  `submitQuarantineRelease`, asserts `quarantine-zone` completes only
  after it) and `supervisor_dialogue_acknowledgement_test.dart` (its
  scripted playthrough needed the same new step to keep reaching
  Receiving Office)
- Full Flutter suite -- 121 of 124 passed; the three failures are the same
  pre-existing baseline flakes as every prior milestone, confirmed
  unrelated
- `flutter build apk --debug --no-pub --target-platform android-arm64` --
  succeeded locally; **not yet installed** -- no device was connected to
  this machine when this milestone finished
- Not covered: a widget-level test tapping through the new release-decision
  dialog, matching the same precedent noted for Barcode Station's scan
  dialog (screen-level dialog interactions in this mission are exercised
  via controller calls in `workplace_simulation_controller_test.dart`, not
  widget taps, for every existing screen too)

## Target product architecture proposal

- Added the proposed Flora AI Employability Infrastructure architecture in
  `docs/23-ai-employability-infrastructure-platform.md`
- Repositioned Workplace Management Simulation as the Simulation bounded
  context within the wider candidate lifecycle without changing its approved
  controller, action, audit, timing or scoring boundaries
- Defined target Career, Candidate, Discovery, Learning, Simulation,
  Competency, Employment, Placement, Partner, Integration and Trust contexts
- Defined authority boundaries so Flora complements rather than duplicates
  training providers, assessment agencies, SSCs, NSDC/NCVET, NCS, Skill India
  Digital Hub, Apprenticeship India and State Skill Missions
- Added phased product gates from WMS through discovery, competency passport,
  employer/placement operations, controlled government integrations and
  lifecycle-aware AI
- Added ADR-0016 making Flutter the authoritative Candidate App platform and
  corrected all legacy mobile-stack documentation references
- This is documentation and planning only. No new employability-platform code,
  integration, portal or production authority has been added

## Known constraints
- Android/Termux/Ubuntu PRoot environment cannot reliably run Android SDK host binaries
- GitHub Actions is the authoritative APK build path for mobile-only development
- The generic `app-debug.apk` artifact filename can be confused with stale
  downloads until GitHub workflow-write permission is available
- macOS will be required for iOS build and signing
- External analytics and connectivity adapters remain local mocks. Supabase
  authentication and candidate-owned data adapters are available only in a
  build configured with the JobSkills URL and publishable key.
- The component gallery is a development aid and is intentionally unavailable
  in production configuration
- Selected language still uses the Phase 1 in-memory adapter and persists
  through navigation; authenticated session state uses secure device storage
- Development OTP `123456` is intentionally local and must never be treated as
  production authentication
- Candidate onboarding drafts remain available locally; profiles and consent
  can synchronize to JobSkills when the Supabase build configuration is
  supplied
- Resume upload and onboarding voice introduction remain non-interactive
  placeholders; voice interview practice is the only route that requests
  microphone permission
- Home, Coach, and Jobs remain local mock experiences. Diagnostic, learning,
  simulation, score, and evidence records use local-first persistence and can
  synchronize to candidate-owned JobSkills records when configured.
- Coach voice/attachment controls and notifications remain transparent
  placeholders; the voice interview uses local capture but no AI provider,
  remote upload, push token, or notification service is connected
- The direct Supabase adapter is intentionally limited to candidate-owned
  Phase 2 records and narrowly scoped Phase 3 practice metadata; media
  authorisation, AI, employer and administrator operations remain behind the
  BFF, which now exists (`apps/api`) and implements candidate job application
  submission plus the WMS attempt sync boundary. The Flutter Jobs feature's
  Apply action calls the Jobs endpoint when both Supabase and API
  configuration are present; job listing itself still comes from
  `LocalMockJobsRepository`, whose mock ids don't match the real seeded jobs
  yet. The Flutter WMS runtime calls the WMS sync endpoint only in builds that
  provide both Supabase and API configuration; otherwise it remains purely
  local.
- The Receiving mission is complete end to end (Document Desk through
  Performance Feedback) and the Put Away mission is complete end to end
  (Staging Area through Performance Feedback), both merged to `main`. WMS
  now has a live Supabase persistence schema, a BFF sync endpoint and an
  API-gated Flutter offline-first sync adapter. No WMS screen is withheld
  pending approval; the WebGL/3D
  spatial interaction layer remains deliberately deferred per direct
  discussion with the product owner rather than a specific ADR (see the Put
  Away workstation screens entry above for the correction to a stale
  "ADR-001" citation).
