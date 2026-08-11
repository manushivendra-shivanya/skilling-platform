# ADR-0020: SectorPack Abstraction for Lessons/Practise/Certification

- Status: Accepted
- Date: 2026-08-11
- Owners: Design, Engineering

## Context

The candidate app's Lessons, Practise, and Certification screens (see
`docs/09-candidate-mobile-app.md`) were originally a generic soft-card
layout: every screen used the same rounded-card-plus-button vocabulary
regardless of subject matter. A design pass replaced that with a
warehouse-specific system ("Shift Floor" — dock status lights, rack bins,
job tickets, an access badge), published as a reference mock, then a
second pass built a genuinely distinct pack for last-mile delivery
partners ("On The Route" — a traffic light, route stops on a map-pin
line, trip-request cards, a driving-licence-styled Rider ID).

Building the second pack surfaced the actual question this ADR answers:
when the platform expands beyond the pilot sector (gated by
`docs/00-master-plan.md`'s Phase Gate — no sector expansion until the
logistics pathway proves out), does every new sector mean redesigning and
re-implementing three screens from scratch? The first last-mile draft
answered that question badly: it reused the warehouse pack's literal
widget chrome (condensed industrial type, hard-cut corners, hazard-tape
dividers) with only the copy swapped, and read as "warehouse floor,
recoloured" rather than something built for a delivery rider. The
corrected second draft replaced the widget shapes themselves, which
raised the real design question — how much should be shared, and how
much should be redrawn, per sector?

## Decision

Split the three screens into two layers:

1. **Structural widgets (shared, sector-blind).** A status-signal
   indicator, an index-tagged list row, a task-object card, and a
   credential card. These carry no sector-specific colour, copy, or
   iconography baked in.
2. **SectorPack (sector-specific data, no shared code).** A pack supplies
   the real-world referents that fill those slots: what the signal
   colours literally represent (`signalSource`, e.g. "Loading-dock status
   lights" vs. "Road traffic light"), the signal palette itself, a
   primary accent, and the labels for the list item / task object /
   credential (e.g. "Rack Bin" / "Job Ticket" / "Access Badge" for
   warehouse vs. "Route Stop" / "Trip Request" / "Rider & Vehicle ID" for
   last-mile).

Critically, layer 2 is **not** just a colour/copy swap over layer 1's
exact widget shapes — the last-mile rebuild showed that forcing every
sector into identically-shaped widgets (the warehouse pack's hard-cut
corners, its stamped-tag chip, its diagonal hazard-tape divider) produces
a reskin that still reads as the first sector. What's actually shared is
the four-slot *contract* (signal / list / task object / credential), not
the DOM/widget-shape of each slot's default implementation. A pack is
free to justify a different concrete widget for a slot — this ADR treats
that as expected, not a failure of abstraction, provided each replacement
is grounded in a real object from that sector (see the QC checklist in
`docs/26-sector-pack-rollout.md`).

The Dart-level contract lives at
`apps/candidate-mobile/lib/features/sector_pack/domain/sector_pack.dart`
as a plain data model (`SectorPack`, `SectorSignalPalette`,
`SectorPacks`). It is a **domain-layer stub only** as of this ADR — no
screen reads from it yet. Wiring `learning_screen.dart`,
`practice_screen.dart`, and `certification_exam_section.dart` to resolve
their content from a `SectorPack` is separate, future work, gated per
`docs/26-sector-pack-rollout.md`'s entry-point definition.

## Alternatives Considered

- **Bespoke redesign per sector.** Rejected: doesn't scale past two or
  three sectors, and duplicates engineering for something that's
  genuinely mostly-shared (screen flow, state handling, the four-slot
  shape).
- **One generic, sector-neutral visual system for every trade.** Rejected
  on the same grounds the original soft-card redesign was rejected for:
  it produces the "mediocre, could be any app" result this whole design
  effort was meant to fix.
- **Force every sector into byte-identical widget shapes, vary only
  colour/copy/icon.** Tried first for last-mile, rejected after review:
  the result still read as the warehouse pack with labels changed. The
  shared contract is the four slots, not each slot's default shape.
- **Auto-generate new sectors' packs from a template or an LLM prompt
  with no human domain review.** Rejected: deciding what stands in for
  "signal" or "credential" in a trade (Andon vs. teller counter vs.
  maker-checker) is real domain research, not something a template can
  produce safely — a badly-researched pack reads as costume, not craft.

## Consequences

- New sectors require a design pass (grounded in real artifacts from that
  trade) and a content-authoring pass (the `SectorPack` data), not a
  screen rebuild — once a pack is actually wired to the live screens,
  which has not happened yet for any pack.
- Two design references exist today: Shift Floor (warehouse, reference
  implementation) and On The Route (last-mile, reference implementation).
  Both are published mocks, screenshot-verified via headless Chromium
  before publishing each revision — see the dogfooding log in
  `docs/26-sector-pack-rollout.md` for what that process actually caught.
- Pack authoring is expected to live in the admin portal's future content
  workflow (`docs/11-admin-portal.md`'s "Taxonomy and role management" /
  "Learning content authoring" areas), not as an engineering PR per
  sector — that portal doesn't exist yet, so today a pack is added as a
  `SectorPacks` constant.
- `docs/26-sector-pack-rollout.md` owns the day-to-day tracking (entry
  point, QC checklist, dogfooding log) this ADR intentionally doesn't
  duplicate.

## Security/Privacy Impact

None. Pack data is static design/content configuration (colours, labels,
icon references) with no PII, credentials, or user data involved.

## Migration/Rollback

No live screen has been migrated yet, so there is nothing to roll back.
When a pack is first wired to `learning_screen.dart` /
`practice_screen.dart` / `certification_exam_section.dart`, that change
should be revertible independently of this ADR — the ADR only establishes
the data shape, not a specific screen's dependency on it.

## References

- `apps/candidate-mobile/lib/features/sector_pack/domain/sector_pack.dart`
- `docs/26-sector-pack-rollout.md`
- `docs/00-master-plan.md` (sector-expansion Phase Gate)
- `docs/04-ui-ux-specification.md` (the design checklist packs are
  reviewed against)
- `docs/11-admin-portal.md` (future home of pack authoring)
