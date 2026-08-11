import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/analytics/analytics_event.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../intelligence/domain/candidate_intelligence.dart';
import '../../intelligence/domain/simulation_scoring_engine.dart';
import '../../intelligence/presentation/candidate_intelligence_controller.dart';
import '../../sector_pack/application/active_sector_pack_provider.dart';
import '../../sector_pack/domain/sector_pack.dart';
import '../../sector_pack/presentation/sector_task_card.dart';
import '../../workplace_simulation/application/workplace_simulation_controller.dart';
import '../../workplace_simulation/domain/simulation_enums.dart';

class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({required this.onOpenWorkplaceSimulation, super.key});

  final void Function(String missionId) onOpenWorkplaceSimulation;

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _WorkplaceMissionEntry {
  const _WorkplaceMissionEntry({
    required this.missionId,
    required this.workOrderLabel,
    required this.title,
    required this.meta,
    required this.difficultyLabel,
  });

  final String missionId;
  final String workOrderLabel;
  final String title;
  final String meta;
  final String difficultyLabel;
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  bool _demoOpen = false;
  bool _scoredOpen = false;
  String? _selectedDecision;

  static const _missions = [
    _WorkplaceMissionEntry(
      missionId: WorkplaceSimulationController.missionId,
      workOrderLabel: 'WM-01',
      title: 'Receive an Incoming Shipment',
      meta: 'Logistics · Warehouse Associate · Approximately 20 minutes',
      difficultyLabel: 'Beginner',
    ),
    _WorkplaceMissionEntry(
      missionId: WorkplaceSimulationController.putAwayMissionId,
      workOrderLabel: 'WM-02',
      title: 'Put Away Incoming Stock',
      meta: 'Logistics · Warehouse Associate · Approximately 20 minutes',
      difficultyLabel: 'Beginner',
    ),
    _WorkplaceMissionEntry(
      missionId: WorkplaceSimulationController.processingMissionId,
      workOrderLabel: 'WM-03',
      title: 'Process Incoming Batch',
      meta: 'Logistics · Warehouse Associate · Approximately 22 minutes',
      difficultyLabel: 'Intermediate',
    ),
    _WorkplaceMissionEntry(
      missionId: WorkplaceSimulationController.dispatchMissionId,
      workOrderLabel: 'WM-04',
      title: 'Dispatch Delivery Route',
      meta: 'Logistics · Warehouse Associate · Approximately 24 minutes',
      difficultyLabel: 'Intermediate',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (_scoredOpen) {
      return _ScoredInventorySimulation(
        onClose: () => setState(() => _scoredOpen = false),
      );
    }
    if (_demoOpen) {
      return _InventoryDemo(
        selectedDecision: _selectedDecision,
        onSelect: (value) => setState(() => _selectedDecision = value),
        onClose: () => setState(() {
          _demoOpen = false;
          _selectedDecision = null;
        }),
      );
    }

    final pack = ref.watch(activeSectorPackProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        112,
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.warningSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Practice demonstrations are not scored assessments and create no employer evidence.',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SectorTaskCard(
          pack: pack,
          workOrderLabel: 'SIM-01',
          tagLabel: 'Scored',
          tone: SectorTaskTone.emphasis,
          title: 'Scored inventory simulation',
          description:
              'Immutable v1 scenario with ordered events, deterministic scoring, explanations, and evidence.',
          tearLabel: 'START',
          onTap: () => setState(() => _scoredOpen = true),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final mission in _missions) ...[
          _WorkplaceMissionCard(
            pack: pack,
            entry: mission,
            onOpen: () => widget.onOpenWorkplaceSimulation(mission.missionId),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Text(
          'Recommended practice',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          backgroundColor: AppColors.brandSoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Inventory discrepancy',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Compare a system quantity with a physical count and choose a safe next action.',
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Start demonstration',
                onPressed: () => setState(() => _demoOpen = true),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Catalogue', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        const AppCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.local_shipping_outlined),
            title: Text('Dispatch prioritisation'),
            subtitle: Text('Preview planned • demonstration only'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.record_voice_over_outlined),
            title: const Text('Voice workplace practice'),
            subtitle: const Text('Planned • microphone is not active'),
            onTap: () => showAppSnackBar(
              context: context,
              message:
                  'Voice practice is not active. No microphone permission was requested.',
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Attempt history', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        ref
            .watch(candidateIntelligenceControllerProvider)
            .when(
              loading: () => const AppStateView(
                icon: Icons.hourglass_top,
                title: 'Loading attempts',
                message: 'Restoring your scored simulation history.',
              ),
              error: (error, stackTrace) => const AppErrorState(
                title: 'Attempt history unavailable',
                message:
                    'Retry from this tab when your secure data is available.',
              ),
              data: (state) => state.simulationScores.isEmpty
                  ? const SizedBox(
                      height: 220,
                      child: AppEmptyState(
                        title: 'No scored attempts',
                        message:
                            'Demonstrations do not appear as assessed evidence or affect reliability.',
                      ),
                    )
                  : Column(
                      children: [
                        for (final score in state.simulationScores.reversed)
                          AppCard(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.verified_outlined),
                              title: Text(
                                'Inventory simulation • ${score.totalScore}%',
                              ),
                              subtitle: Text(score.explanation),
                            ),
                          ),
                      ],
                    ),
            ),
      ],
    );
  }
}

/// One [SectorTaskCard] driven by a workplace mission's
/// [workplaceSimulationControllerProvider] state -- loading, error
/// (unavailable), not started, in progress/paused, and
/// completed/failed all covered.
class _WorkplaceMissionCard extends ConsumerWidget {
  const _WorkplaceMissionCard({
    required this.pack,
    required this.entry,
    required this.onOpen,
  });

  final SectorPack pack;
  final _WorkplaceMissionEntry entry;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      workplaceSimulationControllerProvider(entry.missionId),
    );
    return state.when(
      loading: () => SectorTaskCard(
        pack: pack,
        workOrderLabel: entry.workOrderLabel,
        tagLabel: entry.difficultyLabel,
        tone: SectorTaskTone.muted,
        title: entry.title,
        description: entry.meta,
        statLeft: 'Loading simulation',
        tearLabel: '···',
        unavailable: true,
      ),
      error: (error, stackTrace) => SectorTaskCard(
        pack: pack,
        workOrderLabel: entry.workOrderLabel,
        tagLabel: 'Unavailable',
        tone: SectorTaskTone.muted,
        title: entry.title,
        description: entry.meta,
        statLeft: 'Content unavailable',
        tearLabel: 'N/A',
        unavailable: true,
      ),
      data: (value) {
        final attempt = value.attempt;
        final SectorTaskTone tone;
        final String statLeft;
        final String tearLabel;
        if (attempt == null) {
          tone = SectorTaskTone.emphasis;
          statLeft = 'Not started';
          tearLabel = 'START';
        } else if (attempt.state == MissionState.completed ||
            attempt.state == MissionState.failed) {
          tone = SectorTaskTone.cleared;
          statLeft = attempt.state == MissionState.completed
              ? 'Completed'
              : 'Attempt failed';
          tearLabel = 'RETRY';
        } else {
          tone = SectorTaskTone.active;
          statLeft = 'In progress';
          tearLabel = 'CONTINUE';
        }
        return SectorTaskCard(
          pack: pack,
          workOrderLabel: entry.workOrderLabel,
          tagLabel: entry.difficultyLabel,
          tone: tone,
          title: entry.title,
          description: entry.meta,
          statLeft: statLeft,
          tearLabel: tearLabel,
          onTap: onOpen,
          semanticLabel: '${entry.title}. $statLeft. $tearLabel button.',
        );
      },
    );
  }
}

