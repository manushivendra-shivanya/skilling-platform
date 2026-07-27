# Current Repository State

Last updated: 2026-07-27

## Status

### Built and manually verified
- Flutter candidate application scaffold
- Android debug APK GitHub Actions workflow
- Android APK installation on Samsung S24 Ultra
- Application launch without crash

### Current UI
- Phase 1.1 application foundation replaces the default Flutter counter demo
- Router-backed startup screen with loading, recoverable error, retry, and
  low-data-mode representations
- No candidate onboarding, authentication, or production data flow yet

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
Installable APK foundation complete. Phase 1.1 source validation is complete;
the authoritative GitHub Actions APK validation is pending for this commit.

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

### Next implementation
After the GitHub Actions APK build passes, Phase 1.2 from
docs/20-codex-phase-execution.md should build the reusable design system and
development component gallery. Phase 1.1 now provides:
- application bootstrap with environment configuration and safe error logging
- Riverpod dependency composition and GoRouter startup route
- feature-first launch module with a mock startup repository
- typed `Result` and `AppFailure` models
- local mock adapters for analytics, connectivity, storage, and sessions
- an accessible framework error boundary and startup retry state

## Known constraints
- Android/Termux/Ubuntu PRoot environment cannot reliably run Android SDK host binaries
- GitHub Actions is the authoritative APK build path for mobile-only development
- macOS will be required for iOS build and signing
- No external analytics, connectivity, authentication, or storage provider is
  connected in Phase 1.1; the included adapters are intentionally local mocks
