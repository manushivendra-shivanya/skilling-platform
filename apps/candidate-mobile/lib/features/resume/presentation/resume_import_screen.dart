import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure_localization.dart';
import '../../../core/errors/result.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_sticky_footer.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../onboarding/domain/candidate_onboarding_draft.dart';
import '../../onboarding/presentation/candidate_onboarding_controller.dart';
import '../../profile_details/presentation/detailed_profile_controller.dart';
import '../domain/resume_parsing_repository.dart';
import 'resume_extraction_summary.dart';

/// Post-signup entry point for resume-driven profile autofill -- the
/// primary way candidates get their profile filled in, reached right
/// after sign-in (see `AuthenticatedPlaceholderScreen`'s
/// `onContinueToOnboarding`, redirected here through the router's
/// `_continueFromAuthenticated`). Onboarding step 6's narrower
/// `_ResumeUploadStep` still exists as a secondary utility for whoever
/// reaches the wizard without having used this screen -- see its own doc
/// comment.
///
/// Nothing is written anywhere until the candidate reviews an extraction
/// and presses [AppLocalizations.resumeImportConfirmButton] -- pasting
/// text and extracting is free of side effects, and
/// [AppLocalizations.resumeImportSkipButton] is available at every point
/// (before extracting, mid-review, even after a failed save) so a
/// candidate who doesn't have a resume handy, or changes their mind, is
/// never blocked from reaching the wizard.
class ResumeImportScreen extends ConsumerStatefulWidget {
  const ResumeImportScreen({required this.onContinue, super.key});

  /// Always means "proceed into the onboarding wizard" -- there is
  /// nowhere else this screen leads. Called after a skip (nothing
  /// written), a successful confirm (already applied), or dismissing a
  /// partial-apply failure via "Continue anyway".
  final VoidCallback onContinue;

  @override
  ConsumerState<ResumeImportScreen> createState() => _ResumeImportScreenState();
}

class _ResumeImportScreenState extends ConsumerState<ResumeImportScreen> {
  static const _consentVersion = 'resume_import_v1';
  static const _minResumeLength = 40;