class _ScoredInventorySimulation extends ConsumerStatefulWidget {
  const _ScoredInventorySimulation({required this.onClose});

  final VoidCallback onClose;

  @override
  ConsumerState<_ScoredInventorySimulation> createState() =>
      _ScoredInventorySimulationState();
}

class _ScoredInventorySimulationState
    extends ConsumerState<_ScoredInventorySimulation> {
  final List<SimulationEvent> _events = [];
  var _step = 0;
  var _saving = false;
  SimulationScore? _score;

  @override
  Widget build(BuildContext context) {
    if (_saving) {
      return const AppStateView(
        icon: Icons.calculate_outlined,
        title: 'Scoring simulation',
        message: 'Applying the published deterministic rubric.',
      );
    }
    if (_score != null) {
      return _buildResult(_score!);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        112,
      ),
      children: [
        Text(
          'Inventory discrepancy assessment',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text('Scenario v1 • System: 24 units • Physical count: 21 units'),
        const SizedBox(height: AppSpacing.md),
        const AppCard(
          backgroundColor: AppColors.infoSoft,
          child: Text(
            'Only your selected operational actions are scored. Network or app failures are recorded separately and never reduce reliability.',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_step == 0) ...[
          Text('Step 1: verify', style: Theme.of(context).textTheme.titleLarge),
          const Text('Choose the first action.'),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Recount the physical stock',
            onPressed: () =>
                _record('decision_selected', {'decision': 'recount'}),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Overwrite the system quantity',
            variant: AppButtonVariant.secondary,
            onPressed: () =>
                _record('decision_selected', {'decision': 'overwrite'}),
          ),
        ] else if (_step == 1) ...[
          Text(
            'Step 2: audit trail',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Text('What do you do with the two records?'),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Preserve both values and count notes',
            onPressed: () => _record('records_preserved', const {}),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Discard the original record',
            variant: AppButtonVariant.secondary,
            onPressed: () => _record('record_discarded', const {}),
          ),
        ] else ...[
          Text(
            'Step 3: escalation',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Text('Choose the final response.'),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Escalate the documented exception',
            onPressed: () => _record('exception_escalated', const {}),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Leave it for the next shift',
            variant: AppButtonVariant.secondary,
            onPressed: () => _record('exception_ignored', const {}),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        TextButton.icon(
          onPressed: _recordTechnicalFailure,
          icon: const Icon(Icons.wifi_off_outlined),
          label: const Text('Record a demo network interruption'),
        ),
      ],
    );
  }

  void _record(String type, Map<String, Object?> payload) {
    setState(() {
      _events.add(
        SimulationEvent(
          sequence: _events.length + 1,
          type: type,
          payload: payload,
          clientTime: DateTime.now(),
        ),
      );
      _step += 1;
    });
    if (_step == 3) {
      _submit();
    }
  }

  void _recordTechnicalFailure() {
    setState(() {
      _events.add(
        SimulationEvent(
          sequence: _events.length + 1,
          type: 'network_interrupted',
          payload: const {},
          clientTime: DateTime.now(),
          isTechnical: true,
        ),
      );
    });
    showAppSnackBar(
      context: context,
      message: 'Technical event recorded separately with zero score penalty.',
    );
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final now = DateTime.now();
    final score = SimulationScoringEngine.scoreInventoryDiscrepancy(
      attemptId: 'inventory-${now.microsecondsSinceEpoch}',
      events: _events,
      completedAt: now,
    );
    final failure = await ref
        .read(candidateIntelligenceControllerProvider.notifier)
        .saveSimulation(score);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (failure == null) _score = score;
    });
    if (failure != null) {
      showAppSnackBar(
        context: context,
        message: failure.message,
        tone: AppMessageTone.error,
      );
    } else {
      await ref
          .read(analyticsTrackerProvider)
          .track(AnalyticsEvent.simulationSubmitted(score.simulationVersion));
    }
  }

  Widget _buildResult(SimulationScore score) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        112,
      ),
      children: [
        Text(
          'Simulation result',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          backgroundColor: AppColors.brandSoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${score.totalScore}%',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              Text(score.explanation),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final dimension in score.dimensionScores.entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(dimension.key.replaceAll('_', ' ')),
            trailing: Text('${dimension.value}%'),
          ),
        const SizedBox(height: AppSpacing.sm),
        Text('Next improvement: ${score.improvement}'),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'This evidence is explainable and reviewable. It must not be used as the sole basis for an employer rejection.',
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(label: 'Return to practice', onPressed: widget.onClose),
      ],
    );
  }
}

