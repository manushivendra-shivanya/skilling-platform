import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';

/// White card with a circular readiness ring, matching the design brief's
/// Today-tab layout. Shows the same [readinessProgress] value the old
/// linear-bar card showed -- this is a visual change only, not a new number.
class ReadinessRingCard extends StatelessWidget {
  const ReadinessRingCard({
    required this.readinessProgress,
    required this.learningProgress,
    required this.onOpenDiagnostic,
    super.key,
  });

  final double readinessProgress;
  final double learningProgress;
  final VoidCallback onOpenDiagnostic;

  @override
  Widget build(BuildContext context) {
    final percent = (readinessProgress * 100).round();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.extraLargeBorder,
        border: Border.all(color: AppColors.surfaceMuted),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 108,
            height: 108,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(108, 108),
                  painter: _RingPainter(progress: readinessProgress),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$percent%',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      'ready',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Local mock estimate—not an employer score or hiring decision.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Learning progress',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              Text(
                '${(learningProgress * 100).round()}%',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: learningProgress,
              minHeight: 6,
              backgroundColor: AppColors.surfaceMuted,
              color: AppColors.brand,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Open career diagnostic',
            onPressed: onOpenDiagnostic,
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - 9) / 2;
    final track = Paint()
      ..color = AppColors.surfaceMuted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    final arc = Paint()
      ..color = AppColors.highlight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708, // -90deg, start at top
      6.2832 * progress.clamp(0, 1), // 2*pi * progress
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
