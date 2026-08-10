import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';

/// The static block every skeleton placeholder is built from -- shimmer is
/// applied once, around every [AppSkeleton] on a screen together (see
/// `AppSkeletonGroup`), not per-block, so the shine sweeps across a whole
/// loading layout as one motion rather than N independent ones.
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

/// Wraps any subtree of [AppSkeleton]s in a Material-style shimmer sweep --
/// the standard Android/Flutter loading convention for list-shaped content
/// (a skeleton screen reads as "this is coming" far better than a bare
/// spinner, which says nothing about shape or count). A screen with a
/// loading state built from [AppSkeleton] blocks should wrap them all in
/// one [AppSkeletonGroup] rather than each in its own -- one continuous
/// sweep across the whole layout, not N unsynchronised ones.
///
/// Respects [MediaQuery.disableAnimations] (the OS "reduce motion"
/// setting) by skipping the shimmer entirely and rendering the plain
/// static blocks -- the loading state is still fully legible, just still.
class AppSkeletonGroup extends StatelessWidget {
  const AppSkeletonGroup({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceMuted,
      highlightColor: AppColors.surface,
      period: const Duration(milliseconds: 1400),
      child: child,
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
