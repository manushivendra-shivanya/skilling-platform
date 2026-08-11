import 'package:flutter/material.dart';

import '../domain/sector_pack.dart';
import 'sector_pack_icons.dart';
import 'sector_pack_typography.dart';
import 'sector_signal_dot.dart';

/// Structural widget 2 of 4: the index-tagged list row -- the "Rack Bin" in
/// the published Shift Floor mock for [SectorPack.warehouseLogistics]
/// (`SectorPack.listItemLabel` names what it's called in a given sector).
/// Sector-blind: colour comes from [pack]; every piece of copy is a
/// parameter, not a warehouse literal.
///
/// The whole row is the primary tap target (matches the mock's rationale:
/// "the row itself is the primary tap target ... only the single next
/// action gets a button" -- removes the button-stack problem the pre-pack
/// `_LessonCard` had). [trailing] is for a small secondary *utility*
/// action only (e.g. a download toggle) that must not compete with the
/// row's own tap.
class SectorIndexRow extends StatelessWidget {
  const SectorIndexRow({
    required this.pack,
    required this.indexLabel,
    required this.glyph,
    required this.title,
    required this.statusText,
    this.signalState,
    this.missionLabel,
    this.locked = false,
    this.onTap,
    this.trailing,
    this.semanticLabel,
    super.key,
  });

  final SectorPack pack;

  /// e.g. "L-01" -- computed by the calling screen, not this widget.
  final String indexLabel;
  final SectorGlyph glyph;
  final String title;

  /// The mono status line under the title, e.g.
  /// "8 min · Content v3 · tap to open".
  final String statusText;
  final SectorSignalState? signalState;

  /// e.g. "TODAY'S MISSION" -- null when this row has no such flag.
  final String? missionLabel;
  final bool locked;
  final VoidCallback? onTap;

  /// A small icon-only utility action (e.g. download), rendered after the
  /// body and before the row's own tap area ends. Wrap in its own
  /// `Tooltip`/`Semantics` -- this widget does not add one for you.
  final Widget? trailing;
  final String? semanticLabel;

  /// Width of the index-tag block overlaid on the left -- content below is
  /// padded by this much so it never sits under the tag.
  static const double _tagWidth = 46;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    final inkSoft = Theme.of(context).colorScheme.onSurfaceVariant;
    final tagColor = locked ? pack.signalPalette.locked : pack.primaryAccent;
    final stripeColor = locked
        ? pack.signalPalette.locked
        : pack.signalPalette.active;
    final iconColor = locked ? pack.signalPalette.locked : pack.primaryAccent;

    final iconWrap = Padding(
      padding: const EdgeInsets.all(10),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor, width: 1.5),
        ),
        child: SectorIcon(glyph: glyph, color: iconColor, size: 17),
      ),
    );

    final body = Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (missionLabel != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  missionLabel!,
                  style: SectorPackTypography.monoLabel(
                    color: pack.primaryAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                  ),
                ),
              ),
            Text(title, style: SectorPackTypography.bodyBold(color: ink)),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (signalState != null) ...[
                  SectorSignalDot(pack: pack, state: signalState!),
                  const SizedBox(width: 6),
                ] else if (locked) ...[
                  SectorIcon(glyph: SectorGlyph.lock, color: inkSoft, size: 11),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    statusText,
                    style: SectorPackTypography.monoLabel(color: inkSoft),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    // A Stack, not a stretch-cross-axis Row: this row sits directly inside
    // a ListView, which gives it unbounded height along the scroll axis.
    // `CrossAxisAlignment.stretch` (or `IntrinsicHeight`) both need a
    // *bounded* height to stretch children to and either crash
    // ("BoxConstraints forces an infinite height") or, when paired with
    // wrapped text at a large accessibility text scale, silently
    // under-measure it (IntrinsicHeight estimates each child's height at
    // the Row's *full* width, not the narrower width text actually wraps
    // at once other children take their share -- a real overflow this
    // shape hit before landing on the Stack approach; see this file's
    // widget tests). A Stack sidesteps both: its own size comes from the
    // naturally laid-out content below, and the index tag is simply
    // `Positioned` to fill whatever that height turns out to be.
    final row = Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: _tagWidth),
                child: Row(
                  children: [
                    iconWrap,
                    body,
                    if (trailing != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: trailing,
                      ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  constraints: const BoxConstraints(minWidth: _tagWidth),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: tagColor,
                    border: Border(
                      bottom: BorderSide(color: stripeColor, width: 3),
                    ),
                  ),
                  child: Text(
                    indexLabel,
                    textAlign: TextAlign.center,
                    style: SectorPackTypography.monoLabel(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (semanticLabel == null) return row;
    // Merges an overall label onto the row's semantics node without
    // excluding descendants -- the trailing utility button (its own
    // Tooltip/Semantics) must stay independently reachable.
    return Semantics(label: semanticLabel, container: true, child: row);
  }
}
