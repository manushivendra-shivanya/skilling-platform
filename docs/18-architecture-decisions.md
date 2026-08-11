# 18 — Architecture Decision Records

Create one file per decision under `docs/adr/` using `NNNN-title.md`.

## ADR Template
```markdown
# ADR-NNNN: Title

- Status: Proposed | Accepted | Superseded | Rejected
- Date:
- Owners:

## Context
## Decision
## Alternatives Considered
## Consequences
## Security/Privacy Impact
## Migration/Rollback
## References
```

## Initial Decisions — Status

This list was originally a mandate for twelve ADRs before any of them were
written; none of the twelve ever got one under its own number, which is
why ADR numbering here starts at `0013`. Some of the twelve were decided
anyway (formally or by default) without a recorded ADR, and some are
genuinely still open. Below is the honest state of each, not a repeated
mandate — treat "resolved by default" entries as the actual answer, not
as still-outstanding.

1. **Monorepo tool and package manager** — Resolved by default, no ADR:
   none adopted. `apps/api` and `apps/candidate-mobile` are independent
   sibling directories, each with its own package manager (npm, pub); no
   `turbo.json`/`nx.json`/`pnpm-workspace.yaml` at the repo root.
2. **Next.js web and Flutter mobile application boundaries** — Resolved:
   see `docs/adr/0016-flutter-candidate-mobile-boundary.md`.
3. **API runtime and BFF strategy** — Resolved in practice: NestJS
   (`apps/api`), per the locked stack in `AGENTS.md` and
   `docs/01-system-architecture.md`. The BFF-vs-direct-Supabase boundary
   itself is the actual contested decision here, and that one has ADRs:
   `docs/adr/0013-candidate-owned-supabase-data-access.md` and
   `docs/adr/0014-recorded-turn-voice-boundary.md`.
4. **PostgreSQL ORM/query layer** — Resolved by default, no ADR: none.
   Supabase's client libraries plus versioned SQL under
   `supabase/migrations` directly; no ORM layer introduced.
5. **Authentication and OTP provider abstraction** — Resolved: see
   `docs/adr/0019-candidate-authentication-channel-strategy.md`.
6. **Queue/background job system** — Still open. No queue exists; the one
   scheduled job (job-source syncing, Phase H) uses `@nestjs/schedule`'s
   `@Cron` directly, not a general queue.
7. **Object storage and media processing** — Partially resolved: Supabase
   Storage's private voice-media bucket is covered under
   `docs/adr/0014-recorded-turn-voice-boundary.md`'s Security/Privacy
   section. No general media-processing pipeline exists beyond that.
8. **AI model gateway and provider strategy** — Still open. No AI provider
   is connected anywhere in the app yet; voice evaluation uses a local
   deterministic development evaluator only (see ADR-0014).
9. **Real-time versus recorded-turn voice strategy** — Resolved: see
   `docs/adr/0014-recorded-turn-voice-boundary.md`.
10. **Analytics stack and event governance** — Still open, and worth
    treating as a real gap, not just an unmade decision: analytics events
    go to `InMemoryAnalyticsTracker` and are discarded, not sent to any
    real backend. There is currently no production observability for user
    behaviour at all.
11. **Feature flags** — Still open. No feature-flag system exists.
12. **Deployment environments and secrets** — Resolved in practice, no
    ADR: environment separation via `APP_ENV`/dart-defines and GitHub
    Actions repository secrets/variables (see
    `.github/workflows/build-apk.yml`); Vercel environment separation for
    `apps/api`. Never formalized as an ADR because the mechanism is
    Supabase/Vercel/GitHub Actions' own convention, not a contested
    in-house design choice.

When one of the still-open items above gets decided, write it as a normal
numbered ADR (`0020` onward) using the template above — don't edit this
list to mark it done in place, so this file stays a snapshot of what was
true when it was last reconciled (2026-08-11) rather than silently
drifting the way the original mandate did for months.
