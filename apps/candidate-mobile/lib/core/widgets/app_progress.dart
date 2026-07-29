import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';

class AppProgress extends StatelessWidget {
  const AppProgress({
    required this.value,
    required this.label,
    this.detail,
    super.key,
  }) : assert(value >= 0 && value <= 1);

  final double value;
  final String label;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final percentage = (value * 100).round();

    return Semantics(
      label: label,
      value: '$percentage percent',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  detail ?? '$percentage%',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            LinearProgressIndicator(
              value: value,
              minHeight: 8,
              borderRadius: BorderRadius.circular(999),
            ),
          ],
        ),
      ),
    );
  }
}
