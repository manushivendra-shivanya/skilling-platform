import 'dart:math';

import 'package:flutter/material.dart';

import '../domain/sector_pack.dart';
import 'sector_pack_icons.dart';
import 'sector_pack_typography.dart';
import 'sector_signal_dot.dart';

/// Structural widget 4 of 4: the credential card -- the "Access Badge" in
/// the published Shift Floor mock ([SectorPack.credentialLabel] names what
/// it's called in a given sector).
///
/// The dark gradient is **derived from [SectorPack.primaryAccent]**
/// (darkened toward black), not a hardcoded warehouse navy -- this is what
/// keeps the widget sector-blind while still producing a credential-grade
/// "this is a serious document" surface for any pack. Verified against
/// every colour this produces from the two packs defined today: darkening
/// `primaryAccent` 55-88% toward black keeps white body text at a 12:1+
/// contrast ratio in both cases (see the PR that added this file for the
/// worked numbers) -- re-check this if a future pack's `primaryAccent` is
/// unusually light.
class SectorCredentialCard extends StatelessWidget {
  const SectorCredentialCard({
    required this.pack,
    required this.orgLine,
    required this.levelLabel,
    required this.glyph,
    required this.credentialName,
    required this.subtitle,
    required this.statusLabel,
    required this.statusState,
    required this.barcodeSeed,
    this.eligibilityLabel,
    this.eligibilityFraction,
    this.attemptText,
    this.attemptState,
    this.ctaLabel,
    this.onCta,
    this.ctaEnabled = true,
    this.semanticLabel,
    super.key,
  });

  final SectorPack pack;

  /// e.g. "SKILLING PLATFORM · WAREHOUSE OPS".
  final String orgLine;

  /// e.g. "PASS 70%".
  final String levelLabel;
  final SectorGlyph glyph;
  final String credentialName;
  final String subtitle;

  /// e.g. "LOCKED" / "ELIGIBLE" / "VERIFIED".
  final String statusLabel;
  final SectorSignalState statusState;

  /// Seeds the deterministic decorative barcode -- pass something stable
  /// per card (e.g. an exam + candidate id) so it doesn't repaint
  /// differently on every rebuild.
  final String barcodeSeed;

  final String? eligibilityLabel;

  /// 0..1. Null hides the eligibility bar entirely (e.g. once passed).
  final double? eligibilityFraction;

  final String? attemptText;
  final SectorSignalState? attemptState;

  final String? ctaLabel;
  final VoidCallback? onCta;
  final bool ctaEnabled;

  /// An overall status summary (e.g. "Warehouse Ops Certification, locked,
  /// 2 of 4 lessons cleared") for everything except [ctaLabel]'s button,
  /// which stays independently reachable/announced as its own element.
  /// Null means "not yet audited for this call site" -- prefer supplying
  /// it; every real usage should.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final base = pack.primaryAccent;
    final darkTop = Color.lerp(base, Colors.black, 0.55)!;
    final darkBottom = Color.lerp(base, Colors.black, 0.85)!;
    const onDark = Colors.white;
    final onDarkSoft = Colors.white.withValues(alpha: 0.68);
    final statusColor = switch (statusState) {
      SectorSignalState.locked => pack.signalPalette.locked,
      SectorSignalState.active => pack.signalPalette.active,
      SectorSignalState.cleared => pack.signalPalette.cleared,
    };

    final infoContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                orgLine,
                style: SectorPackTypography.monoLabel(
                  color: onDarkSoft,
                  fontSize: 9.5,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: pack.signalPalette.active,
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                levelLabel,
                style: SectorPackTypography.monoLabel(
                  color: darkBottom,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
              ),
              child: SectorIcon(glyph: glyph, color: onDarkSoft, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    credentialName,
                    style: SectorPackTypography.displayLabel(
                      color: onDark,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: SectorPackTypography.bodyRegular(
                      color: onDarkSoft,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (eligibilityFraction != null) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                'ELIGIBILITY',
                style: SectorPackTypography.monoLabel(
                  color: onDarkSoft,
                  fontSize: 10,
                ),
              ),
              if (eligibilityLabel != null) ...[
                const Spacer(),
                Flexible(
                  child: Text(
                    eligibilityLabel!,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: SectorPackTypography.monoLabel(
                      color: onDarkSoft,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: eligibilityFraction!.clamp(0, 1),
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(
                eligibilityFraction! >= 1
                    ? pack.signalPalette.cleared
                    : pack.signalPalette.active,
              ),
            ),
          ),
        ],
        if (attemptText != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              border: Border(
                left: BorderSide(
                  width: 4,
                  color: switch (attemptState) {
                    SectorSignalState.cleared => pack.signalPalette.cleared,
                    SectorSignalState.locked => pack.signalPalette.locked,
                    _ => pack.signalPalette.active,
                  },
                ),
              ),
            ),
            child: Text(
              attemptText!,
              style: SectorPackTypography.bodyRegular(
                color: Colors.white.withValues(alpha: 0.86),
                fontSize: 12,
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: _Barcode(seed: barcodeSeed)),
            const SizedBox(width: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SectorSignalDot(pack: pack, state: statusState, size: 8),
                const SizedBox(width: 5),
                Text(
                  statusLabel,
                  style: SectorPackTypography.monoLabel(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    // excludeSemantics: true, not just container: true -- without it,
    // Flutter merges every descendant's own semantics (org line, level
    // pill, name, subtitle, eligibility text, *and* the progress bar's
    // role: progressBar / value semantics) into one combined node whose
    // label is all that text newline-joined. Caught via a real
    // semantics-tree dump in this widget's test: the merged node announced
    // the whole card as a single confusingly-labelled "progress bar" that
    // also swallowed the CTA button's own text -- worse than no
    // semanticLabel at all. excludeSemantics replaces all of that with
    // just the one summary string, and because it's scoped to infoContent
    // only (not the CTA below), the button stays its own reachable node.
    final wrappedInfo = semanticLabel == null
        ? infoContent
        : Semantics(
            label: semanticLabel,
            container: true,
            excludeSemantics: true,
            child: infoContent,
          );

    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [darkTop, darkBottom],
        ),
      ),
      child: Stack(
        children: [
          // Foil sheen -- a deliberate, kept device (see the dogfooding
          // log in docs/26: a reviewer flagged it as reading purple on the
          // original navy mock, then chose to keep it after a side-by-side
          // with a flat alternative).
          Positioned(
            top: -60,
            left: -20,
            child: Transform.rotate(
              angle: 0.14,
              child: Container(
                width: 140,
                height: 320,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0),
                      Colors.white.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              wrappedInfo,
              if (ctaLabel != null) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: Material(
                    color: ctaEnabled
                        ? pack.primaryAccent
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                    child: InkWell(
                      onTap: ctaEnabled ? onCta : null,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        child: Text(
                          ctaLabel!,
                          textAlign: TextAlign.center,
                          style: SectorPackTypography.bodySemiBold(
                            color: ctaEnabled ? Colors.white : onDarkSoft,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Barcode extends StatelessWidget {
  const _Barcode({required this.seed});

  final String seed;

  @override
  Widget build(BuildContext context) {
    final random = Random(seed.hashCode);
    final bars = List.generate(28, (_) => 1 + random.nextInt(3));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          color: Colors.white,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final width in bars)
                Padding(
                  padding: const EdgeInsets.only(right: 1),
                  child: Container(
                    width: width.toDouble(),
                    color: Colors.black,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          seed.toUpperCase(),
          style: SectorPackTypography.monoLabel(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}
