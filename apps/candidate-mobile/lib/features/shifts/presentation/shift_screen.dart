import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/app_state_view.dart';
import '../domain/shift_match.dart';
import '../domain/shifts_repository.dart';
import 'shifts_controller.dart';

/// "Shifts near you today" -- the real Shift tab, replacing the earlier
/// placeholder. Candidates browse published shifts, see a skill-match% for
/// each (computed client-side, see `deriveShiftMatch`), and accept one.
/// Check-in/out, availability, payouts, and grievances live behind CTAs
/// here rather than as separate bottom-nav tabs.
class ShiftScreen extends ConsumerWidget {
  const ShiftScreen({
    required this.onOpenAvailability,
    required this.onOpenMyShifts,
    required this.onOpenPayouts,
    required this.onOpenGrievances,
    required this.onOpenSkillGap,
    super.key,
  });

  final VoidCallback onOpenAvailability;
  final VoidCallback onOpenMyShifts;
  final VoidCallback onOpenPayouts;
  final VoidCallback onOpenGrievances;
  final VoidCallback onOpenSkillGap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(shiftsControllerProvider);
    return state.when(
      loading: () => const _ShiftLoadingView(),
      error: (error, stackTrace) => AppErrorState(
        title: 'Shifts could not be loaded',
        message: error is AppFailure
            ? error.message
            : 'Shifts are temporarily unavailable.',
        onAction: () => ref.read(shiftsControllerProvider.notifier).retry(),
      ),
      data: (value) => _ShiftContent(
        state: value,
        onOpenAvailability: onOpenAvailability,
        onOpenMyShifts: onOpenMyShifts,
        onOpenPayouts: onOpenPayouts,
        onOpenGrievances: onOpenGrievances,
        onOpenSkillGap: onOpenSkillGap,
      ),
    );
  }
}

class _ShiftContent extends ConsumerWidget {
  const _ShiftContent({
    required this.state,
    required this.onOpenAvailability,
    required this.onOpenMyShifts,
    required this.onOpenPayouts,
    required this.onOpenGrievances,
    required this.onOpenSkillGap,
  });

