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
- No production authentication or candidate data flow yet

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
Phase 1.4 development authentication complete. Local validation and the
authoritative GitHub Actions Android APK build pass for source commit
`db4ec52`.

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

### Next implementation
After Phase 1.4 APK QC, implement Phase 1.5 from
docs/20-codex-phase-execution.md: resumable candidate onboarding, profile
drafts, versioned consent, preferred roles, and offline visibility.

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
