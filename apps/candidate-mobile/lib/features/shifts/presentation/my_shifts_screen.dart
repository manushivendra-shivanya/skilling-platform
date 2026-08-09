import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/app_text_field.dart';
import '../domain/shifts_repository.dart';
import 'shifts_controller.dart';

class MyShiftsScreen extends ConsumerWidget {
  const MyShiftsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(shiftsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My shifts')),
      body: SafeArea(
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => AppErrorState(
            title: 'Your shifts could not be loaded',
            message: error is AppFailure
                ? error.message
                : 'Your shifts are temporarily unavailable.',
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
    if (state.myApplications.isEmpty) {
      return const AppEmptyState(
        title: 'No shifts yet',
        message: 'Accept a shift from the Shift tab to see it here.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      children: [
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
    final shift = widget.shift;
    final dateFormat = DateFormat('EEE, d MMM • h:mm a');
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            shift?.roleTitle ?? 'Shift',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (shift != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text('${shift.siteName} • ${shift.city}'),
            const SizedBox(height: AppSpacing.xxs),
            Text(dateFormat.format(shift.startsAt)),
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
              label: 'Check-in code',
              controller: _codeController,
              hint: 'From your supervisor',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: _busy ? 'Checking in…' : 'Check in',
              isLoading: _busy,
              onPressed: _checkIn,
            ),
          ] else if (widget.application.status ==
              ShiftApplicationStatus.checkedIn) ...[
            AppButton(
              label: _busy ? 'Checking out…' : 'Check out',
              isLoading: _busy,
              onPressed: _checkOut,
            ),
          ] else if (widget.application.status ==
              ShiftApplicationStatus.completed)
            const Text(
              'Shift completed. Payout status is available under Payouts.',
            ),
        ],
      ),
    );
  }

  Future<void> _checkIn() async {
    if (_codeController.text.trim().isEmpty) {
      setState(() => _error = 'Enter the check-in code.');
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
        message: 'Checked in.',
        tone: AppMessageTone.success,
      );
    } else {
      setState(() => _error = failure.message);
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
    setState(() => _busy = false);
    if (failure == null) {
      showAppSnackBar(
        context: context,
        message: 'Checked out. Your payout is now pending approval.',
        tone: AppMessageTone.success,
      );
    } else {
      setState(() => _error = failure.message);
    }
  }
}

const _stages = [
  ShiftApplicationStatus.accepted,
  ShiftApplicationStatus.checkedIn,
  ShiftApplicationStatus.completed,
];
const _stageLabels = ['Accepted', 'Checked in', 'Completed'];

/// A compact dot-and-line stepper, same visual language as
/// `features/home/presentation/journey_step_card.dart`'s `_StepDot` --
/// copied locally rather than shared, since this is the only other place
/// that pattern is needed so far.
class _StatusStepper extends StatelessWidget {
  const _StatusStepper({required this.status});

  final ShiftApplicationStatus status;

  @override
  Widget build(BuildContext context) {
    final isTerminalOther =
        status == ShiftApplicationStatus.noShow ||
        status == ShiftApplicationStatus.cancelled ||
        status == ShiftApplicationStatus.disputed;
    if (isTerminalOther) {
      return Text(
        _terminalLabel(status),
        style: const TextStyle(color: AppColors.error),
      );
    }
    final currentIndex = _stages.indexOf(status).clamp(0, _stages.length - 1);
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
            for (var i = 0; i < _stageLabels.length; i++)
              Text(
                _stageLabels[i],
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

  String _terminalLabel(ShiftApplicationStatus status) => switch (status) {
    ShiftApplicationStatus.noShow => 'Marked as no-show.',
    ShiftApplicationStatus.cancelled => 'Cancelled.',
    ShiftApplicationStatus.disputed => 'Under dispute.',
    _ => '',
  };
}
