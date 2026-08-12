import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/coach_mark.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/backend_warmup_banner.dart';
import '../../authentication/presentation/development_auth_controller.dart';
import '../domain/candidate_language.dart';
import 'language_selection_controller.dart';

class SignInChoiceScreen extends ConsumerWidget {
  const SignInChoiceScreen({
    required this.onContinueWithEmail,
    required this.onGoogleAuthenticated,
    super.key,
  });

  final VoidCallback onContinueWithEmail;
  final VoidCallback onGoogleAuthenticated;

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
            return _SignInChoiceContent(
              language: language,
              onContinueWithEmail: onContinueWithEmail,
              onGoogleAuthenticated: onGoogleAuthenticated,
            );
          },
        ),
      ),
    );
  }
}

class _SignInChoiceContent extends ConsumerWidget {
  const _SignInChoiceContent({
    required this.language,
    required this.onContinueWithEmail,
    required this.onGoogleAuthenticated,
  });

  final CandidateLanguage language;
  final VoidCallback onContinueWithEmail;
  final VoidCallback onGoogleAuthenticated;

  Future<void> _signInWithGoogle(BuildContext context, WidgetRef ref) async {
    final succeeded = await ref
        .read(developmentAuthControllerProvider.notifier)
        .signInWithGoogle();
    if (succeeded && context.mounted) {
      onGoogleAuthenticated();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = SignInCopy.forLanguage(language);
    final isGoogleConfigured = ref.watch(
      appConfigProvider.select((config) => config.hasGoogleSignInConfiguration),
    );
    final authState = ref.watch(developmentAuthControllerProvider);
    final googleStatus = isGoogleConfigured
        ? authState.failure?.message
        : copy.googleStatus;

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
          // Watching this fires the backend wake-up ping right as sign-in
          // starts, well before the first real request Home/Jobs/Shift
          // will make once the candidate is in.
          const BackendWarmupBanner(),
          const CoachMark(size: 56, color: AppColors.brand),
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
            label: copy.emailLabel,
            leadingIcon: Icons.email_outlined,
            onPressed: onContinueWithEmail,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: copy.googleLabel,
            leadingIcon: Icons.account_circle_outlined,
            variant: AppButtonVariant.secondary,
            isLoading: authState.isVerifying,
            onPressed: isGoogleConfigured
                ? () => _signInWithGoogle(context, ref)
                : null,
            semanticLabel: isGoogleConfigured
                ? copy.googleLabel
                : '${copy.googleLabel}. ${copy.googleStatus}',
          ),
          if (googleStatus != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              googleStatus,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isGoogleConfigured
                    ? AppColors.error
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
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
