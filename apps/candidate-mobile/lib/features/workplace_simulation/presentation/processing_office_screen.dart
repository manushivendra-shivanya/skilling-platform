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

const _decisionOptions = [
  ('processing_complete', 'Processing complete'),
  ('hold_for_review', 'Hold for review'),
  ('escalate_to_supervisor', 'Escalate to supervisor'),
];

/// Classify every batch exception, complete the report, confirm the
/// outcome, and notify the supervisor -- the final stage of the Processing
/// mission.
class ProcessingOfficeScreen extends ConsumerStatefulWidget {
  const ProcessingOfficeScreen({
    required this.missionId,
    required this.onBack,
    required this.onMissionComplete,
    super.key,
  });

  final String missionId;
  final VoidCallback onBack;
  final VoidCallback onMissionComplete;

  @override
  ConsumerState<ProcessingOfficeScreen> createState() =>
      _ProcessingOfficeScreenState();
}

class _ProcessingOfficeScreenState
    extends ConsumerState<ProcessingOfficeScreen> {
  static const _stageId = 'processing-decision';
  static const _classifyTaskId = 'classify-batch-exceptions';
  static const _reportTaskId = 'complete-processing-report';
  static const _decisionTaskId = 'make-processing-decision';
  static const _notifyTaskId = 'notify-supervisor';

  String? _savingTargetId;
  bool _tracked = false;
  bool _allBatchesProcessed = false;
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
          onPressed: _savingTargetId == null ? _exit : null,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Processing Office'),
      ),
      body: SafeArea(
        child: simulation.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AppErrorState(
            title: 'Processing Office unavailable',
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
                .firstWhere(
                  (item) => item.workstationId == 'processing-office',
                );
            if (value.mission.id != widget.missionId ||
                station.status == WorkstationStatus.locked) {
              return AppErrorState(
                title: 'Processing Office is locked',
                message: station.supportingText,
                actionLabel: 'Back to Workplace',
                onAction: widget.onBack,
              );
            }
            final scenario = value.scenario;
            final attempt = value.attempt;
            if (scenario == null || attempt == null) {
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
                  screenId: 'processing-office',
                ),
              );
            }
            final batches = value.mission
                .task(_classifyTaskId)
                .targetResourceIds
                .map(scenario.resource)
                .toList();
            final classified = {
              for (final action in attempt.actions)
                if (action.taskId == _classifyTaskId && action.targetId != null)
                  action.targetId,
            };
            final classifyDone = attempt.completedTaskIds.contains(
              _classifyTaskId,
            );
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
                        'Classify every batch exception',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Accept a compliant batch, or hold a batch with a '
                        'weight, traceability, or label discrepancy.',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (final batch in batches) ...[
                        AppCard(
                          semanticLabel: batch.title,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                batch.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text('${batch.content['batchCode']}'),
                              if (batch.issues.isNotEmpty)
                                Text(
                                  'Flagged: '
                                  '${batch.issues.map((i) => i.issueType.replaceAll('_', ' ')).join(', ')}',
                                ),
                              const SizedBox(height: AppSpacing.xs),
                              if (classified.contains(batch.id))
                                const Text('Classified')
                              else
                                Row(
                                  children: [
                                    Expanded(
                                      child: AppButton(
                                        label: 'Accept',
                                        expand: false,
                                        variant: AppButtonVariant.secondary,
                                        isLoading: _savingTargetId == batch.id,
                                        onPressed: _savingTargetId == null
                                            ? () => _classifyBatch(
                                                batch.id,
                                                'accept',
                                              )
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: AppButton(
                                        label: 'Hold for verification',
                                        expand: false,
                                        isLoading: _savingTargetId == batch.id,
                                        onPressed: _savingTargetId == null
                                            ? () => _classifyBatch(
                                                batch.id,
                                                'hold_for_verification',
                                              )
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                      if (classifyDone) ...[
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          'Processing report',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _allBatchesProcessed,
                                title: const Text('All batches processed'),
                                onChanged: reportSubmitted
                                    ? null
                                    : (v) => setState(
                                        () => _allBatchesProcessed = v ?? false,
                                      ),
                              ),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _exceptionsRecorded,
                                title: const Text('Exceptions recorded'),
                                onChanged: reportSubmitted
                                    ? null
                                    : (v) => setState(
                                        () => _exceptionsRecorded = v ?? false,
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        if (!reportSubmitted)
                          AppButton(
                            label: 'Submit report',
                            expand: false,
                            isLoading: _savingTargetId == 'processing-report',
                            onPressed: _savingTargetId == null
                                ? _submitReport
                                : null,
                          )
                        else
                          const Text('Processing report submitted.'),
                      ],
                      if (reportSubmitted) ...[
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          'Processing decision',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
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
                                  isLoading:
                                      _savingTargetId == 'processing-report',
                                  onPressed: _savingTargetId == null
                                      ? () => _selectDecision(option.$1)
                                      : null,
                                ),
                            ],
                          )
                        else
                          const Text('Decision recorded.'),
                      ],
                      if (decisionMade) ...[
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          'Notify supervisor',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppButton(
                          label: supervisorNotified
                              ? 'Supervisor notified'
                              : 'Notify supervisor',
                          expand: false,
                          isLoading:
                              _savingTargetId == 'supervisor-notification',
                          onPressed: supervisorNotified
                              ? null
                              : (_savingTargetId == null
                                    ? _notifySupervisor
                                    : null),
                        ),
                      ],
                      if (supervisorNotified) ...[
                        const SizedBox(height: AppSpacing.xl),
                        AppButton(
                          label: 'Complete shift',
                          isLoading: _savingTargetId == 'complete-mission',
                          onPressed: _savingTargetId == null
                              ? _completeMission
                              : null,
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

  Future<void> _classifyBatch(String batchId, String disposition) async {
    setState(() => _savingTargetId = batchId);
    final failure = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordAction(
          stageId: _stageId,
          taskId: _classifyTaskId,
          actionType: ActionType.selectDisposition,
          targetId: batchId,
          payload: {
            'disposition': disposition,
            if (disposition != 'accept') 'reason': 'Batch exception flagged',
          },
        );
    if (!mounted) return;
    setState(() => _savingTargetId = null);
    if (failure != null) {
      _showMessage('The batch could not be classified.');
    }
  }

  Future<void> _submitReport() async {
    setState(() => _savingTargetId = 'processing-report');
    final failure = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordAction(
          stageId: _stageId,
          taskId: _reportTaskId,
          actionType: ActionType.completeForm,
          targetId: 'processing-report',
          payload: {
            'allBatchesProcessed': _allBatchesProcessed,
            'exceptionsRecorded': _exceptionsRecorded,
          },
        );
    if (!mounted) return;
    setState(() => _savingTargetId = null);
    if (failure != null) {
      _showMessage('The report could not be submitted.');
    }
  }

  Future<void> _selectDecision(String decision) async {
    setState(() => _savingTargetId = 'processing-report');
    final failure = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordAction(
          stageId: _stageId,
          taskId: _decisionTaskId,
          actionType: ActionType.makeDecision,
          targetId: 'processing-report',
          payload: {'decision': decision},
        );
    if (!mounted) return;
    setState(() => _savingTargetId = null);
    if (failure != null) {
      _showMessage('The decision could not be recorded.');
    }
  }

  Future<void> _notifySupervisor() async {
    setState(() => _savingTargetId = 'supervisor-notification');
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
    setState(() => _savingTargetId = null);
    if (failure != null) {
      _showMessage('The supervisor could not be notified.');
    }
  }

  Future<void> _completeMission() async {
    setState(() => _savingTargetId = 'complete-mission');
    final result = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .completeMission(screenId: 'processing-office');
    if (!mounted) return;
    setState(() => _savingTargetId = null);
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
          screenId: 'processing-office',
        );
    if (mounted) widget.onBack();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
