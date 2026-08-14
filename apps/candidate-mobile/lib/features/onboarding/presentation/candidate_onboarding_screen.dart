import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_icons.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/app_failure_localization.dart';
import '../../../core/network/connectivity_status.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_icon_plate.dart';
import '../../../core/widgets/app_progress.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/app_status_banner.dart';
import '../../../core/widgets/app_sticky_footer.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../resume/domain/resume_parsing_repository.dart';
import '../domain/candidate_onboarding_draft.dart';
import 'candidate_onboarding_controller.dart';
import 'candidate_onboarding_labels.dart';

class CandidateOnboardingScreen extends ConsumerStatefulWidget {
  const CandidateOnboardingScreen({required this.onContinueToHome, super.key});

  final VoidCallback onContinueToHome;

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
    final l10n = AppLocalizations.of(context);
    final draftState = ref.watch(candidateOnboardingControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.onboardingWizardAppBarTitle),
        automaticallyImplyLeading:
            _workingDraft?.currentStep != 10 && !_isSaving,
      ),
      body: SafeArea(
        child: draftState.when(
          loading: () => const _OnboardingLoadingView(),
          error: (error, stackTrace) => AppErrorState(
            title: l10n.onboardingWizardLoadErrorTitle,
            message: error is AppFailure
                ? error.localizedMessage(l10n)
                : l10n.onboardingWizardLoadErrorFallback,
            onAction: () => ref
                .read(candidateOnboardingControllerProvider.notifier)
                .retry(),
          ),
          data: (savedDraft) {
            _initialiseDraft(savedDraft);
            return _buildContent(context, l10n);
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

  Widget _buildContent(BuildContext context, AppLocalizations l10n) {
    final draft = _workingDraft!;
    if (draft.currentStep == 10 || draft.isCompleted) {
      return _CompletionStep(onContinueToHome: widget.onContinueToHome);
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
                label: l10n.onboardingWizardProgressLabel,
                detail: l10n.homeMissionStep(draft.currentStep + 1, _stepCount),
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
                  return AppOfflineBanner(
                    message: l10n.onboardingWizardOfflineMessage,
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
            child: _buildStep(draft, l10n),
          ),
        ),
        AppStickyFooter(
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
                        label: l10n.onboardingWizardBackButton,
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
                          ? l10n.onboardingWizardCompleteButton
                          : l10n.onboardingWizardSaveContinueButton,
                      isLoading: _isSaving,
                      onPressed: _isSaving ? null : _continue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.onboardingWizardSavedLocallyNote,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Maps this same currentStep switch to a step-type icon rather than
  // introducing a second, parallel switch: a choice/select step (goal,
  // education, experience, roles) gets a checklist icon, a text-entry step
  // (name, location) gets a person/pencil icon, and the remaining steps --
  // resume upload, the coming-soon voice step, consent, review -- each get
  // an icon obvious for their own content. See `_StepHeading`.
  Widget _buildStep(CandidateOnboardingDraft draft, AppLocalizations l10n) {
    return switch (draft.currentStep) {
      0 => _ChoiceStep<CandidateGoal>(
        icon: Icons.checklist_rounded,
        title: l10n.onboardingGoalStepTitle,
        description: l10n.onboardingGoalStepDescription,
        values: CandidateGoal.values,
        selected: draft.goal,
        labelFor: (value) => candidateGoalLabel(value, l10n),
        onSelected: (value) => _updateDraft(draft.copyWith(goal: value)),
      ),
      1 => _TextStep(
        icon: Icons.person_outline,
        title: l10n.onboardingNameStepTitle,
        description: l10n.onboardingNameStepDescription,
        fields: [
          AppTextField(
            key: const ValueKey('full-name-field'),
            label: l10n.onboardingFullNameFieldLabel,
            controller: _fullNameController,
            textInputAction: TextInputAction.done,
            semanticLabel: l10n.onboardingFullNameFieldSemantic,
          ),
        ],
      ),
      2 => _TextStep(
        icon: Icons.edit_outlined,
        title: l10n.onboardingLocationStepTitle,
        description: l10n.onboardingLocationStepDescription,
        fields: [
          AppTextField(
            key: const ValueKey('city-field'),
            label: l10n.onboardingCityFieldLabel,
            controller: _cityController,
            textInputAction: TextInputAction.next,
            semanticLabel: l10n.onboardingCityFieldSemantic,
          ),
          AppTextField(
            key: const ValueKey('state-field'),
            label: l10n.onboardingStateFieldLabel,
            controller: _stateController,
            textInputAction: TextInputAction.next,
            semanticLabel: l10n.onboardingStateFieldSemantic,
          ),
          AppTextField(
            key: const ValueKey('pin-code-field'),
            label: l10n.onboardingPinCodeFieldLabel,
            controller: _pinCodeController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            semanticLabel: l10n.onboardingPinCodeFieldSemantic,
          ),
        ],
      ),
      3 => _ChoiceStep<EducationLevel>(
        icon: Icons.checklist_rounded,
        title: l10n.onboardingEducationStepTitle,
        description: l10n.onboardingEducationStepDescription,
        values: EducationLevel.values,
        selected: draft.education,
        labelFor: (value) => educationLevelLabel(value, l10n),
        onSelected: (value) => _updateDraft(draft.copyWith(education: value)),
      ),
      4 => _ChoiceStep<ExperienceLevel>(
        icon: Icons.checklist_rounded,
        title: l10n.onboardingExperienceStepTitle,
        description: l10n.onboardingExperienceStepDescription,
        values: ExperienceLevel.values,
        selected: draft.experience,
        labelFor: (value) => experienceLevelLabel(value, l10n),
        onSelected: (value) => _updateDraft(draft.copyWith(experience: value)),
      ),
      5 => _RolesStep(
        selectedRoles: draft.preferredRoles,
        onChanged: (roles) =>
            _updateDraft(draft.copyWith(preferredRoles: roles)),
      ),
      6 => _ResumeUploadStep(
        onFullNameExtracted: _applyExtractedFullName,
        onHeadlineExtracted: _applyExtractedHeadline,
      ),
      7 => _ComingSoonStep(
        icon: Icons.mic_none_outlined,
        title: l10n.onboardingVoiceStepTitle,
        description: l10n.onboardingVoiceStepDescription,
        note: l10n.onboardingVoiceStepNote,
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

  /// Bridges a resume-extracted name back onto the same controller step 1
  /// (Tell us your name) reads from -- only fills it in when the
  /// candidate hasn't already typed one, so a resume parsed after
  /// already entering a name never silently overwrites it.
  void _applyExtractedFullName(String name) {
    if (_fullNameController.text.trim().isNotEmpty) return;
    setState(() => _fullNameController.text = name);
  }

  /// Same non-clobbering rule as [_applyExtractedFullName], but writes
  /// straight onto the draft rather than a text controller -- `headline`
  /// has no dedicated onboarding step of its own, so there's no field for
  /// the candidate to have already typed into; the check is only against
  /// whatever an earlier resume-parse attempt may have already filled in.
  void _applyExtractedHeadline(String headline) {
    final draft = _workingDraft;
    if (draft == null || draft.headline.trim().isNotEmpty) return;
    _updateDraft(draft.copyWith(headline: headline));
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
    final validationMessage = _validateStep(
      draft,
      AppLocalizations.of(context),
    );
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
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isSaving = false;
      if (failure == null) {
        _workingDraft = draft;
      } else {
        _saveMessage = failure.localizedMessage(l10n);
      }
    });
  }

  String? _validateStep(CandidateOnboardingDraft draft, AppLocalizations l10n) {
    return switch (draft.currentStep) {
      0 when draft.goal == null => l10n.onboardingValidationChooseGoal,
      1 when draft.fullName.trim().length < 2 =>
        l10n.onboardingValidationFullName,
      2 when draft.city.trim().length < 2 || draft.state.trim().length < 2 =>
        l10n.onboardingValidationCityState,
      2 when !RegExp(r'^\d{6}$').hasMatch(draft.pinCode) =>
        l10n.onboardingValidationPinCode,
      3 when draft.education == null => l10n.onboardingValidationEducation,
      4 when draft.experience == null => l10n.onboardingValidationExperience,
      5 when draft.preferredRoles.isEmpty => l10n.onboardingValidationRoles,
      8 when !_termsAccepted || !_privacyAccepted =>
        l10n.onboardingValidationConsent,
      9 when !_isCompleteForReview(draft) =>
        l10n.onboardingValidationReviewIncomplete,
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
  const _StepHeading({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIconPlate(
          icon: icon,
          background: AppColors.brandSoft,
          foreground: AppColors.brand,
        ),
        const SizedBox(height: AppSpacing.sm),
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
    required this.icon,
    required this.title,
    required this.description,
    required this.values,
    required this.selected,
    required this.labelFor,
    required this.onSelected,
  });

  final IconData icon;
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
        _StepHeading(icon: icon, title: title, description: description),
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
    required this.icon,
    required this.title,
    required this.description,
    required this.fields,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<Widget> fields;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeading(icon: icon, title: title, description: description),
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
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeading(
          icon: Icons.checklist_rounded,
          title: l10n.onboardingRolesStepTitle,
          description: l10n.onboardingRolesStepDescription,
        ),
        const SizedBox(height: AppSpacing.xl),
        for (final role in LogisticsRole.values) ...[
          _SelectableCard(
            label: logisticsRoleLabel(role, l10n),
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
    final l10n = AppLocalizations.of(context);
    return AppCard(
      semanticLabel:
          '$label. '
          '${selected ? l10n.languageSelectionCardSelected : l10n.languageSelectionCardNotSelected}',
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

/// Onboarding step 6's real implementation, replacing the former "coming
/// in a later phase" placeholder. Works on pasted resume text, not a
/// file upload -- see `ResumeParseRequest.resumeText`'s doc comment for
/// why file upload isn't in this slice.
///
/// Consent here is a single, per-action checkbox
/// (`_consentVersion`/local `_consentGiven` state), not wired into the
/// versioned platform consent system (`OnboardingConsentVersions`,
/// collected at step 8 -- *after* this step). Requiring that consent here
/// would ask for it before it exists in the flow. A scoped, visible
/// checkbox gives the candidate real, informed control over this one
/// action without reordering onboarding or extending the versioned
/// consent system for a single new purpose.
///
/// Only `fullName` and `headline` are ever written back onto the draft
/// (see `_CandidateOnboardingScreenState._applyExtractedFullName` and
/// `_applyExtractedHeadline`). Every other extracted field is shown for
/// the candidate's own reference only -- `CandidateOnboardingDraft` has
/// no columns for work history, skills, phone, or email, and adding them
/// is a real schema decision this step doesn't make on its own. `headline`
/// feeds the Professional Persona networking card (features/persona/).
class _ResumeUploadStep extends ConsumerStatefulWidget {
  const _ResumeUploadStep({
    required this.onFullNameExtracted,
    required this.onHeadlineExtracted,
  });

  final ValueChanged<String> onFullNameExtracted;
  final ValueChanged<String> onHeadlineExtracted;

  @override
  ConsumerState<_ResumeUploadStep> createState() => _ResumeUploadStepState();
}

class _ResumeUploadStepState extends ConsumerState<_ResumeUploadStep> {
  static const _consentVersion = 'resume_parse_v1';
  static const _minResumeLength = 40;

  final _resumeController = TextEditingController();
  bool _consentGiven = false;
  bool _isParsing = false;
  String? _errorMessage;
  ResumeParseResult? _result;

  @override
  void dispose() {
    _resumeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canExtract =
        _consentGiven &&
        _resumeController.text.trim().length >= _minResumeLength &&
        !_isParsing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeading(
          icon: Icons.upload_file_outlined,
          title: l10n.onboardingResumeStepTitle,
          description: l10n.onboardingResumeStepDescription,
        ),
        const SizedBox(height: AppSpacing.xl),
        AppTextField(
          key: const ValueKey('resume-text-field'),
          label: l10n.onboardingResumeFieldLabel,
          hint: l10n.onboardingResumeFieldHint,
          maxLines: 8,
          controller: _resumeController,
          semanticLabel: l10n.onboardingResumeFieldSemantic,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: CheckboxListTile(
            value: _consentGiven,
            onChanged: (value) =>
                setState(() => _consentGiven = value ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(l10n.onboardingResumeConsentTitle),
            subtitle: Text(l10n.onboardingResumeConsentSubtitle),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: l10n.onboardingResumeExtractButton,
          isLoading: _isParsing,
          onPressed: canExtract ? _extract : null,
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            liveRegion: true,
            child: Text(
              _errorMessage!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.error),
            ),
          ),
        ],
        if (_result != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _ResumeExtractionSummary(result: _result!),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.onboardingResumeFooterNote,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Future<void> _extract() async {
    setState(() {
      _isParsing = true;
      _errorMessage = null;
    });
    final l10n = AppLocalizations.of(context);

    final sessionResult = await ref
        .read(candidateSessionRepositoryProvider)
        .readSession();
    final candidateId = sessionResult.when(
      success: (session) => session?.candidateId,
      failure: (_) => null,
    );
    if (candidateId == null) {
      if (!mounted) return;
      setState(() {
        _isParsing = false;
        _errorMessage = l10n.onboardingResumeSignInAgainError;
      });
      return;
    }

    final result = await ref
        .read(resumeParsingRepositoryProvider)
        .parse(
          ResumeParseRequest(
            candidateId: candidateId,
            resumeText: _resumeController.text.trim(),
            consentVersion: _consentVersion,
          ),
        );
    if (!mounted) return;
    result.when(
      success: (parsed) {
        setState(() {
          _isParsing = false;
          _result = parsed;
        });
        final extractedName = parsed.fields['fullName']?.trim();
        if (extractedName != null && extractedName.isNotEmpty) {
          widget.onFullNameExtracted(extractedName);
        }
        final extractedHeadline = parsed.fields['headline']?.trim();
        if (extractedHeadline != null && extractedHeadline.isNotEmpty) {
          widget.onHeadlineExtracted(extractedHeadline);
        }
      },
      failure: (failure) {
        setState(() {
          _isParsing = false;
          _errorMessage = failure.localizedMessage(l10n);
        });
      },
    );
  }
}

class _ResumeExtractionSummary extends StatelessWidget {
  const _ResumeExtractionSummary({required this.result});

  final ResumeParseResult result;

  Map<String, String> _fieldLabels(AppLocalizations l10n) => {
    'fullName': l10n.onboardingFullNameFieldLabel,
    'phone': l10n.onboardingResumeFieldPhone,
    'email': l10n.onboardingResumeFieldEmail,
    'city': l10n.onboardingResumeFieldCity,
    'headline': l10n.onboardingResumeFieldHeadline,
    'yearsOfExperience': l10n.onboardingResumeFieldExperience,
    'education': l10n.onboardingResumeFieldEducation,
    'workHistory': l10n.onboardingResumeFieldWorkHistory,
    'skills': l10n.onboardingResumeFieldSkills,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fieldLabels = _fieldLabels(l10n);
    final populated = fieldLabels.entries
        .where((entry) => (result.fields[entry.key]?.trim() ?? '').isNotEmpty)
        .toList(growable: false);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.onboardingResumeSummaryHeading,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          if (result.requiresCandidateReview)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                l10n.onboardingResumeReviewWarning,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          if (populated.isEmpty)
            Text(l10n.onboardingResumeEmptyState)
          else
            for (final entry in populated) ...[
              Text(
                fieldLabels[entry.key]!,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              Text(result.fields[entry.key]!.trim()),
              const SizedBox(height: AppSpacing.sm),
            ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.fields['fullName']?.trim().isNotEmpty ?? false
                ? l10n.onboardingResumeFooterNameFilled
                : l10n.onboardingResumeFooterPreviewOnly,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A step whose real content isn't built yet -- says so honestly, in
/// plain candidate-facing language, rather than the internal word
/// "placeholder" or instructions phrased as if the candidate were
/// debugging the app ("skip this placeholder"). [note] is the one thing
/// worth telling the candidate about *why* this screen is empty (e.g. a
/// permission that genuinely isn't requested yet); the "nothing to do
/// here" line below it is constant across every use.
class _ComingSoonStep extends StatelessWidget {
  const _ComingSoonStep({
    required this.icon,
    required this.title,
    required this.description,
    required this.note,
  });

  final IconData icon;
  final String title;
  final String description;
  final String note;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeading(icon: icon, title: title, description: description),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          child: Column(
            children: [
              Icon(icon, size: 56, color: AppColors.brand),
              const SizedBox(height: AppSpacing.md),
              Text(note, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.onboardingComingSoonFooter,
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
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeading(
          icon: Icons.lock_outline,
          title: l10n.onboardingConsentStepTitle,
          description: l10n.onboardingConsentStepDescription,
        ),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckboxListTile(
                value: termsAccepted,
                onChanged: onTermsChanged,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(l10n.onboardingTermsCheckboxTitle),
                subtitle: Text(
                  l10n.onboardingConsentRequiredVersion(
                    OnboardingConsentVersions.termsVersion,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xl),
                child: AppStatusChip(
                  // Same boolean the checkbox above reads -- rendered with
                  // more visual weight alongside it, not instead of it.
                  label: termsAccepted
                      ? l10n.onboardingConsentAccepted
                      : l10n.onboardingConsentNotYetAccepted,
                  tone: termsAccepted
                      ? AppChipTone.success
                      : AppChipTone.warning,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckboxListTile(
                value: privacyAccepted,
                onChanged: onPrivacyChanged,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(l10n.onboardingPrivacyCheckboxTitle),
                subtitle: Text(
                  l10n.onboardingConsentRequiredVersion(
                    OnboardingConsentVersions.privacyVersion,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xl),
                child: AppStatusChip(
                  label: privacyAccepted
                      ? l10n.onboardingConsentAccepted
                      : l10n.onboardingConsentNotYetAccepted,
                  tone: privacyAccepted
                      ? AppChipTone.success
                      : AppChipTone.warning,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.onboardingConsentFooterNote),
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.draft});

  final CandidateOnboardingDraft draft;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeading(
          icon: Icons.description_outlined,
          title: l10n.onboardingReviewStepTitle,
          description: l10n.onboardingReviewStepDescription,
        ),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          child: Column(
            children: [
              _ReviewRow(
                label: l10n.onboardingReviewGoalLabel,
                value: draft.goal == null
                    ? l10n.onboardingReviewMissing
                    : candidateGoalLabel(draft.goal!, l10n),
              ),
              _ReviewRow(
                label: l10n.onboardingReviewNameLabel,
                value: draft.fullName,
              ),
              _ReviewRow(
                label: l10n.onboardingReviewLocationLabel,
                value: '${draft.city}, ${draft.state} • ${draft.pinCode}',
              ),
              _ReviewRow(
                label: l10n.onboardingReviewEducationLabel,
                value: draft.education == null
                    ? l10n.onboardingReviewMissing
                    : educationLevelLabel(draft.education!, l10n),
              ),
              _ReviewRow(
                label: l10n.onboardingReviewExperienceLabel,
                value: draft.experience == null
                    ? l10n.onboardingReviewMissing
                    : experienceLevelLabel(draft.experience!, l10n),
              ),
              _ReviewRow(
                label: l10n.onboardingReviewRolesLabel,
                value: draft.preferredRoles
                    .map((role) => logisticsRoleLabel(role, l10n))
                    .join(', '),
              ),
              _ReviewRow(
                label: l10n.onboardingReviewConsentLabel,
                value: draft.hasCurrentRequiredConsents
                    ? l10n.onboardingReviewConsentAccepted
                    : l10n.onboardingReviewMissing,
                // Same `hasCurrentRequiredConsents` boolean as `value` above,
                // promoted to a status chip -- this is a hard completion
                // gate (see `_isCompleteForReview`), so it earns more visual
                // weight than the plain-text rows around it.
                valueChip: AppStatusChip(
                  label: draft.hasCurrentRequiredConsents
                      ? l10n.onboardingReviewConsentAccepted
                      : l10n.onboardingReviewMissing,
                  tone: draft.hasCurrentRequiredConsents
                      ? AppChipTone.success
                      : AppChipTone.warning,
                ),
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
    this.valueChip,
    this.showDivider = true,
  });

  final String label;
  final String value;

  /// When set, replaces the plain [value] text with a status chip -- same
  /// underlying data as [value], just given more visual weight. [value] is
  /// still required even then, so every row keeps one unambiguous source of
  /// truth for its own semantics/testing.
  final Widget? valueChip;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xxs),
        // `Align` keeps the chip at its natural width -- this Column
        // stretches its children, which would otherwise force the chip's
        // visible rounded box to span the full row width.
        valueChip != null
            ? Align(alignment: Alignment.centerLeft, child: valueChip)
            : Text(value),
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
  const _CompletionStep({required this.onContinueToHome});

  final VoidCallback onContinueToHome;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppStateView(
      icon: AppIcons.success,
      title: l10n.onboardingCompletionTitle,
      message: l10n.onboardingCompletionMessage,
      actionLabel: l10n.onboardingCompletionAction,
      onAction: onContinueToHome,
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
