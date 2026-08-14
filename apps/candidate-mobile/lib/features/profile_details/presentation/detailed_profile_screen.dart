import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/app_failure_localization.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_meter_bar.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/detailed_candidate_profile.dart';
import 'detailed_profile_controller.dart';

/// The LinkedIn-style detailed profile: contact info, skills, and the
/// candidate's Career Journey (experience, education, certifications,
/// projects), each independently add/edit/delete-able.
///
/// Unlike Home, every field on this screen is real, backend-persisted data
/// -- see `DetailedProfileController`/`SupabaseDetailedProfileRepository`.
class DetailedProfileScreen extends ConsumerWidget {
  const DetailedProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(detailedProfileControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileDetailsScreenTitle)),
      body: state.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              AppSkeleton(height: 96),
              SizedBox(height: AppSpacing.md),
              AppSkeleton(height: 160),
              SizedBox(height: AppSpacing.md),
              AppSkeleton(height: 160),
            ],
          ),
        ),
        error: (error, stackTrace) => AppErrorState(
          title: l10n.homeLoadErrorTitle,
          message: error is AppFailure
              ? error.localizedMessage(l10n)
              : l10n.homeLoadErrorMessage,
          onAction: () =>
              ref.read(detailedProfileControllerProvider.notifier).retry(),
        ),
        data: (profile) => _DetailedProfileContent(profile: profile),
      ),
    );
  }
}

class _DetailedProfileContent extends ConsumerWidget {
  const _DetailedProfileContent({required this.profile});

  final DetailedCandidateProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(detailedProfileControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          children: [
            Expanded(
              child: AppMeterBar(value: profile.completionPercent / 100),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              l10n.profileDetailsCompletionLabel(profile.completionPercent),
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        _ContactAndSkillsCard(profile: profile, controller: controller),
        const SizedBox(height: AppSpacing.lg),

        _ExperienceSection(profile: profile, controller: controller),
        const SizedBox(height: AppSpacing.lg),

        _EducationSection(profile: profile, controller: controller),
        const SizedBox(height: AppSpacing.lg),

        _CertificationSection(profile: profile, controller: controller),
        const SizedBox(height: AppSpacing.lg),

        _ProjectSection(profile: profile, controller: controller),
      ],
    );
  }
}

/// "MM/YYYY" (zero-padded month) when both are known, bare "YYYY" when
/// only the year is, or '' when neither is -- numeric rather than a
/// localized month name, so this needs no per-locale month-name strings.
String _formatMonthYear(int? month, int? year) {
  if (year == null) return '';
  if (month == null) return '$year';
  return '${month.toString().padLeft(2, '0')}/$year';
}

String _formatDateRange(
  AppLocalizations l10n, {
  required int? startMonth,
  required int? startYear,
  required int? endMonth,
  required int? endYear,
  required bool isOngoing,
}) {
  final start = _formatMonthYear(startMonth, startYear);
  final end = isOngoing
      ? l10n.profileDetailsPresent
      : _formatMonthYear(endMonth, endYear);
  if (start.isEmpty && end.isEmpty) return '';
  if (start.isEmpty) return end;
  if (end.isEmpty) return start;
  return l10n.profileDetailsDateRange(start, end);
}

/// Shows [message] as a snackbar-style banner via [showAppConfirmationDialog]
/// -- reused wherever a mutation fails so every section reports errors the
/// same way rather than each section inventing its own.
void _showFailureSnackbar(BuildContext context, AppFailure failure) {
  final l10n = AppLocalizations.of(context);
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(failure.localizedMessage(l10n))));
}

class _ContactAndSkillsCard extends StatefulWidget {
  const _ContactAndSkillsCard({
    required this.profile,
    required this.controller,
  });

  final DetailedCandidateProfile profile;
  final DetailedProfileController controller;

  @override
  State<_ContactAndSkillsCard> createState() => _ContactAndSkillsCardState();
}

