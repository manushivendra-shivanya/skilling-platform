import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_icons.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure_localization.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_progress.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../onboarding/presentation/pre_onboarding_step_chrome.dart';
import 'development_auth_controller.dart';

class EmailEntryScreen extends ConsumerStatefulWidget {
  const EmailEntryScreen({required this.onOtpRequested, super.key});

  final VoidCallback onOtpRequested;

  @override
  ConsumerState<EmailEntryScreen> createState() => _EmailEntryScreenState();
}

class _EmailEntryScreenState extends ConsumerState<EmailEntryScreen> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    final succeeded = await ref
        .read(developmentAuthControllerProvider.notifier)
        .requestOtp(_emailController.text);
    if (succeeded && mounted) {
      widget.onOtpRequested();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(developmentAuthControllerProvider);
    final isRealBackend = ref.watch(
      appConfigProvider.select((config) => config.hasSupabaseConfiguration),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.emailEntryAppBarTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PreOnboardingBrandMark(),
              const SizedBox(height: AppSpacing.md),
              // Reached only once the candidate has committed to the email
              // path (Google sign-in skips straight past Email/OTP), so
              // the real 4-step total is known here -- see
              // `PreOnboardingProgress`'s doc comment.
              AppProgress(
                value: 3 / PreOnboardingProgress.emailPathSteps,
                label: l10n.onboardingGettingStartedLabel,
                detail: l10n.homeMissionStep(
                  3,
                  PreOnboardingProgress.emailPathSteps,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Icon(
                Icons.email_outlined,
                size: 56,
                color: AppColors.brand,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.emailEntryHeadline,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                isRealBackend
                    ? l10n.emailEntryRealBackendSubtitle
                    : l10n.emailEntryDevSubtitle,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              if (isRealBackend)
                AppCard(
                  semanticLabel: l10n.emailEntryRealBackendCardSemantic,
                  backgroundColor: AppColors.infoSoft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(AppIcons.info, color: AppColors.info),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(l10n.emailEntryRealBackendCardText)),
                    ],
                  ),
                )
              else
                AppCard(
                  semanticLabel: l10n.emailEntryDevCardSemantic,
                  backgroundColor: AppColors.infoSoft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(AppIcons.info, color: AppColors.info),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(l10n.emailEntryDevCardText)),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(
                label: l10n.emailEntryFieldLabel,
                controller: _emailController,
                hint: l10n.emailEntryFieldHint,
                errorText: authState.failure?.localizedMessage(l10n),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                leadingIcon: Icons.email_outlined,
                enabled: !authState.isRequesting,
                semanticLabel: l10n.emailEntryFieldLabel,
                // The failure only cleared when the next request started, so
                // a validation error stayed on screen while the candidate
                // corrected the address -- making a now-valid address look
                // rejected. Clear it as soon as they edit.
                onChanged: (_) {
                  if (authState.failure != null) {
                    ref
                        .read(developmentAuthControllerProvider.notifier)
                        .clearFailure();
                  }
                },
                onSubmitted: (_) => _requestOtp(),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                // Every other string on this screen already branches on
                // isRealBackend; this one did not, so a build wired to a
                // real Supabase project told the candidate it was sending
                // a "development code" while sending them a real one.
                label: isRealBackend
                    ? l10n.emailEntrySendCodeButton
                    : l10n.emailEntrySendDevCodeButton,
                isLoading: authState.isRequesting,
                onPressed: _requestOtp,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                // This one was hardcoded too, and unlike the button label it
                // stated something untrue about data handling: a configured
                // build does send the address to Supabase, which sends the
                // code by email. Consent copy has to describe what the
                // build actually does.
                isRealBackend
                    ? l10n.emailEntryConsentReal
                    : l10n.emailEntryConsentDev,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
