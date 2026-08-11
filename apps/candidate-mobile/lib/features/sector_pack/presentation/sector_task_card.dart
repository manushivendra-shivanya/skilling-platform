import 'package:flutter/material.dart';

import '../domain/sector_pack.dart';
import 'sector_pack_typography.dart';

/// A [SectorTaskCard]'s left-edge stripe / tag colour. Named by meaning,
/// not by a literal colour, so the mapping onto a real [SectorPack] colour
/// stays sector-blind:
///
/// - [emphasis] -- the featured / scored item. Uses the app's own ink
///   colour (not part of [SectorPack] -- a shared, non-sector-specific
///   neutral), matching the mock's "scored" tag reading as the strongest,
///   most serious tone on the board.
/// - [active] -- in progress / practice. Reads [SectorPack.signalPalette]'s
///   `active` colour.
/// - [cleared] -- completed. Reads `signalPalette.cleared`.
/// - [muted] -- unavailable / coming soon / locked. Reads
///   `signalPalette.locked`.
enum SectorTaskTone { emphasis, active, cleared, muted }

/// Structural widget 3 of 4: the task-object card -- the "Job Ticket" in
/// the published Shift Floor mock ([SectorPack.taskObjectLabel] names what
/// it's called in a given sector). A coloured stripe plus a torn-tab
/// affordance stand in for the second CTA the pre-pack
/// `_WorkplaceSimulationCard` stacked on top of the card itself.
class SectorTaskCard extends StatelessWidget {
  const SectorTaskCard({
    required this.pack,
    required this.workOrderLabel,
    required this.tagLabel,
    required this.tone,
    required this.title,
    required this.description,
    required this.tearLabel,
    this.statLeft,
    this.statRight,
    this.onTap,
    this.unavailable = false,
    this.semanticLabel,
    super.key,
  });

  final SectorPack pack;

  /// e.g. "WM-01" -- a work-order-style reference, computed by the caller.
  final String workOrderLabel;
  final String tagLabel;
  final SectorTaskTone tone;
  final String title;
  final String description;

  /// The vertical tear-tab label, e.g. "START" / "CONTINUE" / "RETRY".
  final String tearLabel;
  final String? statLeft;
  final String? statRight;
  final VoidCallback? onTap;

  /// True dims the tear tab and disables the implied affordance -- content
  /// genuinely unavailable, not just visually muted.
  final bool unavailable;
  final String? semanticLabel;

  static const double _stripeWidth = 7;
  static const double _tearWidth = 34;

  Color _toneColor(BuildContext context) => switch (tone) {
    SectorTaskTone.emphasis => Theme.of(context).colorScheme.onSurface,
    SectorTaskTone.active => pack.signalPalette.active,
    SectorTaskTone.cleared => pack.signalPalette.cleared,
    SectorTaskTone.muted => pack.signalPalette.locked,
  };

  @override
  Widget build(BuildContext context) {
    final toneColor = _toneColor(context);
    final onToneColor =
        ThemeData.estimateBrightnessForColor(toneColor) == Brightness.dark
        ? Colors.white
        : Colors.black;
    final surface = Theme.of(context).colorScheme.surfaceContainerLow;
    final divider = Theme.of(context).dividerColor;
    final inkSoft = Theme.of(context).colorScheme.onSurfaceVariant;
    final ink = Theme.of(context).colorScheme.onSurface;

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(
        _stripeWidth + 5,
        10,
        _tearWidth + 6,
        10,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.start,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                workOrderLabel,
                style: SectorPackTypography.monoLabel(color: inkSoft),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: toneColor,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  tagLabel.toUpperCase(),
                  style: SectorPackTypography.monoLabel(
                    color: onToneColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 9.5,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(title, style: SectorPackTypography.bodyBold(color: ink)),
          const SizedBox(height: 4),
          Text(
            description,
            style: SectorPackTypography.bodyRegular(
              color: inkSoft,
              fontSize: 12,
            ),
          ),
          if (statLeft != null || statRight != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Flexible(
                  child: Text(
                    statLeft ?? '',
                    style: SectorPackTypography.monoLabel(color: inkSoft),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (statRight != null && statRight!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    statRight!,
                    style: SectorPackTypography.monoLabel(color: inkSoft),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );

    final tear = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: divider)),
      ),
      child: RotatedBox(
        quarterTurns: 1,
        child: Text(
          tearLabel.toUpperCase(),
          style: SectorPackTypography.monoLabel(
            color: unavailable ? inkSoft : pack.primaryAccent,
            fontWeight: FontWeight.w700,
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
      ),
    );

    // A Stack, not a stretch-cross-axis Row -- see the identical note in
    // sector_index_row.dart. This card sits directly inside a ListView
    // (unbounded height along the scroll axis), which both
    // `CrossAxisAlignment.stretch` and `IntrinsicHeight` handle badly
    // there. The Stack's size comes from [content]'s natural layout; the
    // stripe and tear tab are `Positioned` to fill whatever height that
    // turns out to be.
    final card = Container(
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: divider),
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              content,
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: _stripeWidth,
                child: ColoredBox(color: toneColor),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: _tearWidth,
                child: tear,
              ),
            ],
          ),
        ),
      ),
    );

    if (semanticLabel == null) return card;
    // excludeSemantics: true hides every descendant's own text (work order,
    // tag, title, description, stat line, tear label) -- without it, a real
    // debugDumpSemanticsTree() dump showed this node reading `semanticLabel`
    // *and then* every one of those strings again, since there's no
    // separate interactive child here for excludeSemantics to protect (the
    // whole card is the one tap target, same shape as
    // practice_screen.dart's `_DemoOptionCard`). Because excludeSemantics
    // also drops the InkWell's own tap-action semantics, `onTap` is
    // repeated explicitly on this node to keep it screen-reader-activatable
    // -- the same fix already shipped there and on
    // certification_exam_screen.dart's `_ExamOptionCard`.
    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: onTap != null,
      container: true,
      excludeSemantics: true,
      onTap: onTap,
      child: card,
    );
  }
}
