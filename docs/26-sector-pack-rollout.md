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
| Warehouse & Logistics | `warehouseLogistics` | [Shift Floor](https://claude.ai/code/artifact/7577fd3a-a115-4e19-bbfa-fd0242325c3c) — published, plus a [full coverage pass](https://claude.ai/code/artifact/b66d923c-031c-4a3a-a958-8cf6362abad9) against every real screen state | Yes — `learning_screen.dart`, `practice_screen.dart`, and the Certification tab (`certification_exam_section.dart`) render through the four shared structural widgets in `lib/features/sector_pack/presentation/`, resolving `SectorPacks.warehouseLogistics` via `activeSectorPackProvider` (hardcoded — see the Entry point section above; no role resolver exists yet) |
| Last-Mile Delivery Partner | `lastMileDelivery` | [On The Route](https://claude.ai/code/artifact/0aacdcbf-fb52-4998-bfca-69bf6eabe76e) v2 — published | No |
| Retail & Field Sales | *(not yet defined)* | Not started | No |
| Hospitality & F&B | *(not yet defined)* | Not started — spec note: primary colour green (food-safety/freshness association) | No |

"Wired to live screens" means `learning_screen.dart` /
`practice_screen.dart` / `certification_exam_section.dart` actually read
their content from a `SectorPack` instead of the current hardcoded mock
content. That migration has happened for `warehouseLogistics` only — for
every other pack it remains separate, future work, not implied by a
design reference existing.

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
| 2026-08-11 | Warehouse (Flutter build) | Lessons / Practise | `SectorIndexRow` and `SectorTaskCard` both sit inside a plain `ListView`, which gives each item unbounded height along the scroll axis. The mock's "stretch the index tag / stripe to the row's full height" effect, implemented first as `Row(crossAxisAlignment: stretch)` wrapped in `IntrinsicHeight`, hit two real bugs in sequence: (1) `IntrinsicHeight` estimates each child's height at the *full* row width rather than the narrower width text actually gets once flex siblings take their share, under-computing height for a wrapped title at a large accessibility text scale and overflowing; (2) removing `IntrinsicHeight` in response then hit `CrossAxisAlignment.stretch`'s own requirement for a *bounded* cross-axis size, which a ListView item's unbounded height doesn't provide, crashing with "BoxConstraints forces an infinite height" | High | Fixed — rebuilt both widgets on a `Stack` instead: the row/card's own size comes from the naturally-laid-out content, and the coloured index tag / stripe / tear tab are `Positioned` to fill whatever height that resolves to. No stretch, no intrinsic pre-pass, no ambiguity at any text scale |
| 2026-08-11 | Warehouse (Flutter build) | Certification | The credential card's gradient was speced against the mock's literal navy (`#16233B`→`#0A1220`), which isn't part of `SectorPack` and would have been a hardcoded warehouse colour inside a supposedly sector-blind widget. Replaced with a gradient derived from `SectorPack.primaryAccent` darkened 55–88% toward black — re-verified the resulting contrast for white body text against both existing packs' `primaryAccent` (warehouse orange, last-mile green): 12:1–19:1 in every case, comfortably past WCAG AA | Medium | Fixed in `sector_credential_card.dart` before it shipped, not after — the derivation is now the documented, sector-blind default |
| 2026-08-11 | Warehouse (Flutter build) | Lessons | `learning_screen.dart`'s loading skeleton (`_LearningLoadingView`, fixed-height `Column` of `AppSkeleton`s) started overflowing at a 2x accessibility text scale on a short device once it had to fit under the new, taller segmented tab bar (idx + label + state readout, versus the old single-line `TabBar`) — not a sector-pack bug per se, but a real regression the taller chrome surfaced | Medium | Fixed — wrapped the loading view in a `SingleChildScrollView` |
| 2026-08-11 | Warehouse (Flutter build) | Lessons | First draft of the diagonal hazard-tape stripe painter set `strokeWidth` to `stripeWidth * sqrt(2)` (treating the mock's CSS `repeating-linear-gradient` band width as if it were the stroke's own perpendicular width) — at a 45° line angle that produces a *horizontal* band twice the intended 8px, since the correct relationship is `strokeWidth = horizontalWidth / sqrt(2)`, not the reverse. Caught by hand-deriving the geometry before shipping, not by eyeballing the render | Medium | Fixed in `learning_screen.dart`'s `_HazardStripePainter` before it shipped — worked formula and the reasoning are in the painter's own doc comment |
| 2026-08-11 | Warehouse (Flutter build) | Practise | The wizard card's primary answer button was first drawn with the same white text every other element on the dark focal card uses. Computed contrast caught it before shipping: white text on `signalPalette.active` (hazard amber, `#F5B700`) is only 1.8:1 — badly fails WCAG AA — because the amber fill itself is light, unlike the dark gradient the rest of the card sits on. `SectorTaskCard`'s own `_toneColor`/`onToneColor` brightness-estimation pattern already solves exactly this, reused directly (`ThemeData.estimateBrightnessForColor`) rather than hardcoding black | Medium | Fixed before shipping — black-on-amber verified at 11.7:1 |
| 2026-08-11 | Warehouse (Flutter build) | Practise | The approved mock's caption estimated wizard-card contrast at "11-14:1 depending on step" from its `color-mix()` CSS approximation. Re-derived from Flutter's actual `Color.lerp(primaryAccent, Colors.black, t)` output (same 0.55/0.85 mix ratios): the real range is wider, 12.4:1 (gradient top-left) to 18.9:1 (bottom-right) — both still comfortably past AA/AAA, but a reminder the two colour-mixing functions don't produce identical numbers even at matching mix ratios, so a mock's stated contrast should be re-verified against the real widget output, not cited as-is | Low | Not a bug — documented the real numbers in `_WizardStepCard`'s doc comment instead of repeating the mock's estimate |
| 2026-08-11 | Warehouse (Flutter build) | Practise | `SectorIndexRow`'s contract (a left-edge `indexLabel` tag) doesn't fit `WarehouseClipsSection`'s rows — a process clip has no natural "L-01"-style index the way a lesson unit does. Confirmed via the task brief's own explicit call-out before building, not discovered by trial — built a lighter, screen-scoped `_ClipRow` reusing `SectorPackTypography`/`SectorIcon`/`pack` colours instead of forcing the row into a widget contract that doesn't apply | Low | Resolved as a deliberate scope decision, not a defect — `_ClipRow` stays private to `warehouse_clips_section.dart`, not a fifth shared structural widget |
| 2026-08-11 | Warehouse (Flutter build) | Practise | The inventory demo's `_DemoOptionCard` needed a single accessible node (informational text + a decorative radio glyph, no separate interactive child) — but wrapping a `Semantics(label:, excludeSemantics: true)` around an `InkWell` drops the *tap action* along with the descendant semantics ExcludeSemantics is meant to hide, since the InkWell's own `SemanticsAction.tap` never reaches the excluded subtree's parent. A real semantics-tree dump (`debugDumpSemanticsTree()`) confirmed the resulting node had `flags: isButton` and a correct merged `label` but no `actions: tap` until `onTap:` was also set directly on the outer `Semantics` widget | Medium | Fixed before shipping — `_DemoOptionCard` passes `onTap` explicitly on the outer `Semantics` node; re-dumped and confirmed `actions: tap` present alongside the correct label |
| 2026-08-11 | Warehouse (Flutter build) | Practise | Converting "Recommended practice" to a real `SectorTaskCard` made its default "Not started" state text collide with `practice_workplace_entry_card_test.dart`'s `findsNWidgets(4)` assertion for the 4 mission cards' own "Not started" text (now 5 matches) — an existing test relying on an implicit count that a same-shape sibling card broke | Low | Fixed — updated the test's expected count and its comment explaining why |
| 2026-08-11 | Warehouse (Flutter, full TalkBack sweep) | Learn tab bar | `learn_and_practice_screen.dart`'s 3-way segmented bar (`_SectorSegmentedTabBar`) had no `Semantics` node of its own at all — Flutter's default merge still made each segment reachable and tappable (`actions: focus, tap` showed up in a real `debugDumpSemanticsTree()` dump), but the *selected* tab was never announced on any segment, ever, since nothing ever set `selected:`/`isSelected`. A screen-reader user had no way to tell which of Lessons/Practise/Certification they were currently on | High | Fixed — each segment is now `Semantics(label:, button: true, selected:, role: SemanticsRole.tab, container: true, excludeSemantics: true, onTap:)`, the row wrapped in `role: SemanticsRole.tabBar`, mirroring the bottom nav's own `NavigationBar` shape; `onTap` repeated explicitly on the outer node (the same excludeSemantics-drops-the-tap-action fix already shipped on `_DemoOptionCard`/`_ExamOptionCard`) since this segment IS the sole tap target. Re-dumped and confirmed `isSelected` present on exactly the active segment, absent on the other two, and flips correctly when tapped through the semantics node itself, not just its raw text — covered by a new permanent test, `learn_and_practice_tab_bar_semantics_test.dart` |
| 2026-08-11 | Warehouse (Flutter, full TalkBack sweep) | Lessons / Practise | `SectorIndexRow` and `SectorTaskCard` both merge an author-supplied `semanticLabel` onto their outer `Semantics(container: true)` node *without* `excludeSemantics: true` (unlike `SectorCredentialCard`'s already-fixed `infoContent` split). A real `debugDumpSemanticsTree()` dump on a real lesson row confirmed the resulting label read the crafted sentence *and then* every descendant `Text`'s own value again (e.g. `"Inventory accuracy basics. Tap to open lesson.\nTODAY'S MISSION\nInventory accuracy basics\n8 min...\nL-01"`) — the whole row read twice. Not a dropped-tap-action trap (no separate interactive descendant is at risk the way `SectorIndexRow`'s trailing utility button is), just a redundant, overwhelming label | Medium | Fixed both. `SectorIndexRow`: `ExcludeSemantics` scoped to just the icon/body/index-tag content (careful to wrap the `Padding` *inside* `Expanded`, not `Expanded` itself — wrapping `Expanded` directly crashed with "Incorrect use of ParentDataWidget", caught immediately by re-running the diagnostic test), leaving `trailing` completely untouched and still independently reachable (re-dumped and confirmed). `SectorTaskCard`: since the whole card is the one tap target (no separate trailing button to protect), applied the same `excludeSemantics: true` + explicit `onTap:` repeat pattern as `_DemoOptionCard`/`_ExamOptionCard`. Both re-dumped clean; regression coverage added to `sector_pack_widgets_test.dart` |
| 2026-08-11 | Warehouse (Flutter, full TalkBack sweep) | Practise | `practice_screen.dart`'s scored-simulation `_ResultCard` (score %, explanation, three dimension rows, improvement note, and the "Return to practice" button) declared no `Semantics` boundary anywhere in its `Column`. Since the button was the *only* actionable descendant in the whole subtree, Flutter's default merge validly combined everything into one node — but a real `debugDumpSemanticsTree()` dump showed the button's own text landing as the tail of one giant paragraph-length label, with no `button` role, instead of being its own clean, independently reachable, correctly-ordered node (the same trap class as `sector_credential_card.dart`'s pre-fix bug, just without an author-supplied `semanticLabel` making it as obvious from source) | Medium | Fixed — gave the informational block and the button each their own `Semantics(container: true)` boundary. First attempt gave only the button `button: true` without its own `container: true`; re-dumping showed the informational block got re-parented as the button's *child*, inverting traversal order (button announced before the score breakdown it describes). Adding `container: true` to the button too resolved it — both re-dumped as clean, correctly-ordered siblings, matching how `certification_exam_result_screen.dart`'s `_ResultBanner` and `AppButton('Back to Learn')` already sit as siblings with no such inversion. Regression coverage added to `practice_screen_restyle_test.dart` |

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
