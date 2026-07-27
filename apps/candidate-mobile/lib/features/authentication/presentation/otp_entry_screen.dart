import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
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
    final authState = ref.watch(developmentAuthControllerProvider);
    _syncChallenge(authState);
    final challenge = authState.challenge;

    if (challenge == null) {
      return Scaffold(
        appBar: AppBar(),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: AppButton(
                label: 'Enter phone number',
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
    final maskedPhone = '******${challenge.phoneNumber.substring(6)}';

    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter the 6-digit code',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Development code for +91 $maskedPhone',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              const AppCard(
                backgroundColor: AppColors.warningSoft,
                semanticLabel:
                    'Development OTP is 123456. No SMS has been sent.',
                child: Text(
                  'Development OTP: 123456\nNo SMS has been sent.',
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(
                label: 'OTP',
                controller: _otpController,
                hint: '123456',
                errorText: authState.failure?.message,
                helperText: expirySeconds == 0
                    ? 'Code expired'
                    : 'Code expires in $expirySeconds seconds',
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                leadingIcon: Icons.password_outlined,
                enabled: !authState.isVerifying,
                obscureText: true,
                semanticLabel: 'Six digit one time password',
                onSubmitted: (_) => _verifyOtp(),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Verify and continue',
                isLoading: authState.isVerifying,
                onPressed: expirySeconds == 0 ? null : _verifyOtp,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: resendSeconds == 0
                    ? 'Resend OTP'
                    : 'Resend available in $resendSeconds seconds',
                variant: AppButtonVariant.text,
                onPressed: resendSeconds == 0 ? _resendOtp : null,
              ),
              AppButton(
                label: 'Change phone number',
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