class _ContactAndSkillsCardState extends State<_ContactAndSkillsCard> {
  late final _phoneController = TextEditingController(
    text: widget.profile.phone,
  );
  late final _emailController = TextEditingController(
    text: widget.profile.email,
  );
  late final _skillController = TextEditingController();
  late List<String> _skills = List.of(widget.profile.skills);
  bool _isSaving = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _skillController.dispose();
    super.dispose();
  }

  void _addSkill(String raw) {
    final skill = raw.trim();
    if (skill.isEmpty || _skills.contains(skill)) {
      _skillController.clear();
      return;
    }
    setState(() {
      _skills = [..._skills, skill];
      _skillController.clear();
    });
  }

  void _removeSkill(String skill) {
    setState(() => _skills = _skills.where((s) => s != skill).toList());
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final failure = await widget.controller.saveContactAndSkills(
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      skills: _skills,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (failure != null) _showFailureSnackbar(context, failure);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.profileDetailsContactSectionTitle,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            label: l10n.profileDetailsPhoneLabel,
            controller: _phoneController,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            label: l10n.profileDetailsEmailLabel,
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.profileDetailsSkillsSectionTitle,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_skills.isEmpty)
            Text(
              l10n.profileDetailsSkillsEmpty,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
            )
          else
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xxs,
              children: [
                for (final skill in _skills)
                  InputChip(
                    label: Text(skill),
                    onDeleted: () => _removeSkill(skill),
                  ),
              ],
            ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _skillController,
            hint: l10n.profileDetailsAddSkillHint,
            textInputAction: TextInputAction.done,
            onSubmitted: _addSkill,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: l10n.profileDetailsSaveButton,
            isLoading: _isSaving,
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
    );
  }
}

/// One row shared by every Career Journey section: a title, an optional
/// subtitle (company/institution/organization), an optional formatted date
/// range, and edit/delete icon buttons. Not `AppCard`'s own `onTap` +
/// `semanticLabel` pattern used elsewhere on Home -- this row needs *two*
/// independent tap targets (edit, delete), which a single combined
/// semantic label can't represent as two actionable controls.
class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.title,
    required this.subtitle,
    required this.dateRange,
    required this.onEdit,
    required this.onDelete,
  });

  final String title;
  final String subtitle;
  final String dateRange;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
                  ),
                if (dateRange.isNotEmpty)
                  Text(
                    dateRange,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: l10n.profileDetailsEditSemantic(title),
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              size: 20,
              color: AppColors.error,
            ),
            tooltip: l10n.profileDetailsDeleteSemantic(title),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

Future<bool> _confirmDelete(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showAppConfirmationDialog(
    context: context,
    title: l10n.profileDetailsDeleteConfirmTitle,
    message: l10n.profileDetailsDeleteConfirmMessage,
    confirmLabel: l10n.profileDetailsDeleteButton,
    isDestructive: true,
  );
}

/// A month + year field pair, shared by every date on every Career
/// Journey form. Plain numeric text fields, not a date picker -- a
/// resume or a candidate's own memory rarely supplies a day, and there
/// is no reason to force a full calendar UI on a value this coarse.
class _MonthYearFields extends StatelessWidget {
  const _MonthYearFields({
    required this.monthLabel,
    required this.yearLabel,
    required this.monthController,
    required this.yearController,
  });

  final String monthLabel;
  final String yearLabel;
  final TextEditingController monthController;
  final TextEditingController yearController;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppTextField(
            label: monthLabel,
            controller: monthController,
            keyboardType: TextInputType.number,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: AppTextField(
            label: yearLabel,
            controller: yearController,
            keyboardType: TextInputType.number,
          ),
        ),
      ],
    );
  }
}

/// Parses a month field, clamping to the 1-12 range the schema's own
/// check constraint enforces -- an out-of-range value here would
/// otherwise surface as an opaque save failure instead of being
/// corrected before the request is even sent.
int? _parseMonth(String raw) {
  final value = int.tryParse(raw.trim());
  if (value == null) return null;
  return value.clamp(1, 12);
}

int? _parseYear(String raw) => int.tryParse(raw.trim());

class _ExperienceSection extends StatelessWidget {
  const _ExperienceSection({required this.profile, required this.controller});

