import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_loading_progress.dart';
import '../../../core/widgets/app_state_view.dart';
import '../application/workplace_interaction_contracts.dart';
import '../application/workplace_simulation_controller.dart';
import '../domain/simulation_content.dart';
import '../domain/simulation_enums.dart';

class TransportPlacementScreen extends ConsumerStatefulWidget {
  const TransportPlacementScreen({
    required this.missionId,
    required this.onBack,
    required this.onOpenPutawayOffice,
    super.key,
  });

  final String missionId;
  final VoidCallback onBack;
  final VoidCallback onOpenPutawayOffice;

  @override
  ConsumerState<TransportPlacementScreen> createState() =>
      _TransportPlacementScreenState();
}

class _TransportPlacementScreenState
    extends ConsumerState<TransportPlacementScreen> {
  static const _moveTaskId = 'transport-and-place-items';
  static const _scanTaskId = 'scan-items-to-bins';
  static const _countTaskId = 'confirm-quantities-placed';
  static const _stageId = 'transport-and-place';

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
        title: const Text('Transport and Placement'),
      ),
      body: SafeArea(
        child: simulation.when(
          loading: () => const Center(
            child: AppLoadingProgressBar(label: 'Loading your progress…'),
          ),
          error: (_, _) => AppErrorState(
            title: 'Transport and Placement unavailable',
            message: 'Your saved progress is safe. Retry loading items.',
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
                  (item) => item.workstationId == 'transport-placement',
                );
            if (value.mission.id != widget.missionId ||
                station.status == WorkstationStatus.locked) {
              return AppErrorState(
                title: 'Transport and Placement is locked',
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
                  screenId: 'transport-placement',
                ),
              );
            }
            final items = value.mission
                .task(_moveTaskId)
                .targetResourceIds
                .map(scenario.resource)
                .toList();
            Set<String?> targetsFor(String taskId) => {
              for (final action in attempt.actions)
                if (action.taskId == taskId && action.targetId != null)
                  action.targetId,
            };
            final moved = targetsFor(_moveTaskId);
            final scanned = targetsFor(_scanTaskId);
            final counted = targetsFor(_countTaskId);
            final allDone =
                attempt.completedTaskIds.contains(_moveTaskId) &&
                attempt.completedTaskIds.contains(_scanTaskId) &&
                attempt.completedTaskIds.contains(_countTaskId);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Move, place and confirm every item',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Move each item safely, scan to confirm the bin, '
                        'then confirm the quantity placed.',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      for (final item in items) ...[
                        _ItemTransportCard(
                          item: item,
                          moved: moved.contains(item.id),
                          scanned: scanned.contains(item.id),
                          counted: counted.contains(item.id),
                          saving: _savingTargetId == item.id,
                          disabled: _savingTargetId != null,
                          onMove: () => _moveItem(item.id),
                          onScan: () => _scanItem(item.id),
                          onConfirmQuantity: (qty) =>
                              _confirmQuantity(item.id, qty),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      Semantics(
                        liveRegion: true,
                        label:
                            '${counted.length} of ${items.length} items confirmed placed',
                        child: Text(
                          '${counted.length} of ${items.length} items confirmed placed',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (allDone)
                        AppButton(
                          label: 'Continue to Putaway Office',
                          onPressed: widget.onOpenPutawayOffice,
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

  Future<void> _moveItem(String itemId) async {
    setState(() => _savingTargetId = itemId);
    final failure = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordAction(
          stageId: _stageId,
          taskId: _moveTaskId,
          actionType: ActionType.moveItem,
          targetId: itemId,
          payload: const {'placed': true, 'safeHandlingConfirmed': true},
        );
    if (!mounted) return;
    setState(() => _savingTargetId = null);
    if (failure != null) {
      _showMessage('The item could not be moved.');
    }
  }

  Future<void> _scanItem(String itemId) async {
    setState(() => _savingTargetId = itemId);
    final failure = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordAction(
          stageId: _stageId,
          taskId: _scanTaskId,
          actionType: ActionType.scanBarcode,
          targetId: itemId,
          payload: const {'scanStatus': 'matched'},
        );
    if (!mounted) return;
    setState(() => _savingTargetId = null);
    if (failure != null) {
      _showMessage('The scan could not be recorded.');
    }
  }

  Future<void> _confirmQuantity(String itemId, int quantity) async {
    setState(() => _savingTargetId = itemId);
    final failure = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordAction(
          stageId: _stageId,
          taskId: _countTaskId,
          actionType: ActionType.countQuantity,
          targetId: itemId,
          payload: {'placedQuantity': quantity},
        );
    if (!mounted) return;
    setState(() => _savingTargetId = null);
    if (failure != null) {
      _showMessage('The placed quantity could not be recorded.');
    }
  }

  Future<void> _exit() async {
    await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordWorkplaceEvent(
          AttemptAuditEventType.workstationScreenExited,
          screenId: 'transport-placement',
        );
    if (mounted) widget.onBack();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ItemTransportCard extends StatefulWidget {
  const _ItemTransportCard({
    required this.item,
    required this.moved,
    required this.scanned,
    required this.counted,
    required this.saving,
    required this.disabled,
    required this.onMove,
    required this.onScan,
    required this.onConfirmQuantity,
  });

  final SimulationResource item;
  final bool moved;
  final bool scanned;
  final bool counted;
  final bool saving;
  final bool disabled;
  final VoidCallback onMove;
  final VoidCallback onScan;
  final ValueChanged<int> onConfirmQuantity;

  @override
  State<_ItemTransportCard> createState() => _ItemTransportCardState();
}

class _ItemTransportCardState extends State<_ItemTransportCard> {
  late final TextEditingController _quantity = TextEditingController(
    text: '${widget.item.content['quantity']}',
  );

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      semanticLabel: widget.item.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.item.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text('${widget.item.content['sku']}'),
          const SizedBox(height: AppSpacing.sm),
          if (!widget.moved)
            AppButton(
              label: 'Move and place',
              expand: false,
              isLoading: widget.saving,
              onPressed: widget.disabled ? null : widget.onMove,
            )
          else if (!widget.scanned)
            AppButton(
              label: 'Scan to confirm bin',
              expand: false,
              isLoading: widget.saving,
              onPressed: widget.disabled ? null : widget.onScan,
            )
          else if (!widget.counted)
            Row(
              children: [
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _quantity,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Placed qty',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppButton(
                  label: 'Confirm',
                  expand: false,
                  isLoading: widget.saving,
                  onPressed: widget.disabled
                      ? null
                      : () {
                          final value = int.tryParse(_quantity.text);
                          if (value != null) widget.onConfirmQuantity(value);
                        },
                ),
              ],
            )
          else
            const Text('Placed, scanned and confirmed'),
        ],
      ),
    );
  }
}
