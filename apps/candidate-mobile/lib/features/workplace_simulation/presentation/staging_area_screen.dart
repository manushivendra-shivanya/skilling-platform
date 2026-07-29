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

class StagingAreaScreen extends ConsumerStatefulWidget {
  const StagingAreaScreen({
    required this.missionId,
    required this.onBack,
    required this.onOpenLocationPlanning,
    super.key,
  });

  final String missionId;
  final VoidCallback onBack;
  final VoidCallback onOpenLocationPlanning;

  @override
  ConsumerState<StagingAreaScreen> createState() => _StagingAreaScreenState();
}

class _StagingAreaScreenState extends ConsumerState<StagingAreaScreen> {
  static const _taskId = 'open-putaway-list';
  static const _stageId = 'review-putaway-list';

  bool _saving = false;
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
          onPressed: _saving ? null : _exit,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Staging Area'),
      ),
      body: SafeArea(
        child: simulation.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AppErrorState(
            title: 'Staging Area unavailable',
            message: 'Your saved progress is safe. Retry loading the list.',
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
                .firstWhere((item) => item.workstationId == 'staging-area');
            if (value.mission.id != widget.missionId ||
                station.status == WorkstationStatus.locked) {
              return AppErrorState(
                title: 'Staging Area is locked',
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
                  screenId: 'staging-area',
                ),
              );
            }
            final reviewed = attempt.completedTaskIds.contains(_taskId);
            final list = scenario.resource('putaway-task-list');
            final items = (list.content['items'] as List)
                .cast<Map<String, Object?>>();
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        list.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text('Reference ${list.content['reference']}'),
                      const SizedBox(height: AppSpacing.lg),
                      for (final item in items) ...[
                        AppCard(
                          semanticLabel: '${item['name']}, ${item['sku']}',
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${item['name']}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    Text('${item['sku']}'),
                                  ],
                                ),
                              ),
                              Text('Qty ${item['quantity']}'),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      if (reviewed)
                        AppButton(
                          label: 'Continue to Location Planning',
                          isLoading: _saving,
                          onPressed: widget.onOpenLocationPlanning,
                        )
                      else
                        AppButton(
                          label: 'Mark reviewed',
                          isLoading: _saving,
                          onPressed: _saving ? null : _markReviewed,
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

  Future<void> _markReviewed() async {
    setState(() => _saving = true);
    final failure = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordAction(
          stageId: _stageId,
          taskId: _taskId,
          actionType: ActionType.openResource,
          targetId: 'putaway-task-list',
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (failure != null) {
      _showMessage('The putaway list could not be marked reviewed.');
      return;
    }
    widget.onOpenLocationPlanning();
  }

  Future<void> _exit() async {
    await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordWorkplaceEvent(
          AttemptAuditEventType.workstationScreenExited,
          screenId: 'staging-area',
        );
    if (mounted) widget.onBack();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
