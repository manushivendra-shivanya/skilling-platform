# 26 — Award-Grade Design System

## Why this file exists

The Home and Voice Interview Practice redesigns (see the `2782334`-lineage
commits and the award-grade voice interview commit on `main`) came out of a
`/deep-research` pass on what makes mobile product design genuinely
award-grade (Webby-caliber), not just "clean Material Design." That research
lived only in a downloaded document and in scattered code comments — nothing
made a future session, or a later point in this one, re-read it before
building the next screen. That's exactly how Lessons, Practise, and
Certification ended up visually out of sync with Home: they were built to an
earlier, generic standard and never retrofitted.

This file is the fix: the durable, checkable form of that research. It is
listed in `AGENTS.md`'s mandatory reading, so every session reads it before
touching candidate-facing UI — the same mechanism that already makes
`docs/04-ui-ux-specification.md` binding.

**Treat this as a checklist for every new or redesigned screen, not
inspiration.** If a screen doesn't hold up against every item below, it is
not done, the same way a screen with a failing test is not done.

## The principles, grounded in what's already shipped

### 1. One primary action per screen, everything else demoted
`TodayMissionCard` owns Home's only `FilledButton`; every other destination
is a row or an outlined action. Five equal buttons is not a design, it's an
unmade decision. Before shipping a screen, count the filled/primary buttons
on it — if it's more than one, that's a finding, not a style choice.

### 2. Evidence and cost before commitment, not after
`TodayMissionCard` shows duration and format *before* the action button —
a candidate on a prepaid data plan decides whether to start based on what
a task will cost them, not after they've already tapped in. Anywhere a
candidate commits to something (time, data, an attempt), the cost is
visible before the commitment, not revealed after.

### 3. Recency, not just a lifetime total
`HomeHeader`'s evidence count always carries its window ("7 proof items ·
last 30 days"), because a bare lifetime number reads as static and
recency is what an employer actually weighs. Any count that matters to a
decision (evidence, attempts, streaks) needs its time window stated next
to it, not implied.

### 4. Real data, not decorative motion
`AnswerPacingTrack` is deliberately **not** a waveform: the capture layer
exposes no amplitude, so a moving waveform would be animation pretending to
be data. Every piece of motion or visual richness on screen has to represent
something real and known — if the honest answer is "we don't have that
signal," the honest UI is simpler, not faked.

### 5. Colour is never the only channel
`AnswerPacingTrack`'s pace band is drawn, its figure is written in digits,
and its label states the same fact in words — three channels for one piece
of information, so colourblindness or a washed-out outdoor screen never
loses the point. Anywhere status is colour-coded (readiness bands, pace,
pass/fail), it also needs a label and/or an icon carrying the same meaning.

### 6. Cards read as lifted, not stacked
Home's mission card is a scroll-list sibling `Transform.translate`d to
overlap the header gradient — a real elevation relationship — rather than
another flat card in a flat list. Flat, evenly-spaced cards of equal visual
weight is the generic-Material default this system explicitly rejects; there
should always be one thing the eye lands on first.

### 7. Real icons, not bare Material defaults with no branding
The Home rebuild replaced bare `Icon(Icons.foo)` glyphs with a branded
header, layered shadows, and icon plates with intentional background tints
(`AppColors.brandSoft`/`infoSoft`/etc. behind each icon) — see
`_IconPlate` in `home_dashboard_screen.dart`. An icon floating on bare
background with no plate, tint, or shadow is the "thought is good, design is
poor" failure mode this system was built to stop.

### 8. Digits that tick must not reflow
`AnswerPacingTrack`'s clock uses `FontFeature.tabularFigures()` specifically
so the seconds counting up doesn't jiggle the layout next to it. Any live-
updating number (timers, counters, scores) needs tabular figures.

### 9. Hinglish is the default voice, not a translation pass
Copy throughout Home and the voice interview redesign ("Aaj koi mission
nahi", "Bilkul sahi lambai", "Ab samet lijiye") is written directly in
Hinglish, matched to the candidate's actual register — not English copy
translated afterward. This is `docs/04-ui-ux-specification.md`'s existing
non-negotiable; this file doesn't relax it, it reinforces it for anything
visual.

### 10. State something true, or say nothing
The voice interview screen states the no-accent-scoring promise on the
recording screen itself, not buried in a policy page, because that's the
moment the promise is actually in doubt. Reassurance, disclaimers, and
status copy belong at the point of doubt, not in a settings page nobody
reads before they need it.

## Checklist for any new or redesigned screen

- [ ] Exactly one filled/primary action, everything else demoted
- [ ] Cost/time/format shown before the commit action, not after
- [ ] Any count that matters to a decision carries its time window
- [ ] No animation or visual richness represents data the app doesn't have
- [ ] Every colour-coded status also has a label or icon carrying the same meaning
- [ ] The primary content reads as elevated (real shadow/overlap), not one more flat card
- [ ] Every icon sits in a tinted plate with intentional colour, not bare on background
- [ ] Live-updating numbers use tabular figures
- [ ] Copy is written in Hinglish directly, not translated after the fact
- [ ] Reassurance/disclaimer copy sits at the point of doubt, not a policy page

## Known screens still below this bar

As of this writing: **Lessons, Practise, and Certification** (the merged
Learn/Practise tab) were flagged as not in sync with this design language —
generic Material list tiles, no branded header, no evidence-first framing.
Mocks for their award-grade redesign are the next piece of work; check them
against every item above, not just against how Home looks.

## Keeping this current

This file is a snapshot of research done once. Treat it as living, not
frozen:
- When a redesign establishes a new pattern worth reusing (like the mission
  card's overlap, or the pacing track's three-channel status), add it here
  with the same grounding style — cite the file and the reasoning, not just
  the rule.
- If a genuinely new design-research pass happens (another `/deep-research`
  round, a fresh Webby-criteria review), fold its conclusions into this file
  rather than leaving them in a downloaded document or a chat transcript —
  that's the only form that survives a session switch.
