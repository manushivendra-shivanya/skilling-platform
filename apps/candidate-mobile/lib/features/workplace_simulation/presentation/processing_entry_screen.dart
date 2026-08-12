import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_loading_progress.dart';
import '../../../core/widgets/app_state_view.dart';
import '../application/workplace_interaction_contracts.dart';
import '../application/workplace_simulation_controller.dart';
import '../domain/simulation_enums.dart';

/// Hygiene checkpoint and batch scan-in for the Processing mission.
class ProcessingEntryScreen extends ConsumerStatefulWidget {
  const ProcessingEntryScreen({
    required this.missionId,
    required this.onBack,
    required this.onOpenPackingStation,
    super.key,
  });

  final String missionId;
  final VoidCallback onBack;
  final VoidCallback onOpenPackingStation;

  @override
  ConsumerState<ProcessingEntryScreen> createState() =>
      _ProcessingEntryScreenState();
}

class _ProcessingEntryScreenState extends ConsumerState<ProcessingEntryScreen> {
  static const _stageId = 'hygiene-and-scan';
  static const _hygieneTaskId = 'confirm-hygiene-compliance';
  static const _scanTaskId = 'scan-processing-batches';

  String? _savingTargetId;
  bool _tracked = false;

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
        title: const Text('Processing Entry'),
      ),
      body: SafeArea(
        child: simulation.when(
          loading: () => const Center(
            child: AppLoadingProgressBar(label: 'Loading your progress…'),
          ),
          error: (_, _) => AppErrorState(
            title: 'Processing Entry unavailable',
            message: 'Your saved progress is safe. Retry loading the batch.',
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
                .firstWhere((item) => item.workstationId == 'processing-entry');
            if (value.mission.id != widget.missionId ||
                station.status == WorkstationStatus.locked) {
              return AppErrorState(
                title: 'Processing Entry is locked',
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
                  screenId: 'processing-entry',
                ),
              );
            }
            final hygiene = scenario.resource('hygiene-checklist');
            final hygieneGap = hygiene.issues.any(
              (issue) => issue.issueType == 'hygiene_missed',
            );
            final hygieneDone = attempt.completedTaskIds.contains(
              _hygieneTaskId,
            );
            final batches = value.mission
                .task(_scanTaskId)
                .targetResourceIds
                .map(scenario.resource)
                .toList();
            final scanned = {
              for (final action in attempt.actions)
                if (action.taskId == _scanTaskId && action.targetId != null)
                  action.targetId,
            };
            final allScanned = attempt.completedTaskIds.contains(_scanTaskId);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pre-Shift Hygiene Checklist',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        hygieneGap
                            ? 'Hands washed: not confirmed. PPE check: incomplete.'
                            : 'Hands washed: confirmed. PPE check: complete.',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (!hygieneDone)
                        Row(
                          children: [
                            Expanded(
                              child: AppButton(
                                label: 'Confirm compliant',
                                variant: AppButtonVariant.secondary,
                                isLoading:
                                    _savingTargetId == 'hygiene-checklist',
                                onPressed: _savingTargetId == null
                                    ? () => _confirmHygiene(compliant: true)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: AppButton(
                                label: 'Report a gap',
                                isLoading:
                                    _savingTargetId == 'hygiene-checklist',
                                onPressed: _savingTargetId == null
                                    ? () => _confirmHygiene(compliant: false)
                                    : null,
                              ),
                            ),
                          ],
                        )
                      else
                        const Text('Hygiene status recorded for this shift.'),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Scan every batch onto the line',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (final batch in batches) ...[
                        AppCard(
                          semanticLabel: batch.title,
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      batch.title,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    Text('${batch.content['batchCode']}'),
                                  ],
                                ),
                              ),
                              if (scanned.contains(batch.id))
                                const Icon(Icons.check_circle)
                              else
                                AppButton(
                                  label: 'Scan',
                                  expand: false,
                                  isLoading: _savingTargetId == batch.id,
                                  onPressed: _savingTargetId == null
                                      ? () => _scanBatch(batch.id)
                                      : null,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      if (hygieneDone && allScanned)
                        AppButton(
                          label: 'Continue to Packing Station',
                          onPressed: widget.onOpenPackingStation,
                        ),
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

  Future<void> _confirmHygiene({required bool compliant}) async {
    setState(() => _savingTargetId = 'hygiene-checklist');
    final failure = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordAction(
          stageId: _stageId,
          taskId: _hygieneTaskId,
          actionType: ActionType.confirmAction,
          targetId: 'hygiene-checklist',
          payload: {'compliant': compliant},
        );
    if (!mounted) return;
    setState(() => _savingTargetId = null);
    if (failure != null) {
      _showMessage('The hygiene status could not be recorded.');
    }
  }

  Future<void> _scanBatch(String batchId) async {
    setState(() => _savingTargetId = batchId);
    final failure = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordAction(
          stageId: _stageId,
          taskId: _scanTaskId,
          actionType: ActionType.scanBarcode,
          targetId: batchId,
          payload: const {'scanStatus': 'matched'},
        );
    if (!mounted) return;
    setState(() => _savingTargetId = null);
    if (failure != null) {
      _showMessage('The batch could not be scanned.');
    }
  }

  Future<void> _exit() async {
    await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordWorkplaceEvent(
          AttemptAuditEventType.workstationScreenExited,
          screenId: 'processing-entry',
        );
    if (mounted) widget.onBack();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