  final DetailedCandidateProfile profile;
  final DetailedProfileController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.profileDetailsExperienceSectionTitle,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (profile.workExperience.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                l10n.profileDetailsExperienceEmpty,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
              ),
            )
          else
            for (final entry in profile.workExperience)
              _EntryRow(
                title: entry.title,
                subtitle: entry.company,
                dateRange: _formatDateRange(
                  l10n,
                  startMonth: entry.startMonth,
                  startYear: entry.startYear,
                  endMonth: entry.endMonth,
                  endYear: entry.endYear,
                  isOngoing: entry.isCurrent,
                ),
                onEdit: () =>
                    _showExperienceForm(context, controller, entry: entry),
                onDelete: () async {
                  if (!await _confirmDelete(context)) return;
                  final failure = await controller.deleteWorkExperience(
                    entry.id,
                  );
                  if (context.mounted && failure != null) {
                    _showFailureSnackbar(context, failure);
                  }
                },
              ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: l10n.profileDetailsAddExperienceButton,
            variant: AppButtonVariant.secondary,
            onPressed: () => _showExperienceForm(context, controller),
          ),
        ],
      ),
    );
  }
}

Future<void> _showExperienceForm(
  BuildContext context,
  DetailedProfileController controller, {
  WorkExperienceEntry? entry,
}) {
  final l10n = AppLocalizations.of(context);
  return showAppBottomSheet(
    context: context,
    title: entry == null
        ? l10n.profileDetailsAddExperienceButton
        : l10n.profileDetailsEditSemantic(entry.title),
    child: _ExperienceForm(controller: controller, entry: entry),
  );
}

class _ExperienceForm extends StatefulWidget {
  const _ExperienceForm({required this.controller, this.entry});

  final DetailedProfileController controller;
  final WorkExperienceEntry? entry;

  @override
  State<_ExperienceForm> createState() => _ExperienceFormState();
}

class _ExperienceFormState extends State<_ExperienceForm> {
  late final _title = TextEditingController(text: widget.entry?.title ?? '');
  late final _company = TextEditingController(
    text: widget.entry?.company ?? '',
  );
  late final _location = TextEditingController(
    text: widget.entry?.location ?? '',
  );
  late final _description = TextEditingController(
    text: widget.entry?.description ?? '',
  );
  late final _startMonth = TextEditingController(
    text: widget.entry?.startMonth?.toString() ?? '',
  );
  late final _startYear = TextEditingController(
    text: widget.entry?.startYear?.toString() ?? '',
  );
  late final _endMonth = TextEditingController(
    text: widget.entry?.endMonth?.toString() ?? '',
  );
  late final _endYear = TextEditingController(
    text: widget.entry?.endYear?.toString() ?? '',
  );
  late bool _isCurrent = widget.entry?.isCurrent ?? false;
  bool _isSaving = false;

