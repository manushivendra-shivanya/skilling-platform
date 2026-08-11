# 26 — Sector Pack Rollout

Companion tracking doc to `docs/adr/0020-sector-pack-abstraction.md`,
which explains *why* Lessons/Practise/Certification split into shared
structural widgets plus a per-sector `SectorPack`. This doc tracks the
*status* of each pack: where a candidate's sector gets decided, what a
pack has to clear before it's trustworthy, and what real dogfooding has
already caught. Update this file, not the ADR, when a pack's status
changes — the ADR is a snapshot of the decision, this is the living
state.

## Entry point — how a candidate's SectorPack gets chosen

No entry point exists yet, because only one sector is live
(`SectorPacks.warehouseLogistics` — see `docs/00-master-plan.md`'s Phase
Gate: no sector expansion until the logistics pathway proves out). This
section is the plan for when a second sector actually gets wired in, not
a description of something built.

**Decision: resolve the pack from the candidate's target job role, not a
separate "pick your sector" screen.** The candidate app already has a job
role taxonomy (`docs/00-master-plan.md`'s initial-roles list;
`docs/03-api-specifications.md`'s job/shift matching) — a candidate is
matched to or selects a target role during onboarding
(`candidate_onboarding_controller.dart`) well before they reach Lessons.
A `roleToSectorPack` lookup (role → `SectorPackId`) is the entry point:
"Warehouse Operations Associate" → `warehouseLogistics`, "Last-Mile
Delivery Partner" → `lastMileDelivery`, and so on. This avoids a
redundant sector-picker UI and keeps the pack tied to something the
matching engine already reasons about.

That lookup table is content, not code — it belongs in the future admin
portal's "Taxonomy and role management" area (`docs/11-admin-portal.md`),
same as the pack data itself eventually should. Until that portal exists,
both live as `SectorPacks` constants in
`apps/candidate-mobile/lib/features/sector_pack/domain/sector_pack.dart`.

**Not decided yet, deliberately:** what happens for a candidate matched
to more than one role/sector at once, and whether a candidate can ever
manually override the resolved pack (e.g. to preview a track before
switching). Both are open questions for whoever wires the second pack in,
not resolved here.

## Status per pack

| Pack | `SectorPackId` | Design reference | Wired to live screens |
|---|---|---|---|
| Warehouse & Logistics | `warehouseLogistics` | [Shift Floor](https://claude.ai/code/artifact/7577fd3a-a115-4e19-bbfa-fd0242325c3c) — published | No — screens still render the pre-SectorPack mock content |
| Last-Mile Delivery Partner | `lastMileDelivery` | [On The Route](https://claude.ai/code/artifact/0aacdcbf-fb52-4998-bfca-69bf6eabe76e) v2 — published | No |
| Retail & Field Sales | *(not yet defined)* | Not started | No |
| Hospitality & F&B | *(not yet defined)* | Not started — spec note: primary colour green (food-safety/freshness association) | No |

"Wired to live screens" means `learning_screen.dart` /
`practice_screen.dart` / `certification_exam_section.dart` actually read
their content from a `SectorPack` instead of the current hardcoded mock
content. That migration hasn't happened for any pack yet — it's separate,
future work per pack, not implied by a design reference existing.

## QC checklist

Run this before a pack's design reference is considered locked (i.e.
before its "Design reference" cell above changes from a draft link to a
published, screenshot-verified one) and again before it's wired to a live
screen:

- [ ] All four slots (signal, list item, task object, credential) have
      real-world referents named explicitly in the pack data — not "TBD"
      and not a description of the abstraction itself (e.g. `signalSource`
      must name an actual object, not say "a status colour system").
- [ ] Terminology matches how the trade actually talks about these things
      — checked against a real source or practitioner knowledge, not
      guessed. (Andon, shop traveler, and maker-checker in the
      cross-sector notes below are examples of this; don't invent a term
      when the trade has its own.)
- [ ] Icon set is custom-drawn stroke icons, one consistent weight — no
      emoji, no bare stock Material icons dropped in raw.
- [ ] Typeface choice has a stated rationale tied to the sector (why this
      face, not "it looked fine") — see docs/04's design checklist.
- [ ] `primaryAccent` is a distinct token from every colour in
      `signalPalette` — `sector_pack_test.dart` enforces this at the data
      level, but the *design* still needs a human check that a
      content-type tag (e.g. "Scored") doesn't visually collide with a
      status colour on the actual mock.
- [ ] Every structural device (divider, card shape, credential format) is
      re-derived from this sector's own artifacts, not copy-pasted from
      another pack with new colours. If a device is intentionally reused
      because it's genuinely common to both sectors (e.g. a torn-ticket
      tab), say so explicitly rather than leaving it silent.
- [ ] Vernacular (Hindi/Hinglish) copy present for all user-facing labels,
      matching the convention already established in the app (Hindi term
      with an English gloss in parentheses, e.g. "अभ्यास (प्रैक्टिस)").
- [ ] Rendered and screenshot-verified — light and dark theme, all three
      screens — via headless Chromium before publishing, not eyeballed
      from source.
- [ ] Reviewed against `docs/04-ui-ux-specification.md` Part 2's design
      checklist.
- [ ] Nav chrome (Home / Lessons / Practise / Career) is unchanged from
      the reference pack — confirms the pack boundary actually sits where
      the ADR says it does (app shell is structure, screen content is
      data).

## Dogfooding log

Real findings from building and reviewing the two existing packs — kept
here as the actual record, not a placeholder. Add to this table, don't
replace it, as more packs go through review.

| Date | Pack | Screen | Finding | Severity | Status |
|---|---|---|---|---|---|
| 2026-08-11 | Warehouse | Certification | `LVL 1` pill wrapped onto two lines | Medium | Fixed |
| 2026-08-11 | Warehouse | Certification | Barcode rendered as a sparse bar-chart/equalizer, not a barcode | Medium | Fixed — denser bars, added a code line |
| 2026-08-11 | Warehouse | Lessons | Hazard-tape divider rendered as a rounded pill inset from the screen edges instead of full-bleed tape | Low | Fixed |
| 2026-08-11 | Warehouse | Certification | Night-mode header text invisible (dark-on-dark) — `color` wasn't re-declared on `.phone-screen`, so descendants inherited the light-mode value instead of picking up the scoped dark override | High | Fixed — root-caused to a real CSS custom-property inheritance gap, not guessed |
| 2026-08-11 | Warehouse | Certification | Glossy diagonal sheen on the navy badge gradient read as purple to the reviewer | Low | Resolved — user reviewed a flat/matte alternative side-by-side and chose to keep the gloss; not a bug, a design call |
| 2026-08-11 | Last-mile v1 | All three | First draft reused the warehouse pack's literal chrome (condensed industrial type, hard-cut corners, offset shadows, diagonal hazard-tape divider) with only copy swapped — read as "warehouse floor, recoloured" | High | Fixed — full v2 rebuild with sector-specific widget shapes (route line, trip-request card, licence-styled ID) |
| 2026-08-11 | Last-mile v2 | Practise | After recolouring to the traffic-signal palette, the "Scored" tag's background collided with the new primary accent colour | Medium | Fixed — moved the tag to a neutral ink background, reserved the signal colours for actual state |
| 2026-08-11 | Last-mile v2 | Lessons | Locked list-row state used a generic grey instead of the sector's own "stop" signal colour | Low | Fixed — locked now reads as the traffic-light red |
| 2026-08-11 | Last-mile (domain model) | — | `sector_pack_test.dart`'s collision-guard test caught `primaryAccent` and `signalPalette.cleared` sharing the exact same hex in the Dart model — the same collision class as the Practise-tag bug above, just imperceptible at that particular colour value | Low | Fixed in the domain model (deepened `primaryAccent`); the published mock still has the original value, judged not worth a re-publish for an imperceptible difference |

## Cross-sector notes (not yet built)

Kept here rather than re-derived later — from the design discussion that
produced the SectorPack abstraction, before Retail or Hospitality/F&B
have actual design references:

- **Manufacturing shop floor**: Andon line-stop light (functionally
  identical R/A/G logic to warehouse dock lights — closest reuse of any
  sector), work-cell stations as the list, a shop traveler as the task
  object, a machine-qualification/skills-matrix badge as the credential.
- **Banking/BFSI ops**: counter status (Open/Serving/Closed) — no hazard
  colour, institutional teal/navy — ledger folio rows, a voucher/slip as
  the task object, a KYC/teller keycard as the credential.
- **Finance & admin back-office**: maker-checker state
  (Drafted/Pending/Approved/Returned), batch/queue rows, a reconciliation
  ticket, a "checker approved" stamp/seal as the credential.
- **Hospitality & F&B**: not yet designed. Spec note carried over from
  the last-mile review: primary colour should be green (food-safety /
  freshness association, e.g. FSSAI hygiene-rating green), likely a
  kitchen pass-ticket board as the task-object idiom.
