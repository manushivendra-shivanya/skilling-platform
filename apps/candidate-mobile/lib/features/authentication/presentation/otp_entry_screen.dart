import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure_localization.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_progress.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../onboarding/presentation/pre_onboarding_step_chrome.dart';
import 'development_auth_controller.dart';

class OtpEntryScreen extends ConsumerStatefulWidget {
  const OtpEntryScreen({
    required this.onAuthenticated,
    required this.onRequestNewOtp,
    super.key,
  });

  final VoidCallback onAuthenticated;
  final VoidCallback onRequestNewOtp;

  @override
  ConsumerState<OtpEntryScreen> createState() => _OtpEntryScreenState();
}

class _OtpEntryScreenState extends ConsumerState<OtpEntryScreen> {
  final _otpController = TextEditingController();
  Timer? _timer;
  String? _challengeId;
  DateTime? _expiresAt;
  DateTime? _resendAvailableAt;
  DateTime _now = DateTime.now();

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _syncChallenge(DevelopmentAuthState state) {
    final challenge = state.challenge;
    if (challenge == null || challenge.id == _challengeId) {
      return;
    }
    _challengeId = challenge.id;
    _expiresAt = challenge.expiresAt;
    _resendAvailableAt = challenge.resendAvailableAt;
    _now = DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  Future<void> _verifyOtp() async {
    final succeeded = await ref
        .read(developmentAuthControllerProvider.notifier)
        .verifyOtp(_otpController.text.trim());
    if (succeeded && mounted) {
      widget.onAuthenticated();
    }
  }

  Future<void> _resendOtp() async {
    final succeeded = await ref
        .read(developmentAuthControllerProvider.notifier)
        .resendOtp();
    if (succeeded && mounted) {
      _otpController.clear();
    }
  }

  int _remainingSeconds(DateTime? target) {
    if (target == null || !_now.isBefore(target)) {
      return 0;
    }
    return target.difference(_now).inSeconds + 1;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(developmentAuthControllerProvider);
    _syncChallenge(authState);
    final challenge = authState.challenge;
    // The hardcoded "123456" code only ever worked against the local mock
    // repository. Once real Supabase configuration is active,
    // developmentAuthRepositoryProvider swaps in SupabaseEmailAuthRepository,
    // which requires a genuine email round-trip -- showing the old dev-code
    // hint there would be actively misleading.
    final isRealBackend = ref.watch(
      appConfigProvider.select((config) => config.hasSupabaseConfiguration),
    );

    if (challenge == null) {
      return Scaffold(
        // Reachable if this route is opened with no active challenge (e.g.
        // a direct/cold navigation). Titled to match the loaded state below
        // rather than left bare -- same header-consistency fix as Sign-in
        // choice's AppBar.
        appBar: AppBar(title: Text(l10n.otpEntryAppBarTitle)),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: AppButton(
                label: l10n.otpEntryEnterPhoneButton,
                onPressed: widget.onRequestNewOtp,
                expand: false,
              ),
            ),
          ),
        ),
      );
    }

    final resendSeconds = _remainingSeconds(_resendAvailableAt);
    final expirySeconds = _remainingSeconds(_expiresAt);
    final maskedEmail = _maskEmail(challenge.contact);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.otpEntryAppBarTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PreOnboardingBrandMark(),
              const SizedBox(height: AppSpacing.md),
              // Last pre-onboarding step on the email path (Google skips
              // straight past this screen), so the real 4-step total is
              // known here -- see `PreOnboardingProgress`'s doc comment.
              AppProgress(
                value:
                    PreOnboardingProgress.emailPathSteps /
                    PreOnboardingProgress.emailPathSteps,
                label: l10n.onboardingGettingStartedLabel,
                detail: l10n.homeMissionStep(
                  PreOnboardingProgress.emailPathSteps,
                  PreOnboardingProgress.emailPathSteps,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.otpEntryHeadline,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                isRealBackend
                    ? l10n.otpEntryCodeSentTo(maskedEmail)
                    : l10n.otpEntryDevCodeFor(maskedEmail),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              if (isRealBackend)
                AppCard(
                  backgroundColor: AppColors.warningSoft,
                  semanticLabel: l10n.otpEntryRealBackendCardSemantic,
                  child: Text(
                    l10n.otpEntryRealBackendCardText,
                    textAlign: TextAlign.center,
                  ),
                )
              else
                AppCard(
                  backgroundColor: AppColors.warningSoft,
                  semanticLabel: l10n.otpEntryDevCardSemantic,
                  child: Text(
                    l10n.otpEntryDevCardText,
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(
                label: l10n.otpEntryFieldLabel,
                controller: _otpController,
                hint: l10n.otpEntryFieldHint,
                errorText: authState.failure?.localizedMessage(l10n),
                helperText: expirySeconds == 0
                    ? l10n.otpEntryCodeExpired
                    : l10n.otpEntryCodeExpiresIn(expirySeconds),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                leadingIcon: Icons.password_outlined,
                enabled: !authState.isVerifying,
                obscureText: true,
                semanticLabel: l10n.otpEntryFieldSemantic,
                onSubmitted: (_) => _verifyOtp(),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: l10n.otpEntryVerifyButton,
                isLoading: authState.isVerifying,
                onPressed: expirySeconds == 0 ? null : _verifyOtp,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: resendSeconds == 0
                    ? l10n.otpEntryResendButton
                    : l10n.otpEntryResendAvailableIn(resendSeconds),
                variant: AppButtonVariant.text,
                onPressed: resendSeconds == 0 ? _resendOtp : null,
              ),
              AppButton(
                label: l10n.otpEntryChangeEmailButton,
                variant: AppButtonVariant.text,
                onPressed: widget.onRequestNewOtp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `ab***@example.com` -- keeps the domain, which the candidate needs to
/// recognise the right inbox, while not putting their full address on
/// screen. Falls back to masking the whole local part for very short ones
/// rather than exposing it unmasked.
String _maskEmail(String email) {
  final atIndex = email.indexOf('@');
  if (atIndex <= 0) return email;
  final localPart = email.substring(0, atIndex);
  final domain = email.substring(atIndex);
  final visible = localPart.length <= 2 ? 1 : 2;
  return '${localPart.substring(0, visible)}***$domain';
}
