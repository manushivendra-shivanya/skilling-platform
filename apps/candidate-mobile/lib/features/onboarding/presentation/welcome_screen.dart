import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/coach_mark.dart';
import '../../../core/widgets/app_button.dart';
import '../../../l10n/generated/app_localizations.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    required this.onContinue,
    this.onOpenComponentGallery,
    this.onOpenWms3dPreview,
    this.onSkipToHome,
    super.key,
  });

  final VoidCallback onContinue;
  final VoidCallback? onOpenComponentGallery;
  final VoidCallback? onOpenWms3dPreview;
  final VoidCallback? onSkipToHome;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                    if (onSkipToHome != null)
                      Align(
                        alignment: Alignment.topRight,
                        child: AppButton(
                          label: l10n.welcomeSkipToHomeDev,
                          variant: AppButtonVariant.text,
                          onPressed: onSkipToHome,
                        ),
                      ),
                    const Spacer(),
                    Semantics(
                      header: true,
                      child: Text(
                        // Brand name -- deliberately not run through
                        // AppLocalizations, same as e.g. a company wordmark:
                        // it is not translated copy, it is what the app is
                        // called.
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
                      child: const CoachMark(size: 52, color: AppColors.brand),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      l10n.welcomeHeadline,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.welcomeSubtitle,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Spacer(),
                    AppButton(
                      label: l10n.welcomeChooseLanguageButton,
                      leadingIcon: Icons.translate,
                      onPressed: onContinue,
                    ),
                    if (onOpenComponentGallery != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      AppButton(
                        label: l10n.welcomeViewDesignSystemDev,
                        variant: AppButtonVariant.text,
                        onPressed: onOpenComponentGallery,
                      ),
                    ],
                    if (onOpenWms3dPreview != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      AppButton(
                        label: l10n.welcomeWms3dPreviewDev,
                        variant: AppButtonVariant.text,
                        onPressed: onOpenWms3dPreview,
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
