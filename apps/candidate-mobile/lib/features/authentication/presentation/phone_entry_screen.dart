import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_icons.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import 'development_auth_controller.dart';

class PhoneEntryScreen extends ConsumerStatefulWidget {
  const PhoneEntryScreen({required this.onOtpRequested, super.key});

  final VoidCallback onOtpRequested;

  @override
  ConsumerState<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends ConsumerState<PhoneEntryScreen> {
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    final succeeded = await ref
        .read(developmentAuthControllerProvider.notifier)
        .requestOtp(_phoneController.text);
    if (succeeded && mounted) {
      widget.onOtpRequested();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(developmentAuthControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Phone sign-in')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.phone_android, size: 56, color: AppColors.brand),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Enter your mobile number',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'We will use this only to demonstrate the development OTP flow.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              const AppCard(
                semanticLabel:
                    'Development mode. No SMS is sent and no production authentication service is connected.',
                backgroundColor: AppColors.infoSoft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(AppIcons.info, color: AppColors.info),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Development mode: no SMS is sent. This flow works without a network connection.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(
                label: '10-digit mobile number',
                controller: _phoneController,
                hint: '9876543210',
                helperText: 'India (+91)',
                errorText: authState.failure?.message,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                leadingIcon: Icons.phone_outlined,
                enabled: !authState.isRequesting,
                semanticLabel: 'Indian mobile number, 10 digits',
                onSubmitted: (_) => _requestOtp(),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Send development OTP',
                isLoading: authState.isRequesting,
                onPressed: _requestOtp,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Your number is kept only in memory for this mock sign-in and is not sent to a server.',
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
