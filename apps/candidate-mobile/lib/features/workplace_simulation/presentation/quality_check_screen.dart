import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../application/workplace_simulation_controller.dart';
import '../application/workplace_simulation_state.dart';
import '../domain/simulation_enums.dart';
import 'widgets/station_scaffold.dart';

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

  @override
  Widget build(BuildContext context) {
    return StationScaffold(
      missionId: widget.missionId,
      workstationId: 'quality-check',
      title: 'Quality Check',
      openedEvent: AttemptAuditEventType.workstationScreenOpened,
      exitedEvent: AttemptAuditEventType.workstationScreenExited,
      onBack: widget.onBack,
      saving: _savingTargetId != null,
      contentBuilder: _buildContent,
      footerBuilder: _buildFooter,
    );
  }

  Widget _buildContent(BuildContext context, WorkplaceSimulationState value) {
    final scenario = value.scenario!;
    final attempt = value.attempt!;
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
    return Column(
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
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Label ${batch.content['labelCode']} • '
                        'Traceability ${batch.content['traceabilityCode']}',
                      ),
                      if (batch.issues.any(
                        (issue) =>
                            issue.issueType == 'label_mismatch' ||
                            issue.issueType == 'missing_traceability',
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
      ],
    );
  }

  Widget? _buildFooter(BuildContext context, WorkplaceSimulationState value) {
    final attempt = value.attempt!;
    final labelsDone = attempt.completedTaskIds.contains(_labelTaskId);
    final sampleDone = attempt.completedTaskIds.contains(_sampleTaskId);
    if (!(labelsDone && sampleDone)) return null;
    return AppButton(
      label: 'Continue to Processing Office',
      onPressed: widget.onOpenProcessingOffice,
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
