# Current Repository State

Last updated: 2026-07-28

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
feature/flutter-foundation

### Latest verified milestone
The additive Workplace Management Simulation backbone and approved Screens
01–05 are connected. Screen 06 proves the Inspection Zone unlock and route
boundary without implementing inspection behaviour.

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

### Jobs — Apply wired to the real BFF endpoint; job-applications migration still not applied
Attempted to apply `20260729180000_phase_three_job_applications.sql` to the
real project (`qoairksjpwkhwqxeollj`) as the prior milestone's "next
implementation" called for. It is still not applied: the connected Supabase
MCP server (`Supabase`) reached the account fine — `list_projects` succeeded
— but both `get_project` and `list_tables` for `qoairksjpwkhwqxeollj`
returned "You do not have permission to perform this action", and
`list_projects` lists only the unrelated `nutridiet` project
(`rspyrkcdzariizvqookp`), exactly as the prior milestone documented. A
second, separate `supabase` (lowercase) MCP server is also present but
requires an interactive OAuth authorization this non-interactive session
cannot perform. No migration was applied and no live-database verification
(tables, RLS, seeded jobs) was possible this milestone.

That blocker does not gate the client side, so this milestone wired
apps/candidate-mobile's Jobs "Apply" action to the real
`POST /v1/jobs/:id/applications` endpoint, intentionally leaving job listing
on mock data:
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

### Next implementation
Get the Supabase MCP connection actually project-scoped to
`qoairksjpwkhwqxeollj` (an admin action outside this repository/session, not
another authentication attempt from here), apply the job-applications
migration, and verify `jobs`/`job_applications` exist with RLS enabled and
the three seeded jobs present. Then decide how the Flutter Jobs feature gets
a real job catalogue — either wire `loadJobs()` to `GET /v1/jobs` too, or
seed/align mock ids with real ones — so the now-wired Apply action has real
jobs to apply to end to end. Separately, still open: deepen Receiving's
content per the backlog in
`docs/24-receiving-department-content-specification.md`; apply the same
reusable-architecture pass to Receiving's ~15 bespoke draft/submit
controller methods now that both Put Away and the BFF slice prove the
simpler generic pattern; and the doc 23 bounded-context merge remains
explicitly deferred pending its own 5 approval gates, separate from BFF/Jobs
work.

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
  BFF, which now exists (`apps/api`) but implements only one endpoint
  (`POST /v1/jobs/{id}/applications`) — not yet applied to a live database,
  and the Flutter Jobs feature still calls `LocalMockJobsRepository`, not
  this endpoint
- The Receiving mission is complete end to end (Document Desk through
  Performance Feedback) and the Put Away mission is complete end to end
  (Staging Area through Performance Feedback), both merged to `main`. No WMS
  screen is withheld pending approval; the WebGL/3D spatial interaction
  layer remains the only deliberately deferred WMS scope, per direct
  discussion with the product owner rather than a specific ADR (see the Put
  Away workstation screens entry above for the correction to a stale
  "ADR-001" citation).