  @override
  void dispose() {
    for (final c in [
      _title,
      _company,
      _location,
      _description,
      _startMonth,
      _startYear,
      _endMonth,
      _endYear,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _company.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    final entry = WorkExperienceEntry(
      id: widget.entry?.id ?? '',
      title: _title.text.trim(),
      company: _company.text.trim(),
      location: _location.text.trim(),
      description: _description.text.trim(),
      startMonth: _parseMonth(_startMonth.text),
      startYear: _parseYear(_startYear.text),
      endMonth: _parseMonth(_endMonth.text),
      endYear: _parseYear(_endYear.text),
      isCurrent: _isCurrent,
      sequence: widget.entry?.sequence ?? 0,
    );
    final failure = await widget.controller.saveWorkExperience(entry);
    if (!mounted) return;
    if (failure != null) {
      setState(() => _isSaving = false);
      _showFailureSnackbar(context, failure);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          label: l10n.profileDetailsTitleFieldLabel,
          controller: _title,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: l10n.profileDetailsCompanyFieldLabel,
          controller: _company,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: l10n.profileDetailsLocationFieldLabel,
          controller: _location,
        ),
        const SizedBox(height: AppSpacing.sm),
        _MonthYearFields(
          monthLabel: l10n.profileDetailsStartMonthFieldLabel,
          yearLabel: l10n.profileDetailsStartYearFieldLabel,
          monthController: _startMonth,
          yearController: _startYear,
        ),
        const SizedBox(height: AppSpacing.sm),
        CheckboxListTile(
          value: _isCurrent,
          onChanged: (value) => setState(() => _isCurrent = value ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(l10n.profileDetailsCurrentRoleLabel),
        ),
        if (!_isCurrent) ...[
          _MonthYearFields(
            monthLabel: l10n.profileDetailsEndMonthFieldLabel,
            yearLabel: l10n.profileDetailsEndYearFieldLabel,
            monthController: _endMonth,
            yearController: _endYear,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        AppTextField(
          label: l10n.profileDetailsDescriptionFieldLabel,
          controller: _description,
          maxLines: 3,
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: l10n.profileDetailsSaveButton,
          isLoading: _isSaving,
          onPressed: _isSaving ? null : _save,
        ),
      ],
    );
  }
}

class _EducationSection extends StatelessWidget {
  const _EducationSection({required this.profile, required this.controller});

  final DetailedCandidateProfile profile;
  final DetailedProfileController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.profileDetailsEducationSectionTitle,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (profile.education.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                l10n.profileDetailsEducationEmpty,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
              ),
            )
          else
            for (final entry in profile.education)
              _EntryRow(
                // Structured degree + fieldOfStudy joined for display --
                // see EducationEntry's own doc comment for why they're
                // two fields, not one.
                title:
                    [
                      entry.degree,
                      entry.fieldOfStudy,
                    ].where((s) => s.isNotEmpty).join(', ').isEmpty
                    ? entry.institution
                    : [
                        entry.degree,
                        entry.fieldOfStudy,
                      ].where((s) => s.isNotEmpty).join(', '),
                subtitle: entry.institution,
                dateRange: _formatDateRange(
                  l10n,
                  startMonth: null,
                  startYear: entry.startYear,
                  endMonth: null,
                  endYear: entry.endYear,
                  isOngoing: false,
                ),
                onEdit: () =>
                    _showEducationForm(context, controller, entry: entry),
                onDelete: () async {
                  if (!await _confirmDelete(context)) return;
                  final failure = await controller.deleteEducation(entry.id);
                  if (context.mounted && failure != null) {
                    _showFailureSnackbar(context, failure);
                  }
                },
              ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: l10n.profileDetailsAddEducationButton,
            variant: AppButtonVariant.secondary,
            onPressed: () => _showEducationForm(context, controller),
          ),
        ],
      ),
    );
  }
}

Future<void> _showEducationForm(
  BuildContext context,
  DetailedProfileController controller, {
  EducationEntry? entry,
}) {
  final l10n = AppLocalizations.of(context);
  return showAppBottomSheet(
    context: context,
    title: entry == null
        ? l10n.profileDetailsAddEducationButton
        : l10n.profileDetailsEditSemantic(entry.institution),
    child: _EducationForm(controller: controller, entry: entry),
  );
}

class _EducationForm extends StatefulWidget {
  const _EducationForm({required this.controller, this.entry});

  final DetailedProfileController controller;
  final EducationEntry? entry;

  @override
  State<_EducationForm> createState() => _EducationFormState();
}

class _EducationFormState extends State<_EducationForm> {
  late final _institution = TextEditingController(
    text: widget.entry?.institution ?? '',
  );
  // Structured, not free text -- see EducationEntry's own doc comment.
  // This is exactly where a resume's "BTech CS" gets interpreted into
  // these two separate fields (by the resume-parsing flow, not this
  // form) -- manual entry here just fills the same two fields directly.
  late final _degree = TextEditingController(text: widget.entry?.degree ?? '');
  late final _fieldOfStudy = TextEditingController(
    text: widget.entry?.fieldOfStudy ?? '',
  );
  late final _grade = TextEditingController(text: widget.entry?.grade ?? '');
  late final _description = TextEditingController(
    text: widget.entry?.description ?? '',
  );
  late final _startYear = TextEditingController(
    text: widget.entry?.startYear?.toString() ?? '',
  );
  late final _endYear = TextEditingController(
    text: widget.entry?.endYear?.toString() ?? '',
  );
  bool _isSaving = false;

