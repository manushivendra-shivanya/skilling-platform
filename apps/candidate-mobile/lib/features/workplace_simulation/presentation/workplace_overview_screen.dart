import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_state_view.dart';
import '../application/workplace_interaction_contracts.dart';
import '../application/workplace_simulation_controller.dart';
import '../domain/simulation_enums.dart';

class WorkplaceOverviewScreen extends ConsumerStatefulWidget {
  const WorkplaceOverviewScreen({
    required this.missionId,
    required this.onOpenDocumentDesk,
    required this.onOpenReceivingDock,
    required this.onOpenInspectionZone,
    required this.onReturnToPractice,
    super.key,
  });

  final String missionId;
  final VoidCallback onOpenDocumentDesk;
  final VoidCallback onOpenReceivingDock;
  final VoidCallback onOpenInspectionZone;
  final VoidCallback onReturnToPractice;

  @override
  ConsumerState<WorkplaceOverviewScreen> createState() =>
      _WorkplaceOverviewScreenState();
}

class _WorkplaceOverviewScreenState
    extends ConsumerState<WorkplaceOverviewScreen> {
  Timer? _timer;
  bool _tracked = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workplaceSimulationControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workplace Overview'),
        actions: [
          IconButton(
            tooltip: 'Pause shift',
            onPressed: _pause,
            icon: const Icon(Icons.pause_circle_outline),
          ),
          IconButton(
            tooltip: 'Save and exit',
            onPressed: _saveAndExit,
            icon: const Icon(Icons.exit_to_app),
          ),
        ],
      ),
      body: SafeArea(
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AppErrorState(
            title: 'Workplace unavailable',
            message: 'Your saved attempt is safe. Retry loading the workplace.',
            actionLabel: 'Retry',
            onAction: () =>
                ref.invalidate(workplaceSimulationControllerProvider),
          ),
          data: (value) {
            if (value.attempt == null ||
                value.scenario == null ||
                value.mission.id != widget.missionId) {
              return AppErrorState(
                title: 'Workplace content is incomplete',
                message: 'Return to Practice and reopen this simulation.',
                actionLabel: 'Return to Practice',
                onAction: widget.onReturnToPractice,
              );
            }
            if (!_tracked) {
              _tracked = true;
              unawaited(
                ref
                    .read(workplaceSimulationControllerProvider.notifier)
                    .recordWorkplaceEvent(
                      AttemptAuditEventType.workplaceOverviewOpened,
                    ),
              );
            }
            final overview = ref
                .read(workplaceSimulationControllerProvider.notifier)
                .workplaceOverview;
            return LayoutBuilder(
              builder: (context, constraints) {
                final textScale = MediaQuery.textScalerOf(context).scale(1);
                final columns = constraints.maxWidth >= 720 && textScale < 1.6
                    ? 2
                    : 1;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 920),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            overview.missionTitle,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '${overview.workplaceName} · '
                            '${overview.departmentName}',
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Elapsed ${_duration(overview.elapsedSimulationDuration)} · '
                            '${(overview.missionProgress * 100).round()}% complete · '
                            '${overview.completedStageCount} of '
                            '${overview.totalStageCount} stages',
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          if (columns == 1)
                            Column(
                              children: [
                                for (final station
                                    in overview.workstations) ...[
                                  _StationCard(
                                    station: station,
                                    onTap: () => _openStation(station),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                ],
                              ],
                            )
                          else
                            GridView.count(
                              crossAxisCount: columns,
                              mainAxisSpacing: AppSpacing.md,
                              crossAxisSpacing: AppSpacing.md,
                              childAspectRatio: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                for (final station in overview.workstations)
                                  _StationCard(
                                    station: station,
                                    onTap: () => _openStation(station),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _openStation(WorkstationViewModel station) async {
    final result = await ref
        .read(workplaceSimulationControllerProvider.notifier)
        .openWorkstation(station.workstationId);
    if (!mounted) return;
    if (result == OpenWorkstationResult.workstationLocked) {
      _showMessage(station.supportingText);
      return;
    }
    if (result != OpenWorkstationResult.success) {
      _showMessage('This workstation cannot be opened.');
      return;
    }
    switch (station.workstationId) {
      case 'document-desk':
        widget.onOpenDocumentDesk();
      case 'receiving-dock':
        widget.onOpenReceivingDock();
      case 'inspection-zone':
        widget.onOpenInspectionZone();
      default:
        _showMessage('This workstation is coming next.');
    }
  }

  Future<void> _pause() async {
    final controller = ref.read(workplaceSimulationControllerProvider.notifier);
    final overview = controller.workplaceOverview;
    if (overview.canResume) {
      await controller.resumeAttempt();
      return;
    }
    if (!overview.canPause) return;
    final failure = await controller.pauseAttempt();
    if (!mounted) return;
    if (failure != null) {
      _showMessage(failure.message);
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Shift paused'),
        content: const Text('Simulation time is stopped. Your work is saved.'),
        actions: [
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final result = await controller.saveAndExit();
              if (!mounted) return;
              if (result != SaveAndExitResult.success) {
                _showMessage(
                  'Your shift could not be saved. Please try again.',
                );
                return;
              }
              navigator.pop();
              widget.onReturnToPractice();
            },
            child: const Text('Exit to Practice'),
          ),
          FilledButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              await controller.resumeAttempt();
              if (mounted) navigator.pop();
            },
            child: const Text('Resume shift'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAndExit() async {
    final result = await ref
        .read(workplaceSimulationControllerProvider.notifier)
        .saveAndExit();
    if (!mounted) return;
    if (result == SaveAndExitResult.success) {
      widget.onReturnToPractice();
      return;
    }
    _showMessage('Your shift could not be saved. Please try again.');
  }

  String _duration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _StationCard extends StatelessWidget {
  const _StationCard({required this.station, required this.onTap});

  final WorkstationViewModel station;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    semanticLabel:
        '${station.name}, ${station.progressLabel}, '
        '${station.isRecommended ? 'recommended' : 'not recommended'}',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Icon(
              station.status == WorkstationStatus.locked
                  ? Icons.lock
                  : Icons.store,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                station.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          station.supportingText,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${station.progressLabel}'
          '${station.isRecommended ? ' · Recommended' : ''}',
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ],
    ),
  );
}
