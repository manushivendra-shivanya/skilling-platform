import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_state_view.dart';
import '../application/workplace_interaction_contracts.dart';
import '../application/workplace_simulation_controller.dart';
import '../domain/simulation_content.dart';
import '../domain/simulation_enums.dart';

class LocationPlanningScreen extends ConsumerStatefulWidget {
  const LocationPlanningScreen({
    required this.missionId,
    required this.onBack,
    required this.onOpenTransportPlacement,
    super.key,
  });

  final String missionId;
  final VoidCallback onBack;
  final VoidCallback onOpenTransportPlacement;

  @override
  ConsumerState<LocationPlanningScreen> createState() =>
      _LocationPlanningScreenState();
}

const _zoneOptions = [
  ('standard-shelving', 'Standard shelving'),
  ('hazmat-locker', 'Hazmat locker'),
  ('cold-storage-unit', 'Cold storage unit'),
  ('secure-cage', 'Secure cage'),
  ('overflow-storage', 'Overflow storage'),
];

class _LocationPlanningScreenState
    extends ConsumerState<LocationPlanningScreen> {
  static const _zoneTaskId = 'assign-storage-zone';
  static const _exceptionTaskId = 'record-location-exception';
  static const _stageId = 'plan-locations';

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
        title: const Text('Location Planning'),
      ),
      body: SafeArea(
        child: simulation.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AppErrorState(
            title: 'Location Planning unavailable',
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
                  (item) => item.workstationId == 'location-planning',
                );
            if (value.mission.id != widget.missionId ||
                station.status == WorkstationStatus.locked) {
              return AppErrorState(
                title: 'Location Planning is locked',
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
                  screenId: 'location-planning',
                ),
              );
            }
            final items = value.mission
                .task(_zoneTaskId)
                .targetResourceIds
                .map(scenario.resource)
                .toList();
            final zoned = {
              for (final action in attempt.actions)
                if (action.taskId == _zoneTaskId && action.targetId != null)
                  action.targetId,
            };
            final flagged = {
              for (final action in attempt.actions)
                if (action.taskId == _exceptionTaskId &&
                    action.targetId != null)
                  action.targetId,
            };
            final allZoned = attempt.completedTaskIds.contains(_zoneTaskId);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assign every item a storage zone',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Read each item carefully. Flag a capacity exception '
                        'if a zone cannot take the item.',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      for (final item in items) ...[
                        _ItemZoneCard(
                          item: item,
                          zoned: zoned.contains(item.id),
                          flagged: flagged.contains(item.id),
                          saving: _savingTargetId == item.id,
                          disabled: _savingTargetId != null,
                          onAssign: (zone) => _assignZone(item.id, zone),
                          onFlag: () => _flagException(item.id),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      Semantics(
                        liveRegion: true,
                        label: '${zoned.length} of ${items.length} items zoned',
                        child: Text(
                          '${zoned.length} of ${items.length} items zoned',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (allZoned)
                        AppButton(
                          label: 'Continue to Transport & Placement',
                          onPressed: widget.onOpenTransportPlacement,
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

  Future<void> _assignZone(String itemId, String zone) async {
    setState(() => _savingTargetId = itemId);
    final failure = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordAction(
          stageId: _stageId,
          taskId: _zoneTaskId,
          actionType: ActionType.classifyIssue,
          targetId: itemId,
          payload: {'selectedZone': zone},
        );
    if (!mounted) return;
    setState(() => _savingTargetId = null);
    if (failure != null) {
      _showMessage('The zone assignment could not be recorded.');
    }
  }

  Future<void> _flagException(String itemId) async {
    setState(() => _savingTargetId = itemId);
    final failure = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordAction(
          stageId: _stageId,
          taskId: _exceptionTaskId,
          actionType: ActionType.classifyIssue,
          targetId: itemId,
          payload: {'exceptionType': 'zone_at_capacity'},
        );
    if (!mounted) return;
    setState(() => _savingTargetId = null);
    if (failure != null) {
      _showMessage('The exception could not be recorded.');
    }
  }

  Future<void> _exit() async {
    await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordWorkplaceEvent(
          AttemptAuditEventType.workstationScreenExited,
          screenId: 'location-planning',
        );
    if (mounted) widget.onBack();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ItemZoneCard extends StatelessWidget {
  const _ItemZoneCard({
    required this.item,
    required this.zoned,
    required this.flagged,
    required this.saving,
    required this.disabled,
    required this.onAssign,
    required this.onFlag,
  });

  final SimulationResource item;
  final bool zoned;
  final bool flagged;
  final bool saving;
  final bool disabled;
  final ValueChanged<String> onAssign;
  final VoidCallback onFlag;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      semanticLabel: '${item.title}, ${zoned ? 'zoned' : 'not zoned'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.title, style: Theme.of(context).textTheme.titleMedium),
          Text('${item.content['sku']} · Qty ${item.content['quantity']}'),
          Text('${item.content['handlingNotes']}'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final option in _zoneOptions)
                ChoiceChip(
                  label: Text(option.$2),
                  selected: false,
                  onSelected: disabled ? null : (_) => onAssign(option.$1),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              if (zoned)
                const Text('Zoned')
              else if (saving)
                const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              const Spacer(),
              TextButton(
                onPressed: disabled || flagged ? null : onFlag,
                child: Text(flagged ? 'Exception flagged' : 'Flag exception'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
