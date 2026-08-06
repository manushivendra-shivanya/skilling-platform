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

/// Consolidate every crate into its route, then stage it for loading.
class ConsolidationBayScreen extends ConsumerStatefulWidget {
  const ConsolidationBayScreen({
    required this.missionId,
    required this.onBack,
    required this.onOpenVehicleCheck,
    super.key,
  });

  final String missionId;
  final VoidCallback onBack;
  final VoidCallback onOpenVehicleCheck;

  @override
  ConsumerState<ConsolidationBayScreen> createState() =>
      _ConsolidationBayScreenState();
}

class _ConsolidationBayScreenState
    extends ConsumerState<ConsolidationBayScreen> {
  static const _stageId = 'consolidation-and-staging';
  static const _consolidateTaskId = 'consolidate-order-items';
  static const _stageTaskId = 'stage-route-crates';

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
        title: const Text('Consolidation Bay'),
      ),
      body: SafeArea(
        child: simulation.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AppErrorState(
            title: 'Consolidation Bay unavailable',
            message: 'Your saved progress is safe. Retry loading crates.',
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
                  (item) => item.workstationId == 'consolidation-bay',
                );
            if (value.mission.id != widget.missionId ||
                station.status == WorkstationStatus.locked) {
              return AppErrorState(
                title: 'Consolidation Bay is locked',
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
                  screenId: 'consolidation-bay',
                ),
              );
            }
            final crates = value.mission
                .task(_consolidateTaskId)
                .targetResourceIds
                .map(scenario.resource)
                .toList();
            Set<String?> targetsFor(String taskId) => {
              for (final action in attempt.actions)
                if (action.taskId == taskId && action.targetId != null)
                  action.targetId,
            };
            final consolidated = targetsFor(_consolidateTaskId);
            final staged = targetsFor(_stageTaskId);
            final allDone =
                attempt.completedTaskIds.contains(_consolidateTaskId) &&
                attempt.completedTaskIds.contains(_stageTaskId);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Consolidate and stage every crate',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Group each crate with its route, then confirm it '
                        'is staged and ready for loading.',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      for (final crate in crates) ...[
                        AppCard(
                          semanticLabel: crate.title,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                crate.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text('${crate.content['routeId']}'),
                              const SizedBox(height: AppSpacing.xs),
                              if (!consolidated.contains(crate.id))
                                AppButton(
                                  label: 'Consolidate',
                                  expand: false,
                                  isLoading: _savingTargetId == crate.id,
                                  onPressed: _savingTargetId == null
                                      ? () => _consolidate(crate.id)
                                      : null,
                                )
                              else if (!staged.contains(crate.id))
                                AppButton(
                                  label: 'Stage for loading',
                                  expand: false,
                                  isLoading: _savingTargetId == crate.id,
                                  onPressed: _savingTargetId == null
                                      ? () => _stage(crate.id)
                                      : null,
                                )
                              else
                                const Text('Consolidated and staged'),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      if (allDone)
                        AppButton(
                          label: 'Continue to Vehicle Check',
                          onPressed: widget.onOpenVehicleCheck,
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

  Future<void> _consolidate(String crateId) async {
    setState(() => _savingTargetId = crateId);
    final failure = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordAction(
          stageId: _stageId,
          taskId: _consolidateTaskId,
          actionType: ActionType.moveItem,
          targetId: crateId,
          payload: const {'consolidated': true},
        );
    if (!mounted) return;
    setState(() => _savingTargetId = null);
    if (failure != null) {
      _showMessage('The crate could not be consolidated.');
    }
  }

  Future<void> _stage(String crateId) async {
    setState(() => _savingTargetId = crateId);
    final failure = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordAction(
          stageId: _stageId,
          taskId: _stageTaskId,
          actionType: ActionType.confirmAction,
          targetId: crateId,
          payload: const {'staged': true},
        );
    if (!mounted) return;
    setState(() => _savingTargetId = null);
    if (failure != null) {
      _showMessage('The crate could not be staged.');
    }
  }

  Future<void> _exit() async {
    await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordWorkplaceEvent(
          AttemptAuditEventType.workstationScreenExited,
          screenId: 'consolidation-bay',
        );
    if (mounted) widget.onBack();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
