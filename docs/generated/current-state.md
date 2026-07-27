# Current Repository State

Last updated: 2026-07-27

## Status

### Built and manually verified
- Flutter candidate application scaffold
- Android debug APK GitHub Actions workflow
- Android APK installation on Samsung S24 Ultra
- Application launch without crash

### Current UI
- Default Flutter counter application
- No production candidate flows implemented yet

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
Installable APK foundation complete.

### Next implementation
Phase 1 from docs/20-codex-phase-execution.md:
- Remove Flutter demo
- Add production architecture
- Add theme and design system
- Add GoRouter and Riverpod
- Add onboarding and main navigation shells
- Add mock repositories
- Preserve GitHub Actions build

## Known constraints
- Android/Termux/Ubuntu PRoot environment cannot reliably run Android SDK host binaries
- GitHub Actions is the authoritative APK build path for mobile-only development
- macOS will be required for iOS build and signing
