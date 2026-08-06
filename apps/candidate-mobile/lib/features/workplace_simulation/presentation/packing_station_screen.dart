import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_state_view.dart';
import '../application/workplace_interaction_contracts.dart';
import '../application/workplace_simulation_controller.dart';
import '../domain/simulation_content.dart';
import '../domain/simulation_enums.dart';

/// Pack every batch, then record the weight shown on the scale.
class PackingStationScreen extends ConsumerStatefulWidget {
  const PackingStationScreen({
    required this.missionId,
    required this.onBack,
    required this.onOpenQualityCheck,
    super.key,
  });

  final String missionId;
  final VoidCallback onBack;
  final VoidCallback onOpenQualityCheck;

  @override
  ConsumerState<PackingStationScreen> createState() =>
      _PackingStationScreenState();
}

class _PackingStationScreenState extends ConsumerState<PackingStationScreen> {
  static const _stageId = 'packing';
  static const _packTaskId = 'pack-batch-items';
  static const _weightTaskId = 'record-batch-weight';

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
        title: const Text('Packing Station'),
      ),
      body: SafeArea(
        child: simulation.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AppErrorState(
            title: 'Packing Station unavailable',
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
                .firstWhere((item) => item.workstationId == 'packing-station');
            if (value.mission.id != widget.missionId ||
                station.status == WorkstationStatus.locked) {
              return AppErrorState(
                title: 'Packing Station is locked',
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
                  screenId: 'packing-station',
                ),
              );
            }
            final batches = value.mission
                .task(_packTaskId)
                .targetResourceIds
                .map(scenario.resource)
                .toList();
            Set<String?> targetsFor(String taskId) => {
              for (final action in attempt.actions)
                if (action.taskId == taskId && action.targetId != null)
                  action.targetId,
            };
            final packed = targetsFor(_packTaskId);
            final weighed = targetsFor(_weightTaskId);
            final allDone =
                attempt.completedTaskIds.contains(_packTaskId) &&
                attempt.completedTaskIds.contains(_weightTaskId);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pack and weigh every batch',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Pack each batch, then read the scale and record the '
                        'weight it actually shows.',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      for (final batch in batches) ...[
                        _BatchPackCard(
                          batch: batch,
                          packed: packed.contains(batch.id),
                          weighed: weighed.contains(batch.id),
                          saving: _savingTargetId == batch.id,
                          disabled: _savingTargetId != null,
                          onPack: () => _packBatch(batch.id),
                          onRecordWeight: (weight) =>
                              _recordWeight(batch.id, weight),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      if (allDone)
                        AppButton(
                          label: 'Continue to Quality Check',
                          onPressed: widget.onOpenQualityCheck,
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

  Future<void> _packBatch(String batchId) async {
    setState(() => _savingTargetId = batchId);
    final failure = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordAction(
          stageId: _stageId,
          taskId: _packTaskId,
          actionType: ActionType.moveItem,
          targetId: batchId,
          payload: const {'packed': true},
        );
    if (!mounted) return;
    setState(() => _savingTargetId = null);
    if (failure != null) {
      _showMessage('The batch could not be packed.');
    }
  }

  Future<void> _recordWeight(String batchId, double weight) async {
    setState(() => _savingTargetId = batchId);
    final failure = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordAction(
          stageId: _stageId,
          taskId: _weightTaskId,
          actionType: ActionType.recordWeight,
          targetId: batchId,
          payload: {'recordedWeightKg': weight},
        );
    if (!mounted) return;
    setState(() => _savingTargetId = null);
    if (failure != null) {
      _showMessage('The weight could not be recorded.');
    }
  }

  Future<void> _exit() async {
    await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordWorkplaceEvent(
          AttemptAuditEventType.workstationScreenExited,
          screenId: 'packing-station',
        );
    if (mounted) widget.onBack();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _BatchPackCard extends StatefulWidget {
  const _BatchPackCard({
    required this.batch,
    required this.packed,
    required this.weighed,
    required this.saving,
    required this.disabled,
    required this.onPack,
    required this.onRecordWeight,
  });

  final SimulationResource batch;
  final bool packed;
  final bool weighed;
  final bool saving;
  final bool disabled;
  final VoidCallback onPack;
  final ValueChanged<double> onRecordWeight;

  @override
  State<_BatchPackCard> createState() => _BatchPackCardState();
}

class _BatchPackCardState extends State<_BatchPackCard> {
  late final TextEditingController _weight = TextEditingController(
    text: '${widget.batch.content['packedWeightKg']}',
  );

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      semanticLabel: widget.batch.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.batch.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text('${widget.batch.content['batchCode']}'),
          Text('Scale reading: ${widget.batch.content['packedWeightKg']} kg'),
          const SizedBox(height: AppSpacing.sm),
          if (!widget.packed)
            AppButton(
              label: 'Pack batch',
              expand: false,
              isLoading: widget.saving,
              onPressed: widget.disabled ? null : widget.onPack,
            )
          else if (!widget.weighed)
            Row(
              children: [
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _weight,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Weight (kg)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppButton(
                  label: 'Record',
                  expand: false,
                  isLoading: widget.saving,
                  onPressed: widget.disabled
                      ? null
                      : () {
                          final value = double.tryParse(_weight.text);
                          if (value != null) widget.onRecordWeight(value);
                        },
                ),
              ],
            )
          else
            const Text('Packed and weighed'),
        ],
      ),
    );
  }
}
