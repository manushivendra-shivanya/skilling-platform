# ADR-0016: Flutter Candidate Mobile Boundary

- Status: Accepted
- Date: 2026-07-28
- Owners: Product Engineering

## Context

The approved master context and the production candidate application use
Flutter, Dart, Riverpod, GoRouter and Material 3. Some older planning documents
still described the candidate client as a different mobile stack. That
documentation drift created ambiguity and risked replacing a working Android
pipeline.

## Decision

Flutter is the authoritative cross-platform technology for the Flora Candidate
App.

- Android remains the first operational target.
- iOS will use the same Flutter codebase when enabled.
- Candidate features follow feature-first architecture.
- Riverpod owns application state and dependency injection.
- GoRouter owns navigation.
- Platform-specific functionality is isolated behind stable Dart interfaces.
- The existing GitHub Actions Android pipeline must be preserved.
- A mobile-platform replacement requires a superseding ADR and an approved
  migration plan; it cannot occur as an incidental feature change.

Next.js remains the approved web boundary for employer, partner, government,
administration, analytics and studio applications.

## Alternatives Considered

- Rebuild the candidate application in another cross-platform framework:
  rejected because it discards validated code, tests and Android build work
  without a product benefit.
- Maintain two candidate mobile implementations: rejected because it doubles
  delivery, security, accessibility and quality-assurance cost.

## Consequences

- Existing Flutter architecture and tests remain investments, not prototypes.
- Shared contracts and design tokens must be platform-neutral rather than
  sharing web UI implementation code.
- Native Android/iOS work is permitted only at explicit plugin or platform
  boundaries.
- New architecture documents must name Flutter consistently.

## Security/Privacy Impact

Secure storage, permissions, media capture and offline queues remain behind
auditable Flutter repository interfaces. Platform plugins require security and
privacy review before production use.

## Migration/Rollback

No code migration is required. This ADR corrects documentation to match the
approved and implemented architecture. Rollback requires a superseding ADR.

## References

- `docs/09-candidate-mobile-app.md`
- `docs/20-codex-phase-execution.md`
