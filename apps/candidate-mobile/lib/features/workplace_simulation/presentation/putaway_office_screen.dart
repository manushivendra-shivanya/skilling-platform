import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_state_view.dart';
import '../application/workplace_interaction_contracts.dart';
import '../application/workplace_simulation_controller.dart';
import '../domain/simulation_enums.dart';

class PutawayOfficeScreen extends ConsumerStatefulWidget {
  const PutawayOfficeScreen({
    required this.missionId,
    required this.onBack,
    required this.onMissionComplete,
    super.key,
  });

  final String missionId;
  final VoidCallback onBack;
  final VoidCallback onMissionComplete;

  @override
  ConsumerState<PutawayOfficeScreen> createState() =>
      _PutawayOfficeScreenState();
}

const _decisionOptions = [
  ('putaway_complete', 'Putaway complete'),
  ('hold_for_review', 'Hold for review'),
  ('escalate_to_supervisor', 'Escalate to supervisor'),
];

class _PutawayOfficeScreenState extends ConsumerState<PutawayOfficeScreen> {
  static const _stageId = 'putaway-decision';
  static const _reportTaskId = 'complete-putaway-report';
  static const _decisionTaskId = 'make-putaway-decision';
  static const _notifyTaskId = 'notify-supervisor';

  bool _saving = false;
  bool _tracked = false;
  bool _allItemsPlaced = false;
  bool _exceptionsRecorded = false;

  @override
  Widget build(BuildContext context) {
    final simulation = ref.watch(
      workplaceSimulationControllerProvider(widget.missionId),
    );
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to workplace',
          onPressed: _saving ? null : _exit,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Putaway Office'),
      ),
      body: SafeArea(
        child: simulation.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AppErrorState(
            title: 'Putaway Office unavailable',
            message: 'Your saved progress is safe. Retry loading the shift.',
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(
              workplaceSimulationControllerProvider(widget.missionId),
            ),
          ),
          data: (value) {
            final controller = ref.read(
              workplaceSimulationControllerProvider(widget.missionId).notifier,
            );
            final station = controller.workplaceOverview.workstations
                .firstWhere((item) => item.workstationId == 'putaway-office');
            if (value.mission.id != widget.missionId ||
                station.status == WorkstationStatus.locked) {
              return AppErrorState(
                title: 'Putaway Office is locked',
                message: station.supportingText,
                actionLabel: 'Back to Workplace',
                onAction: widget.onBack,
              );
            }
            final attempt = value.attempt;
            if (attempt == null) {
              return AppErrorState(
                title: 'Scenario unavailable',
                message: 'Return to the workplace and retry.',
                actionLabel: 'Back to Workplace',
                onAction: widget.onBack,
              );
            }
            if (!_tracked) {
              _tracked = true;
              unawaited(
                controller.recordWorkplaceEvent(
                  AttemptAuditEventType.workstationScreenOpened,
                  screenId: 'putaway-office',
                ),
              );
            }
            bool attempted(String taskId) =>
                attempt.actions.any((action) => action.taskId == taskId);
            final reportSubmitted = attempted(_reportTaskId);
            final decisionMade = attempted(_decisionTaskId);
            final supervisorNotified = attempted(_notifyTaskId);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Putaway report',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Confirm every item was placed and every exception '
                        'was reported.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _allItemsPlaced,
                              title: const Text('All items placed'),
                              onChanged: reportSubmitted || _saving
                                  ? null
                                  : (v) => setState(
                                      () => _allItemsPlaced = v ?? false,
                                    ),
                            ),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _exceptionsRecorded,
                              title: const Text('Exceptions recorded'),
                              onChanged: reportSubmitted || _saving
                                  ? null
                                  : (v) => setState(
                                      () => _exceptionsRecorded = v ?? false,
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (!reportSubmitted)
                        AppButton(
                          label: 'Submit report',
                          expand: false,
                          isLoading: _saving,
                          onPressed: _saving ? null : _submitReport,
                        )
                      else
                        const Text('Putaway report submitted.'),
                      if (reportSubmitted) ...[
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          'Putaway decision',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        const Text(
                          'Choose the outcome consistent with the placements '
                          'and exceptions above.',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (!decisionMade)
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              for (final option in _decisionOptions)
                                AppButton(
                                  label: option.$2,
                                  variant: AppButtonVariant.secondary,
                                  expand: false,
                                  isLoading: _saving,
                                  onPressed: _saving
                                      ? null
                                      : () => _selectDecision(option.$1),
                                ),
                            ],
                          )
                        else
                          const Text('Decision recorded.'),
                      ],
                      if (decisionMade) ...[
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          'Shift report',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        const Text(
                          'Notify the Warehouse Supervisor with the facts, '
                          'placements and any exceptions.',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppButton(
                          label: supervisorNotified
                              ? 'Supervisor notified'
                              : 'Notify supervisor',
                          expand: false,
                          isLoading: _saving,
                          onPressed: supervisorNotified || _saving
                              ? null
                              : _notifySupervisor,
                        ),
                      ],
                      if (supervisorNotified) ...[
                        const SizedBox(height: AppSpacing.xl),
                        AppButton(
                          label: 'Complete shift',
                          isLoading: _saving,
                          onPressed: _saving ? null : _completeMission,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _submitReport() async {
    setState(() => _saving = true);
    final failure = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordAction(
          stageId: _stageId,
          taskId: _reportTaskId,
          actionType: ActionType.completeForm,
          targetId: 'putaway-report',
          payload: {
            'allItemsPlaced': _allItemsPlaced,
            'exceptionsRecorded': _exceptionsRecorded,
          },
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (failure != null) {
      _showMessage('The report could not be submitted.');
    }
  }

  Future<void> _selectDecision(String decision) async {
    setState(() => _saving = true);
    final failure = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordAction(
          stageId: _stageId,
          taskId: _decisionTaskId,
          actionType: ActionType.makeDecision,
          targetId: 'putaway-report',
          payload: {'decision': decision},
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (failure != null) {
      _showMessage('The decision could not be recorded.');
    }
  }

  Future<void> _notifySupervisor() async {
    setState(() => _saving = true);
    final failure = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordAction(
          stageId: _stageId,
          taskId: _notifyTaskId,
          actionType: ActionType.confirmAction,
          targetId: 'supervisor-notification',
          payload: const {
            'supervisorNotified': true,
            'exceptionsIncluded': true,
          },
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (failure != null) {
      _showMessage('The supervisor could not be notified.');
    }
  }

  Future<void> _completeMission() async {
    setState(() => _saving = true);
    final result = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .completeMission(screenId: 'putaway-office');
    if (!mounted) return;
    setState(() => _saving = false);
    if (result == CompleteMissionResult.success) {
      widget.onMissionComplete();
    } else {
      _showMessage('The shift could not be completed.');
    }
  }

  Future<void> _exit() async {
    await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordWorkplaceEvent(
          AttemptAuditEventType.workstationScreenExited,
          screenId: 'putaway-office',
        );
    if (mounted) widget.onBack();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