  final _resumeController = TextEditingController();
  bool _consentGiven = false;
  bool _isParsing = false;
  bool _isApplying = false;
  bool _applyFailed = false;
  String? _parseErrorMessage;
  String? _applyErrorMessage;
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
    final isBusy = _isParsing || _isApplying;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.resumeImportScreenTitle),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: isBusy ? null : widget.onContinue,
            child: Text(l10n.resumeImportSkipButton),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.upload_file_outlined,
                size: 48,
                color: AppColors.brand,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.resumeImportHeading,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.resumeImportDescription,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(
                key: const ValueKey('resume-import-text-field'),
                label: l10n.onboardingResumeFieldLabel,
                hint: l10n.onboardingResumeFieldHint,
                maxLines: 8,
                controller: _resumeController,
                semanticLabel: l10n.onboardingResumeFieldSemantic,
                enabled: !isBusy,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: CheckboxListTile(
                  value: _consentGiven,
                  onChanged: isBusy
                      ? null
                      : (value) =>
                            setState(() => _consentGiven = value ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(l10n.onboardingResumeConsentTitle),
                  subtitle: Text(l10n.onboardingResumeConsentSubtitle),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                key: const ValueKey('resume-import-extract-button'),
                label: l10n.onboardingResumeExtractButton,
                isLoading: _isParsing,
                onPressed: canExtract ? _extract : null,
              ),
              if (_parseErrorMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _parseErrorMessage!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.error),
                  ),
                ),
              ],
              if (_result != null) ...[
                const SizedBox(height: AppSpacing.lg),
                ResumeExtractionSummary(
                  result: _result!,
                  footerAppliesImmediately: false,
                ),
              ],
              if (_applyErrorMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _applyErrorMessage!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.error),
                  ),
                ),
              ],
              // Bottom padding so the sticky footer below never overlaps
              // the last thing scrolled to.
              if (_result != null) const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _result == null
          ? null
          : AppStickyFooter(
              child: AppButton(
                key: const ValueKey('resume-import-confirm-button'),
                label: _applyFailed
                    ? l10n.resumeImportContinueAnywayButton
                    : l10n.resumeImportConfirmButton,
                isLoading: _isApplying,
                onPressed: _isApplying
                    ? null
                    : (_applyFailed ? widget.onContinue : _confirm),
              ),
            ),
    );
  }

  Future<void> _extract() async {
    setState(() {
      _isParsing = true;
      _parseErrorMessage = null;
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
        _parseErrorMessage = l10n.onboardingResumeSignInAgainError;
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
      },
      failure: (failure) {
        setState(() {
          _isParsing = false;
          _parseErrorMessage = failure.localizedMessage(l10n);
        });
      },
    );
  }

  /// Applies the reviewed extraction to both the onboarding draft
  /// (fullName/city/headline -- never overwriting something the
  /// candidate already has, defensive even though this screen is only
  /// ever reached while the draft is still fresh) and the detailed
  /// profile (phone/email/skills plus every education/work/certification/
  /// project entry). Writes go straight through the repositories rather
  /// than one-at-a-time through `DetailedProfileController` (which
  /// reloads the whole profile after every single mutation) -- a resume
  /// can carry a dozen entries, and reloading after each would mean a
  /// dozen extra round-trips for no benefit here.
  Future<void> _confirm() async {
    final result = _result;
    if (result == null) return;
    setState(() {
      _isApplying = true;
      _applyErrorMessage = null;
      _applyFailed = false;
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
        _isApplying = false;
        _applyFailed = true;
        _applyErrorMessage = l10n.onboardingResumeSignInAgainError;
      });
      return;
    }

    var anyFailure = false;

    final CandidateOnboardingDraft draft = await ref.read(
      candidateOnboardingControllerProvider.future,
    );
    final needsFullName =
        draft.fullName.trim().isEmpty && result.fullName.isNotEmpty;
    final needsCity = draft.city.trim().isEmpty && result.city.isNotEmpty;
    final needsHeadline =
        draft.headline.trim().isEmpty && result.headline.isNotEmpty;
    if (needsFullName || needsCity || needsHeadline) {
      final failure = await ref
          .read(candidateOnboardingControllerProvider.notifier)
          .save(
            draft.copyWith(
              fullName: needsFullName ? result.fullName : null,
              city: needsCity ? result.city : null,
              headline: needsHeadline ? result.headline : null,
            ),
          );
      if (failure != null) anyFailure = true;
    }

    final profileRepository = ref.read(detailedProfileRepositoryProvider);
    final writes = <Future<Result<void>>>[
      if (result.phone.isNotEmpty ||
          result.email.isNotEmpty ||
          result.skills.isNotEmpty)
        profileRepository.saveContactAndSkills(
          candidateId,
          phone: result.phone,
          email: result.email,
          skills: result.skills,
        ),
      for (final entry in result.education)
        profileRepository.upsertEducation(candidateId, entry),
      for (final entry in result.workExperience)
        profileRepository.upsertWorkExperience(candidateId, entry),
      for (final entry in result.certifications)
        profileRepository.upsertCertification(candidateId, entry),
      for (final entry in result.projects)
        profileRepository.upsertProject(candidateId, entry),
    ];
    if (writes.isNotEmpty) {
      final results = await Future.wait(writes);
      if (results.any(
        (r) => r.when(success: (_) => false, failure: (_) => true),
      )) {
        anyFailure = true;
      }
      // The detailed profile page/controller reads its own cached state --
      // invalidate so it reloads from the rows just written instead of
      // showing stale (empty) data the next time it's opened.
      ref.invalidate(detailedProfileControllerProvider);
    }

    if (!mounted) return;
    if (anyFailure) {
      setState(() {
        _isApplying = false;
        _applyFailed = true;
        _applyErrorMessage = l10n.resumeImportApplyFailedMessage;
      });
      return;
    }
    setState(() => _isApplying = false);
    widget.onContinue();
  }
}
