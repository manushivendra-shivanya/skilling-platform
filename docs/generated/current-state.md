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
- Approved WMS Screens 01–05 are available from Practice, with controller-owned
  progression through entry, briefing, overview, document review and receiving
  count; Screen 06 is an intentional Inspection Zone handoff placeholder

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

### Next implementation
Implement the approved Screen 06 Inspection Zone interaction contract as the
next coherent WMS milestone. Do not infer Barcode Station, Quarantine Zone,
Receiving Office, final decision, report or results behaviour.

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
  authorisation, AI, employer, administrator and job-application operations
  remain behind the planned NestJS BFF
- WMS Screens 01–05 are production-visible. Screen 06 remains a placeholder;
  Barcode Station, Quarantine Zone, Receiving Office, final decision, shift
  report and results are intentionally unavailable pending approved contracts.
