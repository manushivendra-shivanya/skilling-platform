import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';

enum JourneyStep { learn, practise, assess, proof, apply }

/// Dark "your journey" card with a dot-and-line stepper, matching the design
/// brief's Today-tab journey card. [currentStep] is derived by the caller
/// from real dashboard signals (learning/readiness progress) -- this widget
/// only draws whatever step it's told is current, it doesn't guess.
class JourneyStepCard extends StatelessWidget {
  const JourneyStepCard({required this.currentStep, super.key});

  final JourneyStep currentStep;

  // "Learning" rather than "Learn": originally chosen because the
  // bottom-nav tab was also labelled "Learn" and an exact duplicate made
  // this stepper ambiguous to WidgetTester.tap(find.text('Learn')) across
  // many existing tests whenever Home (which always shows this card) was
  // the current screen. The bottom-nav tab is now "Train"
  // (main_navigation_shell.dart), but "Learning" is kept for its own sake.
  static const _labels = ['Learning', 'Practise', 'Assess', 'Proof', 'Apply'];

  @override
  Widget build(BuildContext context) {
    final currentIndex = currentStep.index;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: AppRadius.extraLargeBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR JOURNEY',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.outline,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Building toward job-ready, one skill at a time.',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              for (var i = 0; i < _labels.length; i++) ...[
                _StepDot(
                  state: i < currentIndex
                      ? _DotState.done
                      : i == currentIndex
                      ? _DotState.current
                      : _DotState.upcoming,
                ),
                if (i != _labels.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: i < currentIndex
                          ? AppColors.success
                          : const Color(0xFF33403A),
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < _labels.length; i++)
                Text(
                  _labels[i],
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: i == currentIndex
                        ? AppColors.highlight
                        : AppColors.outline,
                    fontWeight: i == currentIndex
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _DotState { done, current, upcoming }

class _StepDot extends StatelessWidget {
  const _StepDot({required this.state});

  final _DotState state;

  @override
  Widget build(BuildContext context) {
    final (size, color, glow) = switch (state) {
      _DotState.done => (9.0, AppColors.success, false),
      _DotState.current => (13.0, AppColors.highlight, true),
      _DotState.upcoming => (9.0, const Color(0xFF33403A), false),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: glow
            ? [
                BoxShadow(
                  color: AppColors.highlight.withValues(alpha: 0.35),
                  blurRadius: 6,
                  spreadRadius: 3,
                ),
              ]
            : null,
      ),
    );
  }
}
