# AGENTS.md — Codex Operating Contract

## Product mission
Build an AI-native employment and skilling platform for India's operational and grey-collar workforce.

Initial pilot:
- Warehouse Operations Associate
- Inventory Executive
- Dispatch Executive
- Hub Supervisor
- Shift Supervisor

## Mandatory reading before coding
1. README.md
2. docs/00-master-plan.md
3. docs/01-system-architecture.md
4. docs/09-candidate-mobile-app.md
5. docs/12-engineering-handbook.md
6. docs/16-sprint-plan.md
7. docs/19-codex-master-context.md
8. docs/20-codex-phase-execution.md
9. docs/generated/current-state.md

**Additionally, before touching any candidate-facing screen (new or
redesigned):**
10. docs/04-ui-ux-specification.md — the single, authoritative UI design
    document: screen inventory *and* the award-grade visual language
    established by the Home and Voice Interview redesigns, as a checklist,
    not inspiration. A screen that doesn't hold up against every item in
    Part 2's checklist is not done, the same way a screen with a failing
    test is not done. This is deliberately the *only* UI guideline document
    — when a design pass finds a reusable pattern, or a new `/deep-research`
    round produces conclusions worth keeping, fold them into this file
    rather than starting a new one or leaving them in a downloaded document
    or a chat transcript, none of which survive a session boundary.

Inspect the repository before assuming any file, package, API, route or feature exists.

## Locked stack
- Candidate mobile app: Flutter and Dart
- State management: Riverpod
- Navigation: GoRouter
- Web: Next.js
- API: NestJS
- AI services: Python
- Database, auth and storage: Supabase
- Cache and queues: Redis
- Web deployment: Vercel
- Android APK builds: GitHub Actions

Do not replace this stack without an approved architecture decision record.

## Current mobile state
- Flutter app path: apps/candidate-mobile
- Android debug APK builds successfully through GitHub Actions
- APK installs and opens successfully
- Current UI is still the default Flutter counter application
- compileSdk = 36
- targetSdk = 36
- Java 17
- Gradle 9.1.0
- Android Gradle Plugin 9.0.1
- Kotlin 2.3.20
- Do not add the unused jni dependency

## Product principles
- Mobile-first
- Low-bandwidth
- Hindi and Hinglish first
- Voice-first where useful
- Practical evidence over passive learning
- Explainable scoring
- Explicit consent
- Human review for consequential AI decisions
- Never score accent, emotion, appearance, caste, religion or inferred personality
- Technical failures must not reduce candidate reliability
- No automated rejection solely from an AI score
- Keep all infrastructure, data and secrets separate from ZHealth

## Engineering rules
- Use feature-first architecture
- Preserve the working build pipeline
- Do not expose secrets in client code
- Add loading, error, empty, retry and offline states
- Add accessibility labels
- Add relevant analytics events
- Add tests for new logic and screens
- Update documentation after every coding session
- Update docs/generated/block-diagram.md whenever architecture changes
- Update docs/generated/current-state.md before ending every session

## Required validation
From apps/candidate-mobile:

flutter pub get
dart format .
flutter analyze
flutter test
flutter build apk --debug

From repository root:

git status
git diff --check

## Definition of done
A task is complete only when:
- Acceptance criteria are met
- Tests pass
- Target app builds
- Documentation is updated
- No secrets or sensitive data are introduced
- Changed files and validation results are reported