  final ShiftsState state;
  final VoidCallback onOpenAvailability;
  final VoidCallback onOpenMyShifts;
  final VoidCallback onOpenPayouts;
  final VoidCallback onOpenGrievances;
  final VoidCallback onOpenSkillGap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startingSoon = [...state.shifts]
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final bestMatch = [...state.shifts]
      ..sort(
        (a, b) =>
            state.matchFor(b.id).matchPercent -
            state.matchFor(a.id).matchPercent,
      );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        112,
      ),
      children: [
        Text('My Shift', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          state.isLiveData
              ? '${state.shifts.length} shift${state.shifts.length == 1 ? '' : 's'} near you today'
              : 'Demo shifts • No live employer connection',
          style: const TextStyle(color: AppColors.inkMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            OutlinedButton.icon(
              onPressed: onOpenAvailability,
              icon: const Icon(Icons.schedule_outlined),
              label: const Text('Availability'),
            ),
            OutlinedButton.icon(
              onPressed: onOpenMyShifts,
              icon: const Icon(Icons.event_note_outlined),
              label: const Text('My shifts'),
            ),
            OutlinedButton.icon(
              onPressed: onOpenPayouts,
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: const Text('Payouts'),
            ),
            OutlinedButton.icon(
              onPressed: onOpenGrievances,
              icon: const Icon(Icons.support_agent_outlined),
              label: const Text('Support'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (state.shifts.isEmpty)
          const SizedBox(
            height: 220,
            child: AppEmptyState(
              title: 'No shifts right now',
              message:
                  'Check back soon, or set your availability so Flora knows when you can work.',
            ),
          )
        else ...[
          Text('Best match', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          _ShiftCard(
            shift: bestMatch.first,
            match: state.matchFor(bestMatch.first.id),
            application: state.applicationFor(bestMatch.first.id),
            isLiveData: state.isLiveData,
            onTap: () => _showShiftDetails(
              context,
              ref,
              bestMatch.first,
              onOpenSkillGap: onOpenSkillGap,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Starts soon', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (final shift in startingSoon) ...[
            _ShiftCard(
              shift: shift,
              match: state.matchFor(shift.id),
              application: state.applicationFor(shift.id),
              isLiveData: state.isLiveData,
              onTap: () => _showShiftDetails(
                context,
                ref,
                shift,
                onOpenSkillGap: onOpenSkillGap,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
        const SizedBox(height: AppSpacing.lg),
        const AppCard(
          backgroundColor: AppColors.infoSoft,
          child: Text(
            'Flora facilitates these shifts. Final attendance and payout '
            'approval follows the company’s shift policy.',
          ),
        ),
      ],
    );
  }

  Future<void> _showShiftDetails(
    BuildContext context,
    WidgetRef ref,
    Shift shift, {
    required VoidCallback onOpenSkillGap,
  }) {
    return showAppBottomSheet<void>(
      context: context,
      title: shift.roleTitle,
      child: _ShiftDetails(
        shift: shift,
        match: state.matchFor(shift.id),
        application: state.applicationFor(shift.id),
        isLiveData: state.isLiveData,
        onOpenSkillGap: onOpenSkillGap,
        onAccept: () =>
            ref.read(shiftsControllerProvider.notifier).acceptShift(shift.id),
      ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  const _ShiftCard({
    required this.shift,
    required this.match,
    required this.application,
    required this.isLiveData,
    required this.onTap,
  });

  final Shift shift;
  final ShiftMatch match;
  final ShiftApplication? application;
  final bool isLiveData;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('h:mm a');
    return AppCard(
      onTap: onTap,
      semanticLabel: 'Open ${shift.roleTitle} at ${shift.siteName}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          Text('${shift.siteName} • ${shift.siteAddress}'),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '${timeFormat.format(shift.startsAt)} – ${timeFormat.format(shift.endsAt)}',
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              if (application != null)
                AppStatusChip(
                  label: _statusLabel(application!.status),
                  tone: _statusTone(application!.status),
                )
              else
                AppStatusChip(
                  label: match.isEligible
                      ? 'You match: ${match.matchPercent}%'
                      : 'Skills needed',
                  tone: match.isEligible
                      ? AppChipTone.success
                      : AppChipTone.warning,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _statusLabel(ShiftApplicationStatus status) => switch (status) {
  ShiftApplicationStatus.accepted => 'Accepted',
  ShiftApplicationStatus.confirmed => 'Confirmed',
  ShiftApplicationStatus.checkedIn => 'Checked in',
  ShiftApplicationStatus.completed => 'Completed',
  ShiftApplicationStatus.noShow => 'No show',
  ShiftApplicationStatus.cancelled => 'Cancelled',
  ShiftApplicationStatus.disputed => 'Disputed',
};

AppChipTone _statusTone(ShiftApplicationStatus status) => switch (status) {
  ShiftApplicationStatus.accepted ||
  ShiftApplicationStatus.confirmed => AppChipTone.info,
  ShiftApplicationStatus.checkedIn => AppChipTone.warning,
  ShiftApplicationStatus.completed => AppChipTone.success,
  ShiftApplicationStatus.noShow ||
  ShiftApplicationStatus.cancelled ||
  ShiftApplicationStatus.disputed => AppChipTone.error,
};

class _ShiftDetails extends StatefulWidget {
  const _ShiftDetails({
    required this.shift,
    required this.match,
    required this.application,
    required this.isLiveData,
    required this.onOpenSkillGap,
    required this.onAccept,
  });

  final Shift shift;
  final ShiftMatch match;
  final ShiftApplication? application;
  final bool isLiveData;
  final VoidCallback onOpenSkillGap;
  final Future<AppFailure?> Function() onAccept;

  @override
  State<_ShiftDetails> createState() => _ShiftDetailsState();
}

class _ShiftDetailsState extends State<_ShiftDetails> {
  bool _accepting = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final shift = widget.shift;
    final dateFormat = DateFormat('EEE, d MMM • h:mm a');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${shift.siteName} • ${shift.city}'),
        const SizedBox(height: AppSpacing.xxs),
        Text(shift.siteAddress),
        const SizedBox(height: AppSpacing.md),
        Text('Shift', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(dateFormat.format(shift.startsAt)),
        Text('Ends ${dateFormat.format(shift.endsAt)}'),
        const SizedBox(height: AppSpacing.md),
        Text('Pay', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '₹${shift.payAmount.toStringAsFixed(0)} ${shift.payCurrency} (estimated)',
        ),
        if (shift.description != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'About this shift',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(shift.description!),
        ],
        if (shift.supervisorName != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text('Supervisor', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(shift.supervisorName!),
        ],
        if (shift.cancellationPolicy != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Cancellation policy',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(shift.cancellationPolicy!),
        ],
        const SizedBox(height: AppSpacing.md),
        const AppCard(
          backgroundColor: AppColors.infoSoft,
          child: Text(
            'Flora is facilitating this shift. Final attendance and payout '
            'approval follows the company’s shift policy.',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (widget.application != null)
          AppCard(
            child: Text(
              'You have already ${_statusLabel(widget.application!.status).toLowerCase()} this shift. Open "My shifts" to check in or out.',
            ),
          )
        else if (!widget.match.isEligible) ...[
          Text(
            'Before accepting this shift',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Complete: ${widget.match.missingCompetencyIds.map(_displayName).join(', ')}',
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onOpenSkillGap();
            },
            child: const Text('Complete required skill'),
          ),
        ] else ...[
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          FilledButton(
            onPressed: _accepting ? null : _accept,
            child: Text(_accepting ? 'Accepting…' : 'Accept shift'),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        const AppBottomSheetCloseButton(),
      ],
    );
  }

  Future<void> _accept() async {
    setState(() => _accepting = true);
    final failure = await widget.onAccept();
    if (!mounted) return;
    if (failure == null) {
      showAppSnackBar(
        context: context,
        message: 'Shift accepted.',
        tone: AppMessageTone.success,
      );
      Navigator.of(context).pop();
    } else {
      setState(() {
        _accepting = false;
        _error = failure.message;
      });
    }
  }

  String _displayName(String competencyId) => competencyId
      .split(RegExp('[-_]'))
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}

class _ShiftLoadingView extends StatelessWidget {
  const _ShiftLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          AppSkeleton(height: 56),
          SizedBox(height: AppSpacing.md),
          AppSkeleton(height: 140),
          SizedBox(height: AppSpacing.md),
          AppSkeleton(height: 140),
        ],
      ),
    );
  }
}