  @override
  void dispose() {
    for (final c in [
      _institution,
      _degree,
      _fieldOfStudy,
      _grade,
      _description,
      _startYear,
      _endYear,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_institution.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    final entry = EducationEntry(
      id: widget.entry?.id ?? '',
      institution: _institution.text.trim(),
      degree: _degree.text.trim(),
      fieldOfStudy: _fieldOfStudy.text.trim(),
      grade: _grade.text.trim(),
      description: _description.text.trim(),
      startYear: _parseYear(_startYear.text),
      endYear: _parseYear(_endYear.text),
      sequence: widget.entry?.sequence ?? 0,
    );
    final failure = await widget.controller.saveEducation(entry);
    if (!mounted) return;
    if (failure != null) {
      setState(() => _isSaving = false);
      _showFailureSnackbar(context, failure);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          label: l10n.profileDetailsInstitutionFieldLabel,
          controller: _institution,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: l10n.profileDetailsDegreeFieldLabel,
          controller: _degree,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: l10n.profileDetailsFieldOfStudyFieldLabel,
          controller: _fieldOfStudy,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                label: l10n.profileDetailsStartYearFieldLabel,
                controller: _startYear,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppTextField(
                label: l10n.profileDetailsEndYearFieldLabel,
                controller: _endYear,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: l10n.profileDetailsGradeFieldLabel,
          controller: _grade,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: l10n.profileDetailsDescriptionFieldLabel,
          controller: _description,
          maxLines: 3,
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: l10n.profileDetailsSaveButton,
          isLoading: _isSaving,
          onPressed: _isSaving ? null : _save,
        ),
      ],
    );
  }
}

class _CertificationSection extends StatelessWidget {
  const _CertificationSection({
    required this.profile,
    required this.controller,
  });

  final DetailedCandidateProfile profile;
  final DetailedProfileController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.profileDetailsCertificationsSectionTitle,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (profile.certifications.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                l10n.profileDetailsCertificationsEmpty,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
              ),
            )
          else
            for (final entry in profile.certifications)
              _EntryRow(
                title: entry.name,
                subtitle: entry.issuingOrganization,
                dateRange: _formatDateRange(
                  l10n,
                  startMonth: entry.issueMonth,
                  startYear: entry.issueYear,
                  endMonth: entry.expiryMonth,
                  endYear: entry.expiryYear,
                  isOngoing: false,
                ),
                onEdit: () =>
                    _showCertificationForm(context, controller, entry: entry),
                onDelete: () async {
                  if (!await _confirmDelete(context)) return;
                  final failure = await controller.deleteCertification(
                    entry.id,
                  );
                  if (context.mounted && failure != null) {
                    _showFailureSnackbar(context, failure);
                  }
                },
              ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: l10n.profileDetailsAddCertificationButton,
            variant: AppButtonVariant.secondary,
            onPressed: () => _showCertificationForm(context, controller),
          ),
        ],
      ),
    );
  }
}

Future<void> _showCertificationForm(
  BuildContext context,
  DetailedProfileController controller, {
  ExternalCertificationEntry? entry,
}) {
  final l10n = AppLocalizations.of(context);
  return showAppBottomSheet(
    context: context,
    title: entry == null
        ? l10n.profileDetailsAddCertificationButton
        : l10n.profileDetailsEditSemantic(entry.name),
    child: _CertificationForm(controller: controller, entry: entry),
  );
}

class _CertificationForm extends StatefulWidget {
  const _CertificationForm({required this.controller, this.entry});

  final DetailedProfileController controller;
  final ExternalCertificationEntry? entry;

  @override
  State<_CertificationForm> createState() => _CertificationFormState();
}

