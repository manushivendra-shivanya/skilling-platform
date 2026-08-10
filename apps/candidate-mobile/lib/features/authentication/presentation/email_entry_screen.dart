import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_icons.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
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
    final authState = ref.watch(developmentAuthControllerProvider);
    final isRealBackend = ref.watch(
      appConfigProvider.select((config) => config.hasSupabaseConfiguration),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Email sign-in')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.email_outlined,
                size: 56,
                color: AppColors.brand,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Enter your email address',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                isRealBackend
                    ? 'We will email a one-time code to verify this address.'
                    : 'We will use this only to demonstrate the development OTP flow.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              if (isRealBackend)
                const AppCard(
                  semanticLabel:
                      'Email sign-in requires mail delivery to be enabled on '
                      'the backend. If no code arrives, use Google sign-in '
                      'instead.',
                  backgroundColor: AppColors.infoSoft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(AppIcons.info, color: AppColors.info),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'If your code never arrives, go back and use Google sign-in instead.',
                        ),
                      ),
                    ],
                  ),
                )
              else
                const AppCard(
                  semanticLabel:
                      'Development mode. No email is sent and no production authentication service is connected.',
                  backgroundColor: AppColors.infoSoft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(AppIcons.info, color: AppColors.info),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Development mode: no email is sent. This flow works without a network connection.',
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(
                label: 'Email address',
                controller: _emailController,
                hint: 'name@example.com',
                errorText: authState.failure?.message,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                leadingIcon: Icons.email_outlined,
                enabled: !authState.isRequesting,
                semanticLabel: 'Email address',
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
                label: isRealBackend ? 'Send code' : 'Send development code',
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
                    ? 'Your email is sent to our servers to send you a '
                          'one-time code, and is used to create or resume '
                          'your profile.'
                    : 'Your email is kept only in memory for this mock '
                          'sign-in and is not sent to a server.',
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
