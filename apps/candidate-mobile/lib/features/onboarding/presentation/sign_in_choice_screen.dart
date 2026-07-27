import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_icons.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_state_view.dart';
import '../domain/candidate_language.dart';
import 'language_selection_controller.dart';

class SignInChoiceScreen extends ConsumerWidget {
  const SignInChoiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedLanguage = ref.watch(languageSelectionControllerProvider);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: selectedLanguage.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => AppErrorState(
            title: 'We could not load your language',
            message: 'Go back and select your language again.',
            actionLabel: 'Reload',
            onAction: () =>
                ref.read(languageSelectionControllerProvider.notifier).retry(),
          ),
          data: (language) {
            if (language == null) {
              return const AppErrorState(
                title: 'Choose a language first',
                message: 'Go back to select English, Hindi, or Hinglish.',
                actionLabel: null,
              );
            }
            return _SignInChoiceContent(language: language);
          },
        ),
      ),
    );
  }
}

class _SignInChoiceContent extends StatelessWidget {
  const _SignInChoiceContent({required this.language});

  final CandidateLanguage language;

  @override
  Widget build(BuildContext context) {
    final copy = SignInCopy.forLanguage(language);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(AppIcons.coach, size: 56, color: AppColors.brand),
          const SizedBox(height: AppSpacing.xl),
          Text(
            copy.title,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            copy.message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppButton(
            label: copy.phoneLabel,
            leadingIcon: Icons.phone_android,
            onPressed: () => showAppSnackBar(
              context: context,
              message:
                  'Phone OTP sign-in will be enabled in Phase 1.4. No phone number is collected yet.',
              tone: AppMessageTone.neutral,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: copy.googleLabel,
            leadingIcon: Icons.account_circle_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: null,
            semanticLabel: '${copy.googleLabel}. ${copy.googleStatus}',
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            copy.googleStatus,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('${copy.privacyLead} '),
              _PolicyLink(
                label: copy.termsLabel,
                title: 'Terms of Use',
                message:
                    'The complete versioned terms will be presented before account creation. No account is created in this phase.',
              ),
              Text(' ${copy.andLabel} '),
              _PolicyLink(
                label: copy.privacyLabel,
                title: 'Privacy summary',
                message:
                    'We collect only the information needed for your skilling and employment journey, with clear consent and visibility controls.',
              ),
              const Text('.'),
            ],
          ),
        ],
      ),
    );
  }
}

class _PolicyLink extends StatelessWidget {
  const _PolicyLink({
    required this.label,
    required this.title,
    required this.message,
  });

  final String label;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      label: label,
      child: TextButton(
        onPressed: () => showAppBottomSheet<void>(
          context: context,
          title: title,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message),
              const SizedBox(height: AppSpacing.lg),
              const AppBottomSheetCloseButton(),
            ],
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