class _CertificationFormState extends State<_CertificationForm> {
  late final _name = TextEditingController(text: widget.entry?.name ?? '');
  late final _issuingOrganization = TextEditingController(
    text: widget.entry?.issuingOrganization ?? '',
  );
  late final _credentialId = TextEditingController(
    text: widget.entry?.credentialId ?? '',
  );
  late final _credentialUrl = TextEditingController(
    text: widget.entry?.credentialUrl ?? '',
  );
  late final _issueMonth = TextEditingController(
    text: widget.entry?.issueMonth?.toString() ?? '',
  );
  late final _issueYear = TextEditingController(
    text: widget.entry?.issueYear?.toString() ?? '',
  );
  late final _expiryMonth = TextEditingController(
    text: widget.entry?.expiryMonth?.toString() ?? '',
  );
  late final _expiryYear = TextEditingController(
    text: widget.entry?.expiryYear?.toString() ?? '',
  );
  bool _isSaving = false;

  @override
  void dispose() {
    for (final c in [
      _name,
      _issuingOrganization,
      _credentialId,
      _credentialUrl,
      _issueMonth,
      _issueYear,
      _expiryMonth,
      _expiryYear,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    final entry = ExternalCertificationEntry(
      id: widget.entry?.id ?? '',
      name: _name.text.trim(),
      issuingOrganization: _issuingOrganization.text.trim(),
      credentialId: _credentialId.text.trim(),
      credentialUrl: _credentialUrl.text.trim(),
      issueMonth: _parseMonth(_issueMonth.text),
      issueYear: _parseYear(_issueYear.text),
      expiryMonth: _parseMonth(_expiryMonth.text),
      expiryYear: _parseYear(_expiryYear.text),
      sequence: widget.entry?.sequence ?? 0,
    );
    final failure = await widget.controller.saveCertification(entry);
    if (!mounted) return;
    if (failure != null) {
      setState(() => _isSaving = false);
      _showFailureSnackbar(context, failure);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          label: l10n.profileDetailsCertificationNameFieldLabel,
          controller: _name,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: l10n.profileDetailsIssuingOrgFieldLabel,
          controller: _issuingOrganization,
        ),
        const SizedBox(height: AppSpacing.sm),
        _MonthYearFields(
          monthLabel: l10n.profileDetailsIssueMonthFieldLabel,
          yearLabel: l10n.profileDetailsIssueYearFieldLabel,
          monthController: _issueMonth,
          yearController: _issueYear,
        ),
        const SizedBox(height: AppSpacing.sm),
        _MonthYearFields(
          monthLabel: l10n.profileDetailsExpiryMonthFieldLabel,
          yearLabel: l10n.profileDetailsExpiryYearFieldLabel,
          monthController: _expiryMonth,
          yearController: _expiryYear,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: l10n.profileDetailsCredentialIdFieldLabel,
          controller: _credentialId,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: l10n.profileDetailsCredentialUrlFieldLabel,
          controller: _credentialUrl,
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: l10n.profileDetailsSaveButton,
          isLoading: _isSaving,
          onPressed: _isSaving ? null : _save,
        ),
      ],
    );
  }
}

class _ProjectSection extends StatelessWidget {
  const _ProjectSection({required this.profile, required this.controller});

  final DetailedCandidateProfile profile;
  final DetailedProfileController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.profileDetailsProjectsSectionTitle,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (profile.projects.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                l10n.profileDetailsProjectsEmpty,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
              ),
            )
          else
            for (final entry in profile.projects)
              _EntryRow(
                title: entry.title,
                subtitle: entry.role,
                dateRange: _formatDateRange(
                  l10n,
                  startMonth: entry.startMonth,
                  startYear: entry.startYear,
                  endMonth: entry.endMonth,
                  endYear: entry.endYear,
                  isOngoing: entry.isOngoing,
                ),
                onEdit: () =>
                    _showProjectForm(context, controller, entry: entry),
                onDelete: () async {
                  if (!await _confirmDelete(context)) return;
                  final failure = await controller.deleteProject(entry.id);
                  if (context.mounted && failure != null) {
                    _showFailureSnackbar(context, failure);
                  }
                },
              ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: l10n.profileDetailsAddProjectButton,
            variant: AppButtonVariant.secondary,
            onPressed: () => _showProjectForm(context, controller),
          ),
        ],
      ),
    );
  }
}

