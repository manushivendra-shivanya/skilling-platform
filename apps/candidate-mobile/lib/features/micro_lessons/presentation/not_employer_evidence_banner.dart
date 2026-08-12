import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';

/// Standing disclaimer for micro-lesson content and practice questions
/// (v0.1): nothing shown alongside this banner is scored, recorded, or
/// surfaced to an employer. Shared between the clip list section and the
/// clip detail/practice screen so the label reads identically everywhere
/// it applies.
///
/// [message] defaults to the micro-lesson wording; pass an override when a
/// caller's context needs different wording for the same disclosure --
/// e.g. `practice_screen.dart`'s top-of-screen banner, which names
/// "demonstrations" rather than "practice feedback" since it sits above
/// scored simulations too. Added as an optional, additive param rather than
/// a second banner widget so every caller stays visually and semantically
/// identical apart from the wording.
class NotEmployerEvidenceBanner extends StatelessWidget {
  const NotEmployerEvidenceBanner({this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message ?? 'Practice feedback only — not employer evidence yet.',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
