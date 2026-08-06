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

/// Verify the vehicle reaches its required temperature before loading, then
/// load every crate in the correct sequence.
class VehicleCheckScreen extends ConsumerStatefulWidget {
  const VehicleCheckScreen({
    required this.missionId,
    required this.onBack,
    required this.onOpenDispatchGate,
    super.key,
  });

  final String missionId;
  final VoidCallback onBack;
  final VoidCallback onOpenDispatchGate;

  @override
  ConsumerState<VehicleCheckScreen> createState() => _VehicleCheckScreenState();
}

class _VehicleCheckScreenState extends ConsumerState<VehicleCheckScreen> {
  static const _stageId = 'vehicle-verification';
  static const _tempTaskId = 'verify-vehicle-temperature';
  static const _loadTaskId = 'confirm-load-sequence';

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
        title: const Text('Vehicle Check'),
      ),
      body: SafeArea(
        child: simulation.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AppErrorState(
            title: 'Vehicle Check unavailable',
            message: 'Your saved progress is safe. Retry loading the vehicle.',
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
                .firstWhere((item) => item.workstationId == 'vehicle-check');
            if (value.mission.id != widget.missionId ||
                station.status == WorkstationStatus.locked) {
              return AppErrorState(
                title: 'Vehicle Check is locked',
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
                  screenId: 'vehicle-check',
                ),
              );
            }
            final vehicle = scenario.resource('dispatch-vehicle');
            final tempIssue = vehicle.issues.any(
              (issue) => issue.issueType == 'vehicle_temp_failure',
            );
            final tempDone = attempt.completedTaskIds.contains(_tempTaskId);
            final crates = value.mission
                .task(_loadTaskId)
                .targetResourceIds
                .map(scenario.resource)
                .toList();
            final loaded = {
              for (final action in attempt.actions)
                if (action.taskId == _loadTaskId && action.targetId != null)
                  action.targetId,
            };
            final allDone =
                tempDone && attempt.completedTaskIds.contains(_loadTaskId);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verify vehicle temperature',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Required: ${vehicle.content['requiredTempC']}°C • '
                        'Reading: ${vehicle.content['vehicleTempC']}°C',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (!tempDone)
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            AppButton(
                              label: 'Confirm ready to load',
                              expand: false,
                              isLoading: _savingTargetId == 'dispatch-vehicle',
                              onPressed: _savingTargetId == null
                                  ? () => _recordTemperature(
                                      heldForRecheck: false,
                                      proceededWithoutHold: false,
                                    )
                                  : null,
                            ),
                            AppButton(
                              label: 'Hold for recheck',
                              variant: AppButtonVariant.secondary,
                              expand: false,
                              isLoading: _savingTargetId == 'dispatch-vehicle',
                              onPressed: _savingTargetId == null
                                  ? () => _recordTemperature(
                                      heldForRecheck: true,
                                      proceededWithoutHold: false,
                                    )
                                  : null,
                            ),
                            if (tempIssue)
                              AppButton(
                                label: 'Proceed anyway',
                                variant: AppButtonVariant.destructive,
                                expand: false,
                                isLoading:
                                    _savingTargetId == 'dispatch-vehicle',
                                onPressed: _savingTargetId == null
                                    ? () => _recordTemperature(
                                        heldForRecheck: false,
                                        proceededWithoutHold: true,
                                      )
                                    : null,
                              ),
                          ],
                        )
                      else
                        const Text('Vehicle temperature recorded.'),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Load every crate in sequence',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (final crate in crates) ...[
                        AppCard(
                          semanticLabel: crate.title,
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      crate.title,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    Text('${crate.content['routeId']}'),
                                  ],
                                ),
                              ),
                              if (loaded.contains(crate.id))
                                const Icon(Icons.check_circle)
                              else
                                AppButton(
                                  label: 'Load',
                                  expand: false,
                                  isLoading:
                                      tempDone && _savingTargetId == crate.id,
                                  onPressed: tempDone && _savingTargetId == null
                                      ? () => _loadCrate(crate.id)
                                      : null,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      if (allDone)
                        AppButton(
                          label: 'Continue to Dispatch Gate',
                          onPressed: widget.onOpenDispatchGate,
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

  Future<void> _recordTemperature({
    required bool heldForRecheck,
    required bool proceededWithoutHold,
  }) async {
    setState(() => _savingTargetId = 'dispatch-vehicle');
    final failure = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordAction(
          stageId: _stageId,
          taskId: _tempTaskId,
          actionType: ActionType.recordTemperatureReading,
          targetId: 'dispatch-vehicle',
          payload: {
            'heldForRecheck': heldForRecheck,
            'proceededWithoutHold': proceededWithoutHold,
          },
        );
    if (!mounted) return;
    setState(() => _savingTargetId = null);
    if (failure != null) {
      _showMessage('The temperature reading could not be recorded.');
    }
  }

  Future<void> _loadCrate(String crateId) async {
    setState(() => _savingTargetId = crateId);
    final failure = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordAction(
          stageId: _stageId,
          taskId: _loadTaskId,
          actionType: ActionType.moveItem,
          targetId: crateId,
          payload: const {'loadedInSequence': true},
        );
    if (!mounted) return;
    setState(() => _savingTargetId = null);
    if (failure != null) {
      _showMessage('The crate could not be loaded.');
    }
  }

  Future<void> _exit() async {
    await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordWorkplaceEvent(
          AttemptAuditEventType.workstationScreenExited,
          screenId: 'vehicle-check',
        );
    if (mounted) widget.onBack();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
