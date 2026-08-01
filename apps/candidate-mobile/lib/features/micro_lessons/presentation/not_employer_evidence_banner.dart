import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';

/// Standing disclaimer for micro-lesson content and practice questions
/// (v0.1): nothing shown alongside this banner is scored, recorded, or
/// surfaced to an employer. Shared between the clip list section and the
/// clip detail/practice screen so the label reads identically everywhere
/// it applies.
class NotEmployerEvidenceBanner extends StatelessWidget {
  const NotEmployerEvidenceBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Practice feedback only — not employer evidence yet.',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
