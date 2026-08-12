import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_elevation.dart';
import '../../../app/theme/app_icons.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/coach_mark.dart';
import '../../../core/widgets/app_accent_pill.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_gradient_hero.dart';
import '../../../core/widgets/app_icon_plate.dart';
import '../../../core/widgets/app_loading_progress.dart';
import '../../../core/widgets/app_meter_bar.dart';
import '../../../core/widgets/app_progress.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/app_status_banner.dart';
import '../../../core/widgets/app_sticky_footer.dart';
import '../../../core/widgets/app_text_field.dart';

class DesignSystemGalleryScreen extends StatelessWidget {
  const DesignSystemGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Component gallery')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.section,
        ),
        children: [
          Text(
            'Saksham design system',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Development-only reference for accessible, low-bandwidth candidate experiences.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const _GallerySection(
            title: 'Colour tokens',
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _ColorToken(label: 'Brand', color: AppColors.brand),
                _ColorToken(label: 'Accent', color: AppColors.accent),
                _ColorToken(label: 'Success', color: AppColors.success),
                _ColorToken(label: 'Warning', color: AppColors.warning),
                _ColorToken(label: 'Error', color: AppColors.error),
                _ColorToken(label: 'Info', color: AppColors.info),
              ],
            ),
          ),
          _GallerySection(
            title: 'Typography and Hindi expansion',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'अपनी अगली नौकरी के लिए आज का कौशल अभ्यास पूरा करें',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'हर कार्य का उद्देश्य, अनुमानित समय और अगला कदम साफ़ भाषा में दिखाया जाएगा।',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Complete today’s practical mission to strengthen your job readiness.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const _GallerySection(
            title: 'Icon strategy',
            child: Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.md,
              children: [
                _IconToken(label: 'Home', icon: Icon(AppIcons.home)),
                _IconToken(label: 'Train', icon: Icon(AppIcons.learn)),
                _IconToken(label: 'Practise', icon: Icon(AppIcons.practise)),
                _IconToken(label: 'Jobs', icon: Icon(AppIcons.jobs)),
                _IconToken(label: 'Profile', icon: Icon(AppIcons.profile)),
                _IconToken(label: 'Coach', icon: CoachMark()),
              ],
            ),
          ),
          _GallerySection(
            title: 'Buttons',
            child: Column(
              children: [
                AppButton(
                  label: 'आज का अभ्यास शुरू करें',
                  leadingIcon: Icons.play_arrow_rounded,
                  onPressed: () {},
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'View pathway',
                  variant: AppButtonVariant.secondary,
                  onPressed: () {},
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Not now',
                  variant: AppButtonVariant.text,
                  onPressed: () {},
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Delete draft',
                  variant: AppButtonVariant.destructive,
                  onPressed: () {},
                ),
                const SizedBox(height: AppSpacing.sm),
                const AppButton(
                  label: 'Preparing your mission',
                  onPressed: null,
                  isLoading: true,
                ),
                const SizedBox(height: AppSpacing.sm),
                const AppButton(label: 'Unavailable action', onPressed: null),
              ],
            ),
          ),
          const _GallerySection(
            title: 'Text fields',
            child: Column(
              children: [
                AppTextField(
                  label: 'पूरा नाम',
                  hint: 'अपना नाम लिखें',
                  helperText: 'Use the name you want employers to see.',
                  leadingIcon: Icons.person_outline,
                ),
                SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Mobile number',
                  errorText: 'Enter a valid 10-digit mobile number.',
                  keyboardType: TextInputType.phone,
                  leadingIcon: Icons.phone_outlined,
                ),
              ],
            ),
          ),
          _GallerySection(
            title: 'Cards and chips',
            child: Column(
              children: [
                AppCard(
                  semanticLabel: 'Daily mission, inventory discrepancy',
                  onTap: () {},
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppStatusChip(
                        label: 'Recommended',
                        tone: AppChipTone.success,
                      ),
                      SizedBox(height: AppSpacing.sm),
                      Text(
                        'Resolve an inventory discrepancy',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Text('Practical simulation · About 8 minutes'),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  elevation: AppElevation.medium,
                  semanticLabel: 'Elevated card, e.g. a toolbar wrapper',
                  child: const Text(
                    'AppCard(elevation: AppElevation.medium) -- raised '
                    'above ordinary page content, e.g. Jobs\' search '
                    'toolbar.',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    AppStatusChip(label: 'Downloaded'),
                    AppStatusChip(label: 'Ready', tone: AppChipTone.success),
                    AppStatusChip(
                      label: 'Needs attention',
                      tone: AppChipTone.warning,
                    ),
                    AppStatusChip(
                      label: 'Upload failed',
                      tone: AppChipTone.error,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const _GallerySection(
            title: 'Progress and skeleton loading',
            child: Column(
              children: [
                AppProgress(
                  value: 0.64,
                  label: 'Pathway progress',
                  detail: '7 of 11 missions',
                ),
                SizedBox(height: AppSpacing.xl),
                AppLoadingProgressBar(
                  label: 'Finding jobs for you…',
                  showPercent: true,
                ),
                SizedBox(height: AppSpacing.xl),
                AppCard(child: AppSkeletonCard()),
              ],
            ),
          ),
          _GallerySection(
            title: 'Empty and error states',
            child: Column(
              children: [
                AppCard(
                  child: AppEmptyState(
                    title: 'No applications yet',
                    message:
                        'Jobs you apply to will appear here with clear status updates.',
                    actionLabel: 'Browse jobs',
                    onAction: () {},
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: AppErrorState(
                    title: 'We could not load your pathway',
                    message:
                        'Your saved progress is safe. Check your connection and try again.',
                    onAction: () {},
                  ),
                ),
              ],
            ),
          ),
          const _GallerySection(
            title: 'Offline and pending sync',
            child: Column(
              children: [
                AppOfflineBanner(),
                SizedBox(height: AppSpacing.sm),
                AppPendingSyncBanner(pendingCount: 3),
              ],
            ),
          ),
          _GallerySection(
            title: 'Bottom sheet, dialog, and snackbar',
            child: Column(
              children: [
                AppButton(
                  label: 'Show bottom sheet',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => showAppBottomSheet<void>(
                    context: context,
                    title: 'Mission details',
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Review the expected time and downloaded content before starting.',
                        ),
                        SizedBox(height: AppSpacing.lg),
                        AppBottomSheetCloseButton(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Show confirmation dialog',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => showAppConfirmationDialog(
                    context: context,
                    title: 'Discard this draft?',
                    message:
                        'You can keep editing, or discard only this unfinished draft.',
                    confirmLabel: 'Discard draft',
                    isDestructive: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Show success message',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => showAppSnackBar(
                    context: context,
                    message: 'Your progress was saved.',
                    tone: AppMessageTone.success,
                  ),
                ),
              ],
            ),
          ),
          _GallerySection(
            title: 'Layout patterns',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('AppIconPlate + AppIconPlateButton'),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    const AppIconPlate(
                      icon: Icons.route_outlined,
                      background: AppColors.brandSoft,
                      foreground: AppColors.brand,
                    ),
                    AppIconPlateButton(
                      icon: Icons.schedule_outlined,
                      label: 'Availability',
                      background: AppColors.infoSoft,
                      foreground: AppColors.info,
                      onTap: () {},
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text('AppMeterBar'),
                const SizedBox(height: AppSpacing.sm),
                const AppMeterBar(value: 0.72),
                const SizedBox(height: AppSpacing.lg),
                const Text('AppAccentPill'),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    AppAccentPill(
                      icon: Icons.star_rounded,
                      label: 'Top match for you',
                      background: AppColors.brand,
                      foreground: Colors.white,
                      iconSize: 12,
                      fontSize: 10,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                AppAccentPill(
                  icon: Icons.bolt_rounded,
                  label: 'Starts in 45m',
                  background: AppColors.accentSoft,
                  foreground: AppColors.accent,
                  iconSize: 18,
                  fontWeight: FontWeight.w700,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  borderRadius: AppRadius.medium,
                  expand: true,
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text('AppGradientHero'),
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: AppRadius.mediumBorder,
                  child: AppGradientHero(
                    child: Text(
                      'नमस्ते, Rahul',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text('AppStickyFooter'),
                const SizedBox(height: AppSpacing.sm),
                AppStickyFooter(
                  child: AppButton(label: 'Accept shift', onPressed: () {}),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GallerySection extends StatelessWidget {
  const _GallerySection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _ColorToken extends StatelessWidget {
  const _ColorToken({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label colour token',
      child: ExcludeSemantics(
        child: SizedBox(
          width: 88,
          child: Column(
            children: [
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: AppRadius.mediumBorder,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(label, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconToken extends StatelessWidget {
  const _IconToken({required this.label, required this.icon});

  final String label;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Column(
        children: [
          Semantics(
            label: label,
            child: ExcludeSemantics(child: icon),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
