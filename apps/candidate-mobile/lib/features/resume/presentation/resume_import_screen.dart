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
import '../domain/resume_file_picker.dart';
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
/// Also reachable *after* onboarding is complete, from the Detailed
/// Profile page's "Import from resume" action (see
/// `detailedProfileResumeImportRoutePath`) -- [isReimport] covers what's
/// different there: the heading/description talk about updating an
/// existing profile rather than building a first one, and the top-right
/// action reads "Cancel" rather than "Skip for now" (nothing is being
/// skipped from a required flow at that point). The underlying apply
/// logic in [_confirm] needs no branching for this case: the onboarding
/// draft's fullName/city/headline are already filled by then, so the
/// existing never-overwrite check naturally leaves the completed draft
/// alone and only the detailed profile picks up new data.
///
/// Two ways in, deliberately in this order: upload the PDF or Word file
/// the candidate already has, or paste the text. Uploading is offered
/// first because it is what people actually have -- a resume lives as a
/// file, and asking someone to open it, select all and paste on a phone
/// is asking them to do the app's job. The paste field stays as the
/// fallback for a resume that only exists inside an email or a message.
///
/// The two are mutually exclusive at any moment: choosing a file replaces
/// the paste field with the file's card, and removing the file brings the
/// field back. There is deliberately no state where both are filled and
/// the candidate has to guess which one "Extract details" will use.
///
/// Nothing is written anywhere until the candidate reviews an extraction
/// and presses [AppLocalizations.resumeImportConfirmButton] -- choosing a
/// file or pasting text and extracting is free of side effects, and the
/// top-right action is available at every point (before extracting,
/// mid-review, even after a failed save) so a candidate who doesn't have
/// a resume handy, or changes their mind, is never blocked from moving
/// on.
class ResumeImportScreen extends ConsumerStatefulWidget {
  const ResumeImportScreen({
    required this.onContinue,
    this.isReimport = false,
    super.key,
  });

  /// Post-signup (default, [isReimport] false): always means "proceed
  /// into the onboarding wizard". Re-import ([isReimport] true): means
  /// "return to the Detailed Profile page". Called after a skip/cancel
  /// (nothing written), a successful confirm (already applied), or
  /// dismissing a partial-apply failure via "Continue anyway".
  final VoidCallback onContinue;

  /// True when reached from the Detailed Profile page's "Import from
  /// resume" action, after onboarding is already complete. See the class
  /// doc comment for what this changes.
  final bool isReimport;

  @override
  ConsumerState<ResumeImportScreen> createState() => _ResumeImportScreenState();
}

class _ResumeImportScreenState extends ConsumerState<ResumeImportScreen> {
  static const _consentVersion = 'resume_import_v1';
  static const _minResumeLength = 40;

  /// Matches `MAX_RESUME_FILE_BYTES` in `apps/api/src/resume/
  /// resume.service.ts`. Checked here as well as there so an oversized
  /// file is refused before it is base64-encoded and pushed over a mobile
  /// connection, not after.
  static const _maxFileBytes = 5 * 1024 * 1024;

  final _resumeController = TextEditingController();
  bool _consentGiven = false;
  bool _isParsing = false;
  bool _isApplying = false;
  bool _applyFailed = false;
  String? _parseErrorMessage;
  String? _applyErrorMessage;
  ResumeParseResult? _result;
  PickedResumeFile? _pickedFile;

