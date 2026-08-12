import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_progress.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/app_state_view.dart';
import '../domain/candidate_language.dart';
import 'language_selection_controller.dart';
import 'pre_onboarding_step_chrome.dart';

class LanguageSelectionScreen extends ConsumerWidget {
  const LanguageSelectionScreen({required this.onContinue, super.key});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedLanguage = ref.watch(languageSelectionControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Language / भाषा')),
      body: SafeArea(
        child: selectedLanguage.when(
          loading: () => const _LanguageLoadingView(),
          error: (error, stackTrace) => AppErrorState(
            title: 'We could not load your language',
            message: 'Please try again. Your selection stays on this device.',
            onAction: () =>
                ref.read(languageSelectionControllerProvider.notifier).retry(),
          ),
          data: (language) => _LanguageSelectionContent(
            selectedLanguage: language,
            onSelect: (value) => ref
                .read(languageSelectionControllerProvider.notifier)
                .select(value),
            onContinue: onContinue,
          ),
        ),
      ),
    );
  }
}

class _LanguageSelectionContent extends StatelessWidget {
  const _LanguageSelectionContent({
    required this.selectedLanguage,
    required this.onSelect,
    required this.onContinue,
  });

  final CandidateLanguage? selectedLanguage;
  final ValueChanged<CandidateLanguage> onSelect;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            // The brand mark + progress header used to sit fixed above a
            // separately-scrolling language list, each competing with the
            // other for a share of the screen's fixed height. On a narrow,
            // heavily text-scaled device that fixed split had no give left
            // -- adding the header pushed the list past a hard overflow
            // rather than just scrolling further. Folding header and list
            // into one `ListView` means extra header content (or a larger
            // text scale) simply scrolls, the way `_buildStep`'s own
            // `SingleChildScrollView` already absorbs the same widgets in
            // the onboarding wizard.
            child: ListView(
              children: [
                const PreOnboardingBrandMark(),
                const SizedBox(height: AppSpacing.md),
                AppProgress(
                  value: 1 / PreOnboardingProgress.sharedPrefixSteps,
                  label: 'Getting started',
                  detail:
                      'Step 1 of ${PreOnboardingProgress.sharedPrefixSteps}',
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Choose the language you are comfortable with',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'आप इसे बाद में कभी भी बदल सकते हैं।',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                for (final language in CandidateLanguage.values) ...[
                  AppCard(
                    key: ValueKey(language.code),
                    semanticLabel:
                        '${language.nativeName}. ${language.description}. '
                        '${language == selectedLanguage ? 'Selected' : 'Not selected'}',
                    onTap: () => onSelect(language),
                    backgroundColor: language == selectedLanguage
                        ? AppColors.brandSoft
                        : AppColors.surface,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                language.nativeName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(language.description),
                            ],
                          ),
                        ),
                        Icon(
                          language == selectedLanguage
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: language == selectedLanguage
                              ? AppColors.brand
                              : AppColors.outline,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Continue',
            onPressed: selectedLanguage == null ? null : onContinue,
            semanticLabel: selectedLanguage == null
                ? 'Continue, choose a language first'
                : 'Continue with ${selectedLanguage!.nativeName}',
          ),
        ],
      ),
    );
  }
}

class _LanguageLoadingView extends StatelessWidget {
  const _LanguageLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeleton(width: 260, height: 32),
          SizedBox(height: AppSpacing.xl),
          AppSkeleton(height: 80),
          SizedBox(height: AppSpacing.sm),
          AppSkeleton(height: 80),
          SizedBox(height: AppSpacing.sm),
          AppSkeleton(height: 80),
        ],
      ),
    );
  }
}
