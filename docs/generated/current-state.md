# Current Repository State

Last updated: 2026-07-27

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
- No production authentication, backend profile sync, resume upload, or voice
  recording yet

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
Phase 1.6 main navigation complete. Local validation and the authoritative
GitHub Actions Android APK build pass for source commit `ecff5ad`. Device QC is
pending.

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

### Next implementation
After Phase 1.6 APK QC, implement Phase 1.7 from
docs/20-codex-phase-execution.md: mock-backed Home dashboard with loading,
empty, error, populated, refresh, accessibility, analytics, and pending-sync
states.

## Known constraints
- Android/Termux/Ubuntu PRoot environment cannot reliably run Android SDK host binaries
- GitHub Actions is the authoritative APK build path for mobile-only development
- The generic `app-debug.apk` artifact filename can be confused with stale
  downloads until GitHub workflow-write permission is available
- macOS will be required for iOS build and signing
- No external analytics, connectivity, authentication, or storage provider is
  connected in Phase 1.1; the included adapters are intentionally local mocks
- The component gallery is a development aid and is intentionally unavailable
  in production configuration
- Selected language still uses the Phase 1 in-memory adapter and persists
  through navigation; authenticated session state uses secure device storage
- Development OTP `123456` is intentionally local and must never be treated as
  production authentication
- Candidate onboarding drafts and consent records are device-local Phase 1
  data; server-side profile/consent persistence and cross-device sync remain
  Phase 2 work
- Resume upload and voice introduction are non-interactive placeholders; no
  storage or microphone permission is requested
- Phase 1.6 tab destinations intentionally contain only transparent previews;
  their product content is scheduled for Phases 1.7–1.12
- The AI Coach and notifications routes are non-interactive placeholders; no
  AI provider, microphone, upload, push token, or notification service is used