  @override
  void dispose() {
    _resumeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pickedFile = _pickedFile;
    final hasEnoughInput =
        pickedFile != null ||
        _resumeController.text.trim().length >= _minResumeLength;
    final canExtract = _consentGiven && hasEnoughInput && !_isParsing;
    final isBusy = _isParsing || _isApplying;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.resumeImportScreenTitle),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: isBusy ? null : widget.onContinue,
            child: Text(
              widget.isReimport
                  ? l10n.resumeImportCancelButton
                  : l10n.resumeImportSkipButton,
            ),
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
                widget.isReimport
                    ? l10n.resumeImportReimportHeading
                    : l10n.resumeImportHeading,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.isReimport
                    ? l10n.resumeImportReimportDescription
                    : l10n.resumeImportDescription,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              if (pickedFile != null)
                _PickedFileCard(
                  file: pickedFile,
                  onRemove: isBusy
                      ? null
                      : () => setState(() => _pickedFile = null),
                )
              else ...[
                OutlinedButton.icon(
                  key: const ValueKey('resume-import-upload-button'),
                  onPressed: isBusy ? null : _pickFile,
                  icon: const Icon(Icons.attach_file_rounded),
                  // Plain Text, deliberately not wrapped in a Flexible:
                  // OutlinedButton.icon already puts the label in one
                  // (and a second would be competing parent data on the
                  // same render object), so it wraps to a second line on
                  // a narrow screen at a large text scale on its own.
                  label: Text(
                    l10n.resumeImportUploadButton,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  l10n.resumeImportUploadHint,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: AppColors.inkMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    // Flexible so the label wins the space it needs at a
                    // large text scale instead of pushing the row past
                    // the screen edge.
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        child: Text(
                          l10n.resumeImportUploadOrPaste,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: AppColors.inkMuted),
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
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
              ],
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

  /// Opens the device's document picker. Nothing is sent yet -- the file
  /// is held in memory until the candidate presses "Extract details",
  /// same as pasted text, so choosing the wrong file costs nothing.
  Future<void> _pickFile() async {
    final l10n = AppLocalizations.of(context);
    PickedResumeFile? picked;
    try {
      picked = await ref.read(resumeFilePickerProvider).pickResumeFile();
    } on ResumeFileUnreadableException {
      if (!mounted) return;
      setState(() => _parseErrorMessage = l10n.resumeImportFileUnreadableError);
      return;
    }
    // Null means the picker was dismissed without choosing -- an ordinary
    // outcome, so the screen is left exactly as it was.
    if (picked == null || !mounted) return;

    if (picked.sizeInBytes > _maxFileBytes) {
      setState(() => _parseErrorMessage = l10n.resumeImportFileTooLargeError);
      return;
    }
    setState(() {
      _pickedFile = picked;
      _parseErrorMessage = null;
      // A previous extraction belonged to the previous input; leaving it
      // on screen under a newly chosen file would misattribute it.
      _result = null;
      _applyErrorMessage = null;
      _applyFailed = false;
    });
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

    final repository = ref.read(resumeParsingRepositoryProvider);
    final file = _pickedFile;
    final result = file != null
        ? await repository.parseDocument(
            ResumeDocumentParseRequest(
              candidateId: candidateId,
              fileName: file.name,
              bytes: file.bytes,
              consentVersion: _consentVersion,
            ),
          )
        : await repository.parse(
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

  /// Applies the reviewed extraction to the onboarding draft
  /// (fullName/city/headline), the detailed profile's identity fields
  /// (headline again -- see `DetailedCandidateProfile.headline`'s doc
  /// comment on the duplication -- plus totalExperience), and the
  /// detailed profile's list sections (phone/email/skills plus every
  /// education/work/certification/project entry). Every never-overwrite
  /// check compares against that field's *own* current value, not the
  /// draft's, since headline and totalExperience live in two different
  /// places that can each independently already be filled or empty.
  /// Writes go straight through the repositories rather than one-at-a-
  /// time through `DetailedProfileController` (which reloads the whole
  /// profile after every single mutation) -- a resume can carry a dozen
  /// entries, and reloading after each would mean a dozen extra
  /// round-trips for no benefit here.
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

    final currentProfile = await ref.read(
      detailedProfileControllerProvider.future,
    );
    final needsProfileHeadline =
        currentProfile.headline.trim().isEmpty && result.headline.isNotEmpty;
    // The one bug this closes: `yearsOfExperience` has always been
    // extracted and shown in the review summary above, but until
    // `saveProfileBasics` existed there was no column to save it into --
    // it was read once and discarded on confirm.
    final needsTotalExperience =
        currentProfile.totalExperience.trim().isEmpty &&
        result.yearsOfExperience.isNotEmpty;

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
      // `summary` is never touched here -- resumes aren't parsed for it
      // (see `DetailedCandidateProfile.summary`'s own doc comment), so
      // this always carries the candidate's current value forward rather
      // than blanking it.
      if (needsProfileHeadline || needsTotalExperience)
        profileRepository.saveProfileBasics(
          candidateId,
          headline: needsProfileHeadline
              ? result.headline
              : currentProfile.headline,
          summary: currentProfile.summary,
          totalExperience: needsTotalExperience
              ? result.yearsOfExperience
              : currentProfile.totalExperience,
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

/// Confirms which file is about to be read, and offers a way back out.
///
/// It replaces the paste field rather than sitting alongside it, so the
/// screen only ever has one live input -- see the screen's own doc
/// comment.
class _PickedFileCard extends StatelessWidget {
  const _PickedFileCard({required this.file, required this.onRemove});

  final PickedResumeFile file;

  /// Null while a parse is in flight -- removing the file mid-request
  /// would leave the reply with nothing to attach itself to.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppCard(
      key: const ValueKey('resume-import-picked-file'),
      child: Row(
        children: [
          const Icon(Icons.description_outlined, color: AppColors.brand),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _readableSize(file.sizeInBytes),
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
          TextButton(
            key: const ValueKey('resume-import-remove-file-button'),
            onPressed: onRemove,
            child: Text(l10n.resumeImportRemoveFileButton),
          ),
        ],
      ),
    );
  }

  /// Deliberately not localized through ARB: "KB"/"MB" are used verbatim
  /// in Hindi and Hinglish too, and a plural-aware message for a unit
  /// nobody translates would be ceremony for no reader.
  static String _readableSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