Future<void> _showProjectForm(
  BuildContext context,
  DetailedProfileController controller, {
  ProjectEntry? entry,
}) {
  final l10n = AppLocalizations.of(context);
  return showAppBottomSheet(
    context: context,
    title: entry == null
        ? l10n.profileDetailsAddProjectButton
        : l10n.profileDetailsEditSemantic(entry.title),
    child: _ProjectForm(controller: controller, entry: entry),
  );
}

class _ProjectForm extends StatefulWidget {
  const _ProjectForm({required this.controller, this.entry});

  final DetailedProfileController controller;
  final ProjectEntry? entry;

  @override
  State<_ProjectForm> createState() => _ProjectFormState();
}

class _ProjectFormState extends State<_ProjectForm> {
  late final _title = TextEditingController(text: widget.entry?.title ?? '');
  late final _role = TextEditingController(text: widget.entry?.role ?? '');
  late final _description = TextEditingController(
    text: widget.entry?.description ?? '',
  );
  late final _url = TextEditingController(text: widget.entry?.url ?? '');
  late final _startMonth = TextEditingController(
    text: widget.entry?.startMonth?.toString() ?? '',
  );
  late final _startYear = TextEditingController(
    text: widget.entry?.startYear?.toString() ?? '',
  );
  late final _endMonth = TextEditingController(
    text: widget.entry?.endMonth?.toString() ?? '',
  );
  late final _endYear = TextEditingController(
    text: widget.entry?.endYear?.toString() ?? '',
  );
  late bool _isOngoing = widget.entry?.isOngoing ?? false;
  bool _isSaving = false;

  @override
  void dispose() {
    for (final c in [
      _title,
      _role,
      _description,
      _url,
      _startMonth,
      _startYear,
      _endMonth,
      _endYear,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    final entry = ProjectEntry(
      id: widget.entry?.id ?? '',
      title: _title.text.trim(),
      role: _role.text.trim(),
      description: _description.text.trim(),
      url: _url.text.trim(),
      startMonth: _parseMonth(_startMonth.text),
      startYear: _parseYear(_startYear.text),
      endMonth: _parseMonth(_endMonth.text),
      endYear: _parseYear(_endYear.text),
      isOngoing: _isOngoing,
      skillsUsed: widget.entry?.skillsUsed ?? const [],
      sequence: widget.entry?.sequence ?? 0,
    );
    final failure = await widget.controller.saveProject(entry);
    if (!mounted) return;
    if (failure != null) {
      setState(() => _isSaving = false);
      _showFailureSnackbar(context, failure);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          label: l10n.profileDetailsTitleFieldLabel,
          controller: _title,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: l10n.profileDetailsRoleFieldLabel,
          controller: _role,
        ),
        const SizedBox(height: AppSpacing.sm),
        _MonthYearFields(
          monthLabel: l10n.profileDetailsStartMonthFieldLabel,
          yearLabel: l10n.profileDetailsStartYearFieldLabel,
          monthController: _startMonth,
          yearController: _startYear,
        ),
        const SizedBox(height: AppSpacing.sm),
        CheckboxListTile(
          value: _isOngoing,
          onChanged: (value) => setState(() => _isOngoing = value ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(l10n.profileDetailsOngoingProjectLabel),
        ),
        if (!_isOngoing) ...[
          _MonthYearFields(
            monthLabel: l10n.profileDetailsEndMonthFieldLabel,
            yearLabel: l10n.profileDetailsEndYearFieldLabel,
            monthController: _endMonth,
            yearController: _endYear,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        AppTextField(
          label: l10n.profileDetailsDescriptionFieldLabel,
          controller: _description,
          maxLines: 3,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: l10n.profileDetailsProjectUrlFieldLabel,
          controller: _url,
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: l10n.profileDetailsSaveButton,
          isLoading: _isSaving,
          onPressed: _isSaving ? null : _save,
        ),
      ],
    );
  }
}
