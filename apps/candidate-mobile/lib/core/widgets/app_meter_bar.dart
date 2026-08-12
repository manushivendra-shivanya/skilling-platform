import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';

/// A bare, label-less thin filled meter -- just the bar, with no percentage
/// text or heading. Home's pathway row, the Today Mission card, the sector
/// credential card's eligibility strip, and Jobs' match meter each
/// hand-rolled a near-identical few lines of this. (For a bar with its own
/// label and percentage readout, see [AppProgress] instead -- a heavier,
/// different-purpose widget.)
///
/// Built as a [Stack] + [Positioned.fill] + [FractionallySizedBox] -- the
/// technique Jobs' `_MatchMeterBar` already used -- rather than wrapping
/// [LinearProgressIndicator], which is what the older Home/mission/
/// sector-pack duplicates did. A `FractionallySizedBox` at a fixed height
/// paints a predictable, jank-free fill with no dependency on Material's
/// progress-indicator theming or its built-in value-change animation,
/// neither of which a purely presentational meter needs.
class AppMeterBar extends StatelessWidget {
  const AppMeterBar({
    required this.value,
    this.height = 6,
    this.trackColor = AppColors.surfaceMuted,
    this.fillColor = AppColors.brand,
    super.key,
  });

  /// 0.0-1.0. Clamped rather than asserted -- callers deriving this from a
  /// raw percentage (e.g. Jobs' 0-100 match score) shouldn't each have to
  /// re-clamp before passing it in.
  final double value;
  final double height;
  final Color trackColor;
  final Color fillColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Stack(
          children: [
            Positioned.fill(child: Container(color: trackColor)),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: value.clamp(0.0, 1.0),
                child: Container(height: height, color: fillColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
