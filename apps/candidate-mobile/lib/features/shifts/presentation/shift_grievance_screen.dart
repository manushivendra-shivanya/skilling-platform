import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/app_failure_localization.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_loading_progress.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/app_sticky_footer.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/shift_grievance.dart';
import 'shift_grievance_controller.dart';

/// Maps a category to its localized display label. Kept in the presentation
/// layer, not the domain enum, since [ShiftGrievanceCategory] has no
/// `BuildContext`/`AppLocalizations` to localize with.
String _categoryLabel(
  ShiftGrievanceCategory category,
  AppLocalizations l10n,
) => switch (category) {
  ShiftGrievanceCategory.attendanceMismatch =>
    l10n.grievanceCategoryAttendanceMismatch,
  ShiftGrievanceCategory.payoutMismatch => l10n.grievanceCategoryPayoutMismatch,
  ShiftGrievanceCategory.unsafeWork => l10n.grievanceCategoryUnsafeWork,
  ShiftGrievanceCategory.supervisorIssue =>
    l10n.grievanceCategorySupervisorIssue,
  ShiftGrievanceCategory.unpaidOvertime => l10n.grievanceCategoryUnpaidOvertime,
  ShiftGrievanceCategory.cancellationIssue =>
    l10n.grievanceCategoryCancellationIssue,
  ShiftGrievanceCategory.harassmentSafety =>
    l10n.grievanceCategoryHarassmentSafety,
  ShiftGrievanceCategory.other => l10n.grievanceCategoryOther,
};

class ShiftGrievanceScreen extends ConsumerWidget {
  const ShiftGrievanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(shiftGrievanceControllerProvider);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.grievanceTitle)),
      body: SafeArea(
        child: state.when(
          loading: () => Center(
            child: AppLoadingProgressBar(label: l10n.grievanceLoadingLabel),
          ),
          error: (error, stackTrace) => AppErrorState(
            title: l10n.grievanceLoadErrorTitle,
            message: error is AppFailure
                ? error.localizedMessage(l10n)
                : l10n.grievanceLoadErrorFallback,
            onAction: () => ref.invalidate(shiftGrievanceControllerProvider),
          ),
          data: (grievances) => _GrievanceContent(grievances: grievances),
        ),
      ),
    );
  }
}

class _GrievanceContent extends ConsumerStatefulWidget {
  const _GrievanceContent({required this.grievances});

  final List<ShiftGrievance> grievances;

  @override
  ConsumerState<_GrievanceContent> createState() => _GrievanceContentState();
}

class _GrievanceContentState extends ConsumerState<_GrievanceContent> {
  ShiftGrievanceCategory _category = ShiftGrievanceCategory.other;
  final _descriptionController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dateFormat = DateFormat('d MMM yyyy');
    final ticketCount = widget.grievances.length;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            children: [
              Text(
                l10n.grievanceTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.grievanceCountFiled(ticketCount),
                style: const TextStyle(color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.grievanceRaiseTicketLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _CategoryDropdownField(
                      value: _category,
                      onChanged: (value) {
                        if (value != null) setState(() => _category = value);
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: l10n.grievanceWhatHappenedLabel,
                      controller: _descriptionController,
                      maxLines: 4,
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(
                          _error!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.error),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                l10n.grievanceYourTicketsLabel,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (widget.grievances.isEmpty)
                AppEmptyState(
                  title: l10n.grievanceEmptyTitle,
                  message: l10n.grievanceEmptyMessage,
                )
              else
                for (final grievance in widget.grievances) ...[
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '#${grievance.ticketReference}',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            AppStatusChip(
                              label: _statusLabel(grievance.status, l10n),
                              tone: _statusTone(grievance.status),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          _categoryLabel(grievance.category, l10n),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: AppColors.inkMuted,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          grievance.description,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(dateFormat.format(grievance.createdAt)),
                        if (grievance.resolutionNotes != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            l10n.grievanceResolutionPrefix(
                              grievance.resolutionNotes!,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
            ],
          ),
        ),
        AppStickyFooter(
          child: AppButton(
            label: _submitting
                ? l10n.grievanceSubmittingLabel
                : l10n.grievanceSubmitButton,
            isLoading: _submitting,
            onPressed: _submit,
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (_descriptionController.text.trim().isEmpty) {
      setState(() => _error = l10n.grievanceDescribeValidation);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final failure = await ref
        .read(shiftGrievanceControllerProvider.notifier)
        .submit(
          category: _category,
          description: _descriptionController.text.trim(),
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (failure == null) {
      _descriptionController.clear();
      showAppSnackBar(
        context: context,
        message: l10n.grievanceSubmittedSnackbar,
        tone: AppMessageTone.success,
      );
    } else {
      setState(() => _error = failure.localizedMessage(l10n));
    }
  }

  String _statusLabel(ShiftGrievanceStatus status, AppLocalizations l10n) =>
      switch (status) {
        ShiftGrievanceStatus.open => l10n.grievanceStatusOpen,
        ShiftGrievanceStatus.inReview => l10n.grievanceStatusInReview,
        ShiftGrievanceStatus.resolved => l10n.grievanceStatusResolved,
        ShiftGrievanceStatus.closed => l10n.grievanceStatusClosed,
      };

  AppChipTone _statusTone(ShiftGrievanceStatus status) => switch (status) {
    ShiftGrievanceStatus.open => AppChipTone.warning,
    ShiftGrievanceStatus.inReview => AppChipTone.info,
    ShiftGrievanceStatus.resolved ||
    ShiftGrievanceStatus.closed => AppChipTone.success,
  };
}

/// A category picker styled to match [AppTextField]'s `InputDecoration`
/// conventions -- an explicit labelled, medium-radius outline -- so it
/// carries the same visual weight as the description field beside it
/// instead of falling back to Flutter's bare default dropdown look.
class _CategoryDropdownField extends StatelessWidget {
  const _CategoryDropdownField({required this.value, required this.onChanged});

  final ShiftGrievanceCategory value;
  final ValueChanged<ShiftGrievanceCategory?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DropdownButtonFormField<ShiftGrievanceCategory>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: l10n.grievanceCategoryLabel,
        border: const OutlineInputBorder(borderRadius: AppRadius.mediumBorder),
      ),
      items: [
        for (final category in ShiftGrievanceCategory.values)
          DropdownMenuItem(
            value: category,
            child: Text(_categoryLabel(category, l10n)),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
