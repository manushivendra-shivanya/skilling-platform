import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_loading_progress.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/backend_warmup_banner.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../authentication/presentation/development_auth_controller.dart';
import '../domain/candidate_language.dart';
import 'language_selection_controller.dart';
import 'pre_onboarding_step_chrome.dart';

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
    final l10n = AppLocalizations.of(context);
    final selectedLanguage = ref.watch(languageSelectionControllerProvider);

    return Scaffold(
      // Was a bare, untitled AppBar -- the one screen in the pre-onboarding
      // header set that didn't say where the candidate was. Titled to match
      // the other 3 (Language, Email, OTP), all of which already carry a
      // plain step-name title in the default AppBar style.
      appBar: AppBar(title: Text(l10n.signInAppBarTitle)),
      body: SafeArea(
        child: selectedLanguage.when(
          loading: () => Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: AppLoadingProgressBar(
                label: l10n.signInLoadingLanguageLabel,
              ),
            ),
          ),
          error: (error, stackTrace) => AppErrorState(
            title: l10n.languageLoadErrorTitle,
            message: l10n.signInLanguageErrorMessage,
            actionLabel: l10n.signInLanguageErrorReloadAction,
            onAction: () =>
                ref.read(languageSelectionControllerProvider.notifier).retry(),
          ),
          data: (language) {
            if (language == null) {
              return AppErrorState(
                title: l10n.signInNoLanguageTitle,
                message: l10n.signInNoLanguageMessage,
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
    final l10n = AppLocalizations.of(context);
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
          // One consistent small brand mark, matching Language/Email/OTP --
          // was its own one-off 56px CoachMark before. No step-progress
          // indicator on this screen: which of the two buttons below the
          // candidate taps decides whether their total is 2 steps (Google)
          // or 4 (email), so any number shown here would have to be
          // silently rewritten the instant they choose. See
          // `PreOnboardingProgress`'s doc comment for the full reasoning.
          const PreOnboardingBrandMark(),
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
                title: l10n.signInTermsTitle,
                message: l10n.signInTermsMessage,
              ),
              Text(' ${copy.andLabel} '),
              _PolicyLink(
                label: copy.privacyLabel,
                title: l10n.signInPrivacyTitle,
                message: l10n.signInPrivacyMessage,
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
      child: AppButton(
        label: label,
        variant: AppButtonVariant.text,
        expand: false,
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
      ),
    );
  }
}
