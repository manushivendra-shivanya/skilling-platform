# ADR-0017: Practise Workplace Route Hierarchy

- Status: Accepted
- Date: 2026-07-28
- Owners: Product Engineering

## Context

The Candidate App already standardises the user-facing Practice feature on the
British-English `/practise` route. A later WMS screen contract used `/practice`
examples. Supporting both forms would create a parallel route tree, duplicate
deep links and ambiguous analytics.

## Decision

All Workplace Simulation screens remain under the established `/practise`
hierarchy:

```text
/practise/workplace-simulation
/practise/workplace-simulation/:missionId
/practise/workplace-simulation/:missionId/briefing
/practise/workplace-simulation/:missionId/workplace
/practise/workplace-simulation/:missionId/document-desk
/practise/workplace-simulation/:missionId/receiving-dock
/practise/workplace-simulation/:missionId/inspection-zone
```

The route mission ID must match the controller's loaded mission. Route presence
does not authorise workstation access; the application controller derives
unlock state and returns a typed open result.

No `/practice` aliases or redirects will be introduced.

## Alternatives Considered

- Add duplicate `/practice` routes: rejected because it creates two canonical
  URLs and can bypass consistent route guards.
- Rename the entire feature route to `/practice`: rejected because it breaks
  existing navigation, deep links, tests and analytics.
- Keep mission-specific hard-coded paths: rejected because the WMS hierarchy
  must support versioned missions without adding a new route constant per
  mission.

## Consequences

- Existing Candidate App naming remains stable.
- WMS route builders require and validate `missionId`.
- Documentation and tests must use `/practise` exclusively.
- External links must use the canonical British-English path.

## Security/Privacy Impact

Controller-owned route authorization prevents direct deep links from bypassing
persisted workstation progression.

## Migration/Rollback

Existing hard-coded WMS URLs already use `/practise` and remain shape-compatible
when converted to a mission parameter. Rollback requires a superseding ADR.

## References

- `docs/20-codex-phase-execution.md`
- `docs/21-workplace-management-simulation.md`
- `apps/candidate-mobile/lib/app/router/app_router.dart`
