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

/// Label and traceability verification, plus the supervisor sample review.
class QualityCheckScreen extends ConsumerStatefulWidget {
  const QualityCheckScreen({
    required this.missionId,
    required this.onBack,
    required this.onOpenProcessingOffice,
    super.key,
  });

  final String missionId;
  final VoidCallback onBack;
  final VoidCallback onOpenProcessingOffice;

  @override
  ConsumerState<QualityCheckScreen> createState() => _QualityCheckScreenState();
}

class _QualityCheckScreenState extends ConsumerState<QualityCheckScreen> {
  static const _stageId = 'quality-and-sample';
  static const _labelTaskId = 'verify-batch-labels';
  static const _sampleTaskId = 'supervisor-sample-check';

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
        title: const Text('Quality Check'),
      ),
      body: SafeArea(
        child: simulation.when(
          loading: () => const Center(
            child: AppLoadingProgressBar(label: 'Loading your progress…'),
          ),
          error: (_, _) => AppErrorState(
            title: 'Quality Check unavailable',
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
                .firstWhere((item) => item.workstationId == 'quality-check');
            if (value.mission.id != widget.missionId ||
                station.status == WorkstationStatus.locked) {
              return AppErrorState(
                title: 'Quality Check is locked',
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
                  screenId: 'quality-check',
                ),
              );
            }
            final batches = value.mission
                .task(_labelTaskId)
                .targetResourceIds
                .map(scenario.resource)
                .toList();
            final verified = {
              for (final action in attempt.actions)
                if (action.taskId == _labelTaskId && action.targetId != null)
                  action.targetId,
            };
            final labelsDone = attempt.completedTaskIds.contains(_labelTaskId);
            final sampleDone = attempt.completedTaskIds.contains(_sampleTaskId);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verify every label and traceability code',
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
                                    Text(
                                      'Label ${batch.content['labelCode']} • '
                                      'Traceability ${batch.content['traceabilityCode']}',
                                    ),
                                    if (batch.issues.any(
                                      (issue) =>
                                          issue.issueType == 'label_mismatch' ||
                                          issue.issueType ==
                                              'missing_traceability',
                                    ))
                                      const Text(
                                        'Discrepancy noted against the batch record.',
                                      ),
                                  ],
                                ),
                              ),
                              if (verified.contains(batch.id))
                                const Icon(Icons.check_circle)
                              else
                                AppButton(
                                  label: 'Verify',
                                  expand: false,
                                  isLoading: _savingTargetId == batch.id,
                                  onPressed: _savingTargetId == null
                                      ? () => _verifyBatch(batch.id)
                                      : null,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Supervisor sample review',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (!sampleDone)
                        AppButton(
                          label: 'Complete sample review',
                          expand: false,
                          isLoading: _savingTargetId == 'supervisor-sample',
                          onPressed: labelsDone && _savingTargetId == null
                              ? _completeSampleReview
                              : null,
                        )
                      else
                        const Text('Supervisor sample review complete.'),
                      const SizedBox(height: AppSpacing.md),
                      if (labelsDone && sampleDone)
                        AppButton(
                          label: 'Continue to Processing Office',
                          onPressed: widget.onOpenProcessingOffice,
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

  Future<void> _verifyBatch(String batchId) async {
    setState(() => _savingTargetId = batchId);
    final failure = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordAction(
          stageId: _stageId,
          taskId: _labelTaskId,
          actionType: ActionType.inspectItem,
          targetId: batchId,
          payload: const {'labelVerified': true},
        );
    if (!mounted) return;
    setState(() => _savingTargetId = null);
    if (failure != null) {
      _showMessage('The label could not be verified.');
    }
  }

  Future<void> _completeSampleReview() async {
    setState(() => _savingTargetId = 'supervisor-sample');
    final failure = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordAction(
          stageId: _stageId,
          taskId: _sampleTaskId,
          actionType: ActionType.confirmAction,
          targetId: 'supervisor-sample',
          payload: const {'sampleReviewed': true},
        );
    if (!mounted) return;
    setState(() => _savingTargetId = null);
    if (failure != null) {
      _showMessage('The sample review could not be completed.');
    }
  }

  Future<void> _exit() async {
    await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordWorkplaceEvent(
          AttemptAuditEventType.workstationScreenExited,
          screenId: 'quality-check',
        );
    if (mounted) widget.onBack();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
