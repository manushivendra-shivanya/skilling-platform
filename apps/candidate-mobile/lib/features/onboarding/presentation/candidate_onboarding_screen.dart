import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_icons.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/network/connectivity_status.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_progress.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/app_status_banner.dart';
import '../../../core/widgets/app_text_field.dart';
import '../domain/candidate_onboarding_draft.dart';
import 'candidate_onboarding_controller.dart';

class CandidateOnboardingScreen extends ConsumerStatefulWidget {
  const CandidateOnboardingScreen({super.key});

  @override
  ConsumerState<CandidateOnboardingScreen> createState() =>
      _CandidateOnboardingScreenState();
}

class _CandidateOnboardingScreenState
    extends ConsumerState<CandidateOnboardingScreen> {
  static const _stepCount = 10;

  final _fullNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pinCodeController = TextEditingController();

  CandidateOnboardingDraft? _workingDraft;
  String? _validationMessage;
  String? _saveMessage;
  bool _isSaving = false;
  bool _termsAccepted = false;
  bool _privacyAccepted = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pinCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draftState = ref.watch(candidateOnboardingControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create your profile'),
        automaticallyImplyLeading:
            _workingDraft?.currentStep != 10 && !_isSaving,
      ),
      body: SafeArea(
        child: draftState.when(
          loading: () => const _OnboardingLoadingView(),
          error: (error, stackTrace) => AppErrorState(
            title: 'We could not open your profile',
            message: error is AppFailure
                ? error.message
                : 'Your saved draft could not be loaded. Please try again.',
            onAction: () => ref
                .read(candidateOnboardingControllerProvider.notifier)
                .retry(),
          ),
          data: (savedDraft) {
            _initialiseDraft(savedDraft);
            return _buildContent(context);
          },
        ),
      ),
    );
  }

  void _initialiseDraft(CandidateOnboardingDraft savedDraft) {
    if (_workingDraft != null) {
      return;
    }
    _workingDraft = savedDraft;
    _fullNameController.text = savedDraft.fullName;
    _cityController.text = savedDraft.city;
    _stateController.text = savedDraft.state;
    _pinCodeController.text = savedDraft.pinCode;
    _termsAccepted =
        savedDraft.consents[OnboardingConsentVersions.termsPurpose]?.version ==
        OnboardingConsentVersions.termsVersion;
    _privacyAccepted =
        savedDraft
            .consents[OnboardingConsentVersions.privacyPurpose]
            ?.version ==
        OnboardingConsentVersions.privacyVersion;
  }

  Widget _buildContent(BuildContext context) {
    final draft = _workingDraft!;
    if (draft.currentStep == 10 || draft.isCompleted) {
      return const _CompletionStep();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppProgress(
                value: (draft.currentStep + 1) / _stepCount,
                label: 'Profile setup',
                detail: 'Step ${draft.currentStep + 1} of $_stepCount',
              ),
              const SizedBox(height: AppSpacing.sm),
              StreamBuilder<ConnectivityStatus>(
                stream: ref.read(connectivityRepositoryProvider).watchStatus(),
                initialData: ref
                    .read(connectivityRepositoryProvider)
                    .currentStatus,
                builder: (context, snapshot) {
                  if (snapshot.data != ConnectivityStatus.offline) {
                    return const SizedBox.shrink();
                  }
                  return const AppOfflineBanner(
                    message:
                        'You are offline. Your profile steps are saved securely on this device.',
                  );
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.xl,
              AppSpacing.md,
            ),
            child: _buildStep(draft),
          ),
        ),
        DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.surfaceMuted)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.xl,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_validationMessage != null || _saveMessage != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _validationMessage ?? _saveMessage!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (_validationMessage != null || _saveMessage != null)
                  const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    if (draft.currentStep > 0) ...[
                      Expanded(
                        child: AppButton(
                          label: 'Back',
                          variant: AppButtonVariant.secondary,
                          isLoading: false,
                          onPressed: _isSaving ? null : _goBack,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(
                      flex: draft.currentStep > 0 ? 1 : 2,
                      child: AppButton(
                        label: draft.currentStep == 9
                            ? 'Complete profile'
                            : 'Save and continue',
                        isLoading: _isSaving,
                        onPressed: _isSaving ? null : _continue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Saved securely on this device after every step.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep(CandidateOnboardingDraft draft) {
    return switch (draft.currentStep) {
      0 => _ChoiceStep<CandidateGoal>(
        title: 'What would you like to achieve?',
        description: 'We will shape your next steps around this goal.',
        values: CandidateGoal.values,
        selected: draft.goal,
        labelFor: (value) => value.label,
        onSelected: (value) => _updateDraft(draft.copyWith(goal: value)),
      ),
      1 => _TextStep(
        title: 'Tell us your name',
        description:
            'Use the name you want employers and training partners to see.',
        fields: [
          AppTextField(
            key: const ValueKey('full-name-field'),
            label: 'Full name',
            controller: _fullNameController,
            textInputAction: TextInputAction.done,
            semanticLabel: 'Full name, required',
          ),
        ],
      ),
      2 => _TextStep(
        title: 'Where are you based?',
        description: 'Location helps us show practical opportunities near you.',
        fields: [
          AppTextField(
            key: const ValueKey('city-field'),
            label: 'City or district',
            controller: _cityController,
            textInputAction: TextInputAction.next,
            semanticLabel: 'City or district, required',
          ),
          AppTextField(
            key: const ValueKey('state-field'),
            label: 'State',
            controller: _stateController,
            textInputAction: TextInputAction.next,
            semanticLabel: 'State, required',
          ),
          AppTextField(
            key: const ValueKey('pin-code-field'),
            label: 'PIN code',
            controller: _pinCodeController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            semanticLabel: 'Six digit PIN code, required',
          ),
        ],
      ),
      3 => _ChoiceStep<EducationLevel>(
        title: 'What is your education level?',
        description: 'Choose the closest option. This is self-reported.',
        values: EducationLevel.values,
        selected: draft.education,
        labelFor: (value) => value.label,
        onSelected: (value) => _updateDraft(draft.copyWith(education: value)),
      ),
      4 => _ChoiceStep<ExperienceLevel>(
        title: 'How much work experience do you have?',
        description:
            'Experience in any role counts. Freshers are welcome here.',
        values: ExperienceLevel.values,
        selected: draft.experience,
        labelFor: (value) => value.label,
        onSelected: (value) => _updateDraft(draft.copyWith(experience: value)),
      ),
      5 => _RolesStep(
        selectedRoles: draft.preferredRoles,
        onChanged: (roles) =>
            _updateDraft(draft.copyWith(preferredRoles: roles)),
      ),
      6 => const _PlaceholderStep(
        icon: Icons.description_outlined,
        title: 'Resume upload',
        description:
            'Resume upload is coming in a later phase. You can complete your profile without one.',
        status: 'Nothing will be uploaded now.',
      ),
      7 => const _PlaceholderStep(
        icon: Icons.mic_none_outlined,
        title: 'Voice introduction',
        description:
            'Voice recording will be added with microphone education and separate recording consent.',
        status: 'The microphone is not accessed in this phase.',
      ),
      8 => _ConsentStep(
        termsAccepted: _termsAccepted,
        privacyAccepted: _privacyAccepted,
        onTermsChanged: (value) =>
            setState(() => _termsAccepted = value ?? false),
        onPrivacyChanged: (value) =>
            setState(() => _privacyAccepted = value ?? false),
      ),
      9 => _ReviewStep(draft: _draftWithTextFields(draft)),
      _ => const SizedBox.shrink(),
    };
  }

  void _updateDraft(CandidateOnboardingDraft draft) {
    setState(() {
      _workingDraft = draft;
      _validationMessage = null;
      _saveMessage = null;
    });
  }

  CandidateOnboardingDraft _draftWithTextFields(
    CandidateOnboardingDraft draft,
  ) {
    return draft.copyWith(
      fullName: _fullNameController.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      pinCode: _pinCodeController.text.trim(),
    );
  }

  Future<void> _continue() async {
    var draft = _draftWithTextFields(_workingDraft!);
    final validationMessage = _validateStep(draft);
    if (validationMessage != null) {
      setState(() {
        _validationMessage = validationMessage;
        _saveMessage = null;
      });
      return;
    }

    if (draft.currentStep == 8) {
      final acceptedAt = DateTime.now().toUtc();
      draft = draft.copyWith(
        consents: {
          OnboardingConsentVersions.termsPurpose: ConsentAcceptance(
            purpose: OnboardingConsentVersions.termsPurpose,
            version: OnboardingConsentVersions.termsVersion,
            acceptedAt: acceptedAt,
          ),
          OnboardingConsentVersions.privacyPurpose: ConsentAcceptance(
            purpose: OnboardingConsentVersions.privacyPurpose,
            version: OnboardingConsentVersions.privacyVersion,
            acceptedAt: acceptedAt,
          ),
        },
      );
    }

    final isCompleting = draft.currentStep == 9;
    final nextDraft = draft.copyWith(
      currentStep: draft.currentStep + 1,
      isCompleted: isCompleting,
    );
    await _save(nextDraft);
  }

  Future<void> _goBack() async {
    final draft = _draftWithTextFields(_workingDraft!);
    await _save(draft.copyWith(currentStep: draft.currentStep - 1));
  }

  Future<void> _save(CandidateOnboardingDraft draft) async {
    setState(() {
      _isSaving = true;
      _validationMessage = null;
      _saveMessage = null;
    });
    final failure = await ref
        .read(candidateOnboardingControllerProvider.notifier)
        .save(draft);
    if (!mounted) {
      return;
    }
    setState(() {
      _isSaving = false;
      if (failure == null) {
        _workingDraft = draft;
      } else {
        _saveMessage = failure.message;
      }
    });
  }

  String? _validateStep(CandidateOnboardingDraft draft) {
    return switch (draft.currentStep) {
      0 when draft.goal == null => 'Choose one goal to continue.',
      1 when draft.fullName.trim().length < 2 =>
        'Enter your full name to continue.',
      2 when draft.city.trim().length < 2 || draft.state.trim().length < 2 =>
        'Enter your city or district and state.',
      2 when !RegExp(r'^\d{6}$').hasMatch(draft.pinCode) =>
        'Enter a valid 6-digit PIN code.',
      3 when draft.education == null => 'Choose your education level.',
      4 when draft.experience == null => 'Choose your work experience.',
      5 when draft.preferredRoles.isEmpty =>
        'Choose at least one preferred role.',
      8 when !_termsAccepted || !_privacyAccepted =>
        'Accept both required notices to continue.',
      9 when !_isCompleteForReview(draft) =>
        'Some required profile details are missing. Go back and review them.',
      _ => null,
    };
  }

  bool _isCompleteForReview(CandidateOnboardingDraft draft) {
    return draft.goal != null &&
        draft.fullName.trim().length >= 2 &&
        draft.city.trim().length >= 2 &&
        draft.state.trim().length >= 2 &&
        RegExp(r'^\d{6}$').hasMatch(draft.pinCode) &&
        draft.education != null &&
        draft.experience != null &&
        draft.preferredRoles.isNotEmpty &&
        draft.hasCurrentRequiredConsents;
  }
}

class _StepHeading extends StatelessWidget {
  const _StepHeading({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          description,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ChoiceStep<T> extends StatelessWidget {
  const _ChoiceStep({
    required this.title,
    required this.description,
    required this.values,
    required this.selected,
    required this.labelFor,
    required this.onSelected,
  });

  final String title;
  final String description;
  final List<T> values;
  final T? selected;
  final String Function(T value) labelFor;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeading(title: title, description: description),
        const SizedBox(height: AppSpacing.xl),
        for (final value in values) ...[
          _SelectableCard(
            label: labelFor(value),
            selected: selected == value,
            onTap: () => onSelected(value),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _TextStep extends StatelessWidget {
  const _TextStep({
    required this.title,
    required this.description,
    required this.fields,
  });

  final String title;
  final String description;
  final List<Widget> fields;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeading(title: title, description: description),
        const SizedBox(height: AppSpacing.xl),
        for (final field in fields) ...[
          field,
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _RolesStep extends StatelessWidget {
  const _RolesStep({required this.selectedRoles, required this.onChanged});

  final Set<LogisticsRole> selectedRoles;
  final ValueChanged<Set<LogisticsRole>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepHeading(
          title: 'Which roles interest you?',
          description:
              'Choose one or more logistics roles. You can change these later.',
        ),
        const SizedBox(height: AppSpacing.xl),
        for (final role in LogisticsRole.values) ...[
          _SelectableCard(
            label: role.label,
            selected: selectedRoles.contains(role),
            onTap: () {
              final updatedRoles = {...selectedRoles};
              if (!updatedRoles.add(role)) {
                updatedRoles.remove(role);
              }
              onChanged(updatedRoles);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      semanticLabel: '$label. ${selected ? 'Selected' : 'Not selected'}',
      onTap: onTap,
      backgroundColor: selected ? AppColors.brandSoft : AppColors.surface,
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.titleMedium),
          ),
          Icon(
            selected ? Icons.check_circle : Icons.radio_button_unchecked,
            color: selected ? AppColors.brand : AppColors.outline,
          ),
        ],
      ),
    );
  }
}

class _PlaceholderStep extends StatelessWidget {
  const _PlaceholderStep({
    required this.icon,
    required this.title,
    required this.description,
    required this.status,
  });

  final IconData icon;
  final String title;
  final String description;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeading(title: title, description: description),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          child: Column(
            children: [
              Icon(icon, size: 56, color: AppColors.brand),
              const SizedBox(height: AppSpacing.md),
              Text(status, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Choose Save and continue to skip this placeholder.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConsentStep extends StatelessWidget {
  const _ConsentStep({
    required this.termsAccepted,
    required this.privacyAccepted,
    required this.onTermsChanged,
    required this.onPrivacyChanged,
  });

  final bool termsAccepted;
  final bool privacyAccepted;
  final ValueChanged<bool?> onTermsChanged;
  final ValueChanged<bool?> onPrivacyChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepHeading(
          title: 'Consent centre',
          description:
              'Review and accept each required notice separately. You can manage consent later.',
        ),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          child: CheckboxListTile(
            value: termsAccepted,
            onChanged: onTermsChanged,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Platform terms'),
            subtitle: const Text(
              'Required • Version ${OnboardingConsentVersions.termsVersion}',
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: CheckboxListTile(
            value: privacyAccepted,
            onChanged: onPrivacyChanged,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Privacy notice'),
            subtitle: const Text(
              'Required • Version ${OnboardingConsentVersions.privacyVersion}',
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'No voice recording or employer evidence-sharing consent is collected here. Those permissions will be requested only when those features are available.',
        ),
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.draft});

  final CandidateOnboardingDraft draft;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepHeading(
          title: 'Review your profile',
          description:
              'Check your details before completing setup. Use Back to make changes.',
        ),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          child: Column(
            children: [
              _ReviewRow(label: 'Goal', value: draft.goal?.label ?? 'Missing'),
              _ReviewRow(label: 'Name', value: draft.fullName),
              _ReviewRow(
                label: 'Location',
                value: '${draft.city}, ${draft.state} • ${draft.pinCode}',
              ),
              _ReviewRow(
                label: 'Education',
                value: draft.education?.label ?? 'Missing',
              ),
              _ReviewRow(
                label: 'Experience',
                value: draft.experience?.label ?? 'Missing',
              ),
              _ReviewRow(
                label: 'Preferred roles',
                value: draft.preferredRoles
                    .map((role) => role.label)
                    .join(', '),
              ),
              _ReviewRow(
                label: 'Required consent',
                value: draft.hasCurrentRequiredConsents
                    ? 'Accepted with current versions'
                    : 'Missing',
                showDivider: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xxs),
        Text(value),
        if (showDivider) ...[
          const SizedBox(height: AppSpacing.sm),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _CompletionStep extends StatelessWidget {
  const _CompletionStep();

  @override
  Widget build(BuildContext context) {
    return const AppStateView(
      icon: AppIcons.success,
      title: 'Your profile is ready',
      message:
          'Your onboarding details and consent versions are saved securely on this device. The Saksham home experience arrives in Phase 1.6.',
      actionLabel: null,
    );
  }
}

class _OnboardingLoadingView extends StatelessWidget {
  const _OnboardingLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeleton(width: 240, height: 28),
          SizedBox(height: AppSpacing.sm),
          AppSkeleton(width: 180, height: 18),
          SizedBox(height: AppSpacing.xl),
          AppSkeleton(height: 72),
          SizedBox(height: AppSpacing.sm),
          AppSkeleton(height: 72),
        ],
      ),
    );
  }
}
