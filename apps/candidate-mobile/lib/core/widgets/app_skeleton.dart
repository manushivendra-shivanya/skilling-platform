import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';

class AppSkeleton extends StatelessWidget {
  const AppSkeleton({
    required this.height,
    this.width = double.infinity,
    this.borderRadius = AppRadius.mediumBorder,
    super.key,
  });

  final double height;
  final double width;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading content',
      child: ExcludeSemantics(
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: borderRadius,
          ),
        ),
      ),
    );
  }
}

class AppSkeletonCard extends StatelessWidget {
  const AppSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSkeleton(height: 18, width: 160),
        SizedBox(height: AppSpacing.sm),
        AppSkeleton(height: 14),
        SizedBox(height: AppSpacing.xs),
        AppSkeleton(height: 14, width: 220),
        SizedBox(height: AppSpacing.md),
        AppSkeleton(height: 44),
      ],
    );
  }
}
