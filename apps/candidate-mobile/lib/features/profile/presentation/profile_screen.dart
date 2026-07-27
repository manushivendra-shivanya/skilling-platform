import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../authentication/presentation/candidate_session_controller.dart';
import '../../authentication/presentation/development_auth_controller.dart';
import '../../onboarding/domain/candidate_onboarding_draft.dart';
import '../../onboarding/presentation/candidate_onboarding_controller.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({required this.onLoggedOut, super.key});

  final VoidCallback onLoggedOut;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _employerVisibility = false;
  bool _notificationsEnabled = false;
  bool _loggingOut = false;

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(candidateOnboardingControllerProvider);
    return draft.when(
      loading: () => const _ProfileLoadingView(),
      error: (error, stackTrace) => AppErrorState(
        title: 'Profile could not be loaded',
        message: error is AppFailure
            ? error.message
            : 'Your secure local profile is temporarily unavailable.',
        onAction: () =>
            ref.read(candidateOnboardingControllerProvider.notifier).retry(),
      ),
      data: _buildProfile,
    );
  }

  Widget _buildProfile(CandidateOnboardingDraft draft) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        112,
      ),
      children: [
        Text(draft.fullName, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xxs),
        Text('${draft.city}, ${draft.state}'),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Edit personal details',
          variant: AppButtonVariant.secondary,
          onPressed: () => _editDetails(draft),
        ),
        const SizedBox(height: AppSpacing.lg),
        _Section(
          title: 'Career profile',
          children: [
            _DetailRow(label: 'Goal', value: draft.goal?.label ?? 'Not set'),
            _DetailRow(
              label: 'Education',
              value: draft.education?.label ?? 'Not set',
            ),
            _DetailRow(
              label: 'Experience',
              value: draft.experience?.label ?? 'Not set',
            ),
            _DetailRow(
              label: 'Preferred roles',
              value: draft.preferredRoles.map((role) => role.label).join(', '),
            ),
            const _DetailRow(
              label: 'Evidence',
              value: 'No verified evidence yet',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _Section(
          title: 'Privacy and consent',
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _employerVisibility,
              onChanged: (value) => setState(() => _employerVisibility = value),
              title: const Text('Employer profile visibility'),
              subtitle: const Text(
                'Local preview only. No employer receives data in Phase 1.',
              ),
            ),
            _DetailRow(
              label: 'Platform terms',
              value:
                  draft
                      .consents[OnboardingConsentVersions.termsPurpose]
                      ?.version ??
                  'Not accepted',
            ),
            _DetailRow(
              label: 'Privacy notice',
              value:
                  draft
                      .consents[OnboardingConsentVersions.privacyPurpose]
                      ?.version ??
                  'Not accepted',
            ),
            const _DetailRow(
              label: 'Voice and employer sharing',
              value: 'Requested separately when those features are used',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _Section(
          title: 'Preferences and support',
          children: [
            const _DetailRow(label: 'Language', value: 'English'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _notificationsEnabled,
              onChanged: (value) =>
                  setState(() => _notificationsEnabled = value),
              title: const Text('Notification preference'),
              subtitle: const Text(
                'Local preview only. No push token is registered.',
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.help_outline),
              title: const Text('Help and support'),
              onTap: () => showAppSnackBar(
                context: context,
                message:
                    'Support contact workflow will be connected in a later phase.',
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('Request account deletion'),
              subtitle: const Text('Placeholder • no request is sent'),
              onTap: _showDeletionPlaceholder,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Log out',
          variant: AppButtonVariant.secondary,
          isLoading: _loggingOut,
          onPressed: _loggingOut ? null : _logout,
        ),
      ],
    );
  }

  Future<void> _editDetails(CandidateOnboardingDraft draft) async {
    final updated = await showAppBottomSheet<CandidateOnboardingDraft>(
      context: context,
      title: 'Edit personal details',
      child: _EditProfileForm(draft: draft),
    );
    if (updated == null || !mounted) return;
    final failure = await ref
        .read(candidateOnboardingControllerProvider.notifier)
        .save(updated);
    if (!mounted) return;
    showAppSnackBar(
      context: context,
      message: failure?.message ?? 'Profile saved securely on this device.',
      tone: failure == null ? AppMessageTone.success : AppMessageTone.error,
    );
  }

  Future<void> _showDeletionPlaceholder() async {
    await showAppConfirmationDialog(
      context: context,
      title: 'Account deletion is not connected',
      message:
          'No request will be sent in Phase 1. A verified deletion workflow and recovery window are required before this becomes active.',
      confirmLabel: 'I understand',
      cancelLabel: 'Close',
      isDestructive: true,
    );
  }

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    final failure = await ref
        .read(candidateSessionControllerProvider.notifier)
        .logout();
    if (!mounted) return;
    if (failure == null) {
      ref.read(developmentAuthControllerProvider.notifier).clear();
      ref.invalidate(candidateOnboardingControllerProvider);
      widget.onLoggedOut();
    } else {
      setState(() => _loggingOut = false);
      showAppSnackBar(
        context: context,
        message: failure.message,
        tone: AppMessageTone.error,
      );
    }
  }
}

class _EditProfileForm extends StatefulWidget {
  const _EditProfileForm({required this.draft});

  final CandidateOnboardingDraft draft;

  @override
  State<_EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends State<_EditProfileForm> {
  late final TextEditingController _name;
  late final TextEditingController _city;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.draft.fullName);
    _city = TextEditingController(text: widget.draft.city);
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Full name'),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _city,
          decoration: const InputDecoration(labelText: 'City or district'),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(_error!, style: const TextStyle(color: AppColors.error)),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(label: 'Save changes', onPressed: _submit),
        const SizedBox(height: AppSpacing.sm),
        const AppBottomSheetCloseButton(),
      ],
    );
  }

  void _submit() {
    if (_name.text.trim().length < 2 || _city.text.trim().length < 2) {
      setState(() => _error = 'Enter a valid name and city.');
      return;
    }
    Navigator.of(context).pop(
      widget.draft.copyWith(
        fullName: _name.text.trim(),
        city: _city.text.trim(),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const Divider(),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xxs),
          Text(value.isEmpty ? 'Not set' : value),
        ],
      ),
    );
  }
}

class _ProfileLoadingView extends StatelessWidget {
  const _ProfileLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          AppSkeleton(height: 80),
          SizedBox(height: AppSpacing.md),
          AppSkeleton(height: 200),
        ],
      ),
    );
  }
}
