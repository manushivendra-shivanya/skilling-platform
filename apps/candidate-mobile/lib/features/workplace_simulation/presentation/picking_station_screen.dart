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

/// Scan every crate for its route -- flag a wrong-route crate, rescan a
/// failed read, or confirm a compliant crate.
class PickingStationScreen extends ConsumerStatefulWidget {
  const PickingStationScreen({
    required this.missionId,
    required this.onBack,
    required this.onOpenConsolidationBay,
    super.key,
  });

  final String missionId;
  final VoidCallback onBack;
  final VoidCallback onOpenConsolidationBay;

  @override
  ConsumerState<PickingStationScreen> createState() =>
      _PickingStationScreenState();
}

class _PickingStationScreenState extends ConsumerState<PickingStationScreen> {
  static const _stageId = 'picking';
  static const _pickTaskId = 'pick-order-items';

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
        title: const Text('Picking Station'),
      ),
      body: SafeArea(
        child: simulation.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AppErrorState(
            title: 'Picking Station unavailable',
            message: 'Your saved progress is safe. Retry loading orders.',
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
                .firstWhere((item) => item.workstationId == 'picking-station');
            if (value.mission.id != widget.missionId ||
                station.status == WorkstationStatus.locked) {
              return AppErrorState(
                title: 'Picking Station is locked',
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
                  screenId: 'picking-station',
                ),
              );
            }
            final crates = value.mission
                .task(_pickTaskId)
                .targetResourceIds
                .map(scenario.resource)
                .toList();
            final picked = {
              for (final action in attempt.actions)
                if (action.taskId == _pickTaskId && action.targetId != null)
                  action.targetId,
            };
            final allDone = attempt.completedTaskIds.contains(_pickTaskId);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan every crate for its route',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Scan each crate. Flag a wrong-route crate, rescan '
                        'a failed read, or confirm a normal scan.',
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
                              Text(
                                '${crate.content['routeId']} • '
                                '${crate.content['destination']}',
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              if (picked.contains(crate.id))
                                const Text('Scanned')
                              else
                                Wrap(
                                  spacing: AppSpacing.xs,
                                  runSpacing: AppSpacing.xs,
                                  children: [
                                    AppButton(
                                      label: 'Scan (matched)',
                                      expand: false,
                                      isLoading: _savingTargetId == crate.id,
                                      onPressed: _savingTargetId == null
                                          ? () => _scanCrate(crate.id, const {
                                              'scanStatus': 'matched',
                                            })
                                          : null,
                                    ),
                                    AppButton(
                                      label: 'Flag wrong route',
                                      variant: AppButtonVariant.secondary,
                                      expand: false,
                                      isLoading: _savingTargetId == crate.id,
                                      onPressed: _savingTargetId == null
                                          ? () => _scanCrate(crate.id, const {
                                              'flagged': true,
                                            })
                                          : null,
                                    ),
                                    AppButton(
                                      label: 'Rescan',
                                      variant: AppButtonVariant.secondary,
                                      expand: false,
                                      isLoading: _savingTargetId == crate.id,
                                      onPressed: _savingTargetId == null
                                          ? () => _scanCrate(crate.id, const {
                                              'rescanned': true,
                                            })
                                          : null,
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      if (allDone)
                        AppButton(
                          label: 'Continue to Consolidation Bay',
                          onPressed: widget.onOpenConsolidationBay,
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

  Future<void> _scanCrate(String crateId, Map<String, Object?> payload) async {
    setState(() => _savingTargetId = crateId);
    final failure = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordAction(
          stageId: _stageId,
          taskId: _pickTaskId,
          actionType: ActionType.scanBarcode,
          targetId: crateId,
          payload: payload,
        );
    if (!mounted) return;
    setState(() => _savingTargetId = null);
    if (failure != null) {
      _showMessage('The crate could not be scanned.');
    }
  }

  Future<void> _exit() async {
    await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordWorkplaceEvent(
          AttemptAuditEventType.workstationScreenExited,
          screenId: 'picking-station',
        );
    if (mounted) widget.onBack();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
