import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_icons.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    required this.onContinue,
    this.onOpenComponentGallery,
    this.onOpenWms3dPreview,
    this.onOpenMicroLessons,
    super.key,
  });

  final VoidCallback onContinue;
  final VoidCallback? onOpenComponentGallery;
  final VoidCallback? onOpenWms3dPreview;
  final VoidCallback? onOpenMicroLessons;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - (AppSpacing.xl * 2),
              ),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const Spacer(),
                    Semantics(
                      header: true,
                      child: Text(
                        'Saksham',
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(color: AppColors.brand),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      width: 104,
                      height: 104,
                      decoration: const BoxDecoration(
                        color: AppColors.brandSoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        AppIcons.coach,
                        size: 52,
                        color: AppColors.brand,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Build skills. Prove your readiness. Find better work.',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Practical guidance for logistics careers, in the language you prefer.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Spacer(),
                    AppButton(
                      label: 'Choose your language',
                      leadingIcon: Icons.translate,
                      onPressed: onContinue,
                    ),
                    if (onOpenComponentGallery != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      AppButton(
                        label: 'View design system',
                        variant: AppButtonVariant.text,
                        onPressed: onOpenComponentGallery,
                      ),
                    ],
                    if (onOpenWms3dPreview != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      AppButton(
                        label: 'WMS 3D preview (dev)',
                        variant: AppButtonVariant.text,
                        onPressed: onOpenWms3dPreview,
                      ),
                    ],
                    if (onOpenMicroLessons != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      AppButton(
                        label: 'Micro-lessons (dev)',
                        variant: AppButtonVariant.text,
                        onPressed: onOpenMicroLessons,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
