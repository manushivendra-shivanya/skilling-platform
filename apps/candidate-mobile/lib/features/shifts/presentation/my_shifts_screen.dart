import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/app_failure_localization.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_loading_progress.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/shifts_repository.dart';
import 'shifts_controller.dart';

class MyShiftsScreen extends ConsumerWidget {
  const MyShiftsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(shiftsControllerProvider);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.myShiftsTitle)),
      body: SafeArea(
        child: state.when(
          loading: () => Center(
            child: AppLoadingProgressBar(label: l10n.myShiftsLoadingLabel),
          ),
          error: (error, stackTrace) => AppErrorState(
            title: l10n.myShiftsLoadErrorTitle,
            message: error is AppFailure
                ? error.localizedMessage(l10n)
                : l10n.myShiftsLoadErrorFallback,
            onAction: () => ref.read(shiftsControllerProvider.notifier).retry(),
          ),
          data: (value) => _MyShiftsContent(state: value),
        ),
      ),
    );
  }
}

class _MyShiftsContent extends ConsumerWidget {
  const _MyShiftsContent({required this.state});

  final ShiftsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (state.myApplications.isEmpty) {
      return AppEmptyState(
        title: l10n.myShiftsEmptyTitle,
        message: l10n.myShiftsEmptyMessage,
      );
    }
    final shiftCount = state.myApplications.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      children: [
        Text(
          l10n.myShiftsTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.myShiftsCountInProgress(shiftCount),
          style: const TextStyle(color: AppColors.inkMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final application in state.myApplications) ...[
          _MyShiftCard(
            application: application,
            shift: _shiftFor(application.shiftId),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }

  Shift? _shiftFor(String shiftId) {
    for (final shift in state.shifts) {
      if (shift.id == shiftId) return shift;
    }
    return null;
  }
}

class _MyShiftCard extends ConsumerStatefulWidget {
  const _MyShiftCard({required this.application, required this.shift});

  final ShiftApplication application;
  final Shift? shift;

  @override
  ConsumerState<_MyShiftCard> createState() => _MyShiftCardState();
}

class _MyShiftCardState extends ConsumerState<_MyShiftCard> {
  final _codeController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shift = widget.shift;
    final dateFormat = DateFormat('EEE, d MMM • h:mm a');
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (shift != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    shift.roleTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '₹${shift.payAmount.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text('${shift.siteName} • ${shift.city}'),
            const SizedBox(height: AppSpacing.xxs),
            Text(dateFormat.format(shift.startsAt)),
          ] else ...[
            Text(
              l10n.shiftDetailShiftLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              l10n.myShiftsDetailsUnavailable,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.inkMuted),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          _StatusStepper(status: widget.application.status),
          const SizedBox(height: AppSpacing.md),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          if (widget.application.status == ShiftApplicationStatus.accepted ||
              widget.application.status ==
                  ShiftApplicationStatus.confirmed) ...[
            AppTextField(
              label: l10n.myShiftsCheckInCodeLabel,
              controller: _codeController,
              hint: l10n.myShiftsCheckInCodeHint,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: _busy
                  ? l10n.myShiftsCheckingInLabel
                  : l10n.myShiftsCheckInButton,
              isLoading: _busy,
              onPressed: _checkIn,
            ),
          ] else if (widget.application.status ==
              ShiftApplicationStatus.checkedIn) ...[
            AppButton(
              label: _busy
                  ? l10n.myShiftsCheckingOutLabel
                  : l10n.myShiftsCheckOutButton,
              isLoading: _busy,
              onPressed: _checkOut,
            ),
          ] else if (widget.application.status ==
              ShiftApplicationStatus.completed)
            Text(l10n.myShiftsCompletedNote),
        ],
      ),
    );
  }

  Future<void> _checkIn() async {
    final l10n = AppLocalizations.of(context);
    if (_codeController.text.trim().isEmpty) {
      setState(() => _error = l10n.myShiftsEnterCodeValidation);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final failure = await ref
        .read(shiftsControllerProvider.notifier)
        .checkIn(widget.application.id, _codeController.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    if (failure == null) {
      showAppSnackBar(
        context: context,
        message: l10n.myShiftsCheckedInSnackbar,
        tone: AppMessageTone.success,
      );
    } else {
      setState(() => _error = failure.localizedMessage(l10n));
    }
  }

  Future<void> _checkOut() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final failure = await ref
        .read(shiftsControllerProvider.notifier)
        .checkOut(widget.application.id);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = false);
    if (failure == null) {
      showAppSnackBar(
        context: context,
        message: l10n.myShiftsCheckedOutSnackbar,
        tone: AppMessageTone.success,
      );
    } else {
      setState(() => _error = failure.localizedMessage(l10n));
    }
  }
}

const _stages = [
  ShiftApplicationStatus.accepted,
  ShiftApplicationStatus.checkedIn,
  ShiftApplicationStatus.completed,
];

/// A compact dot-and-line stepper, same visual language as
/// `features/home/presentation/journey_step_card.dart`'s `_StepDot` --
/// copied locally rather than shared, since this is the only other place
/// that pattern is needed so far.
class _StatusStepper extends StatelessWidget {
  const _StatusStepper({required this.status});

  final ShiftApplicationStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isTerminalOther =
        status == ShiftApplicationStatus.noShow ||
        status == ShiftApplicationStatus.cancelled ||
        status == ShiftApplicationStatus.disputed;
    if (isTerminalOther) {
      return Text(
        _terminalLabel(status, l10n),
        style: const TextStyle(color: AppColors.error),
      );
    }
    final currentIndex = _stages.indexOf(status).clamp(0, _stages.length - 1);
    final stageLabels = [
      l10n.shiftStatusAccepted,
      l10n.shiftStatusCheckedIn,
      l10n.shiftStatusCompleted,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < _stages.length; i++) ...[
              Container(
                width: i == currentIndex ? 12 : 8,
                height: i == currentIndex ? 12 : 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= currentIndex
                      ? AppColors.success
                      : AppColors.surfaceMuted,
                ),
              ),
              if (i != _stages.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: i < currentIndex
                        ? AppColors.success
                        : AppColors.surfaceMuted,
                  ),
                ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < stageLabels.length; i++)
              Text(
                stageLabels[i],
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: i == currentIndex ? AppColors.ink : AppColors.inkMuted,
                  fontWeight: i == currentIndex
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _terminalLabel(ShiftApplicationStatus status, AppLocalizations l10n) =>
      switch (status) {
        ShiftApplicationStatus.noShow => l10n.myShiftsTerminalNoShow,
        ShiftApplicationStatus.cancelled => l10n.myShiftsTerminalCancelled,
        ShiftApplicationStatus.disputed => l10n.myShiftsTerminalDisputed,
        _ => '',
      };
}