class _InventoryDemo extends StatelessWidget {
  const _InventoryDemo({
    required this.selectedDecision,
    required this.onSelect,
    required this.onClose,
  });

  final String? selectedDecision;
  final ValueChanged<String> onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        112,
      ),
      children: [
        Text(
          'Inventory discrepancy demo',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text('System: 24 units • Physical count: 21 units'),
        const SizedBox(height: AppSpacing.lg),
        for (final option in const [
          'Change the system quantity immediately',
          'Recount, preserve records, and escalate the mismatch',
          'Ignore the difference until the shift ends',
        ]) ...[
          AppCard(
            onTap: () => onSelect(option),
            semanticLabel:
                '$option. ${selectedDecision == option ? 'Selected' : 'Not selected'}',
            backgroundColor: selectedDecision == option
                ? AppColors.brandSoft
                : AppColors.surface,
            child: Row(
              children: [
                Expanded(child: Text(option)),
                Icon(
                  selectedDecision == option
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: selectedDecision == option
                      ? AppColors.brand
                      : AppColors.outline,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (selectedDecision != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            backgroundColor: AppColors.infoSoft,
            child: Text(
              selectedDecision ==
                      'Recount, preserve records, and escalate the mismatch'
                  ? 'Good practice: verify the count, keep an audit trail, and escalate according to SOP.'
                  : 'Try again: safe operations preserve records and escalate unexplained discrepancies.',
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        const Text(
          'If the app or network fails during a future assessment, the technical failure must not reduce candidate reliability.',
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Return to practice',
          variant: AppButtonVariant.secondary,
          onPressed: onClose,
        ),
      ],
    );
  }
}
