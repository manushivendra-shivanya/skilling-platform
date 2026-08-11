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
import '../../sector_pack/presentation/sector_pack_icons.dart';
import '../../sector_pack/presentation/sector_pack_typography.dart';
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

  /// Purely local UI state -- the demo makes no scored/persisted attempt
  /// (see the "not scored, no employer evidence" banner above), so there is
  /// no underlying model to read a completed flag from. Set once any
  /// option has been picked during a demo session and never reset (unlike
  /// [_selectedDecision], which resets to null on close) so the
  /// "Recommended practice" entry card can show a completed look on return,
  /// the same shape the 4 real missions use for their own completed state.
  bool _demoCompleted = false;

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
    final pack = ref.watch(activeSectorPackProvider);
    if (_scoredOpen) {
      return _ScoredInventorySimulation(
        onClose: () => setState(() => _scoredOpen = false),
      );
    }
    if (_demoOpen) {
      return _InventoryDemo(
        pack: pack,
        selectedDecision: _selectedDecision,
        onSelect: (value) => setState(() {
          _selectedDecision = value;
          _demoCompleted = true;
        }),
        onClose: () => setState(() {
          _demoOpen = false;
          _selectedDecision = null;
        }),
      );
    }

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
        // The same shape as the 4 mission tickets above (a work order, a
        // tag, a title/description, a tear-off action) -- so it becomes a
        // real SectorTaskCard, matching the approved mock, rather than a
        // differently-styled AppCard for what is functionally identical
        // content.
        SectorTaskCard(
          pack: pack,
          workOrderLabel: 'DEMO-01',
          tagLabel: 'Practice',
          tone: _demoCompleted ? SectorTaskTone.cleared : SectorTaskTone.active,
          title: 'Inventory discrepancy',
          description:
              'Compare a system quantity with a physical count and choose a safe next action.',
          statLeft: _demoCompleted ? 'Completed' : 'Not started',
          tearLabel: _demoCompleted ? 'RETRY' : 'START',
          onTap: () => setState(() => _demoOpen = true),
          semanticLabel:
              'Inventory discrepancy demo. '
              '${_demoCompleted ? 'Completed' : 'Not started'}. '
              '${_demoCompleted ? 'Retry' : 'Start'} button.',
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Catalogue', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: SectorIcon(
              glyph: SectorGlyph.truck,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            title: const Text('Dispatch prioritisation'),
            subtitle: const Text('Preview planned • demonstration only'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: SectorIcon(
              glyph: SectorGlyph.mic,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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
                              leading: SectorIcon(
                                glyph: SectorGlyph.check,
                                color: pack.signalPalette.cleared,
                              ),
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

  /// The current step's step label, question, and two answer options --
  /// paired with their [_record] callbacks -- for [_WizardStepCard]. A
  /// record, not three separate `if`/`else if` branches building widgets
  /// directly, since the branch content is now identical shape every step
  /// (one dark focal card, two answer buttons) and only the copy changes.
  ({
    String stepLabel,
    String question,
    String primaryLabel,
    VoidCallback onPrimary,
    String secondaryLabel,
    VoidCallback onSecondary,
  })
  get _currentStep {
    return switch (_step) {
      0 => (
        stepLabel: 'STEP 1 OF 3 · VERIFY',
        question: 'Choose the first action.',
        primaryLabel: 'Recount the physical stock',
        onPrimary: () => _record('decision_selected', {'decision': 'recount'}),
        secondaryLabel: 'Overwrite the system quantity',
        onSecondary: () =>
            _record('decision_selected', {'decision': 'overwrite'}),
      ),
      1 => (
        stepLabel: 'STEP 2 OF 3 · AUDIT TRAIL',
        question: 'What do you do with the two records?',
        primaryLabel: 'Preserve both values and count notes',
        onPrimary: () => _record('records_preserved', const {}),
        secondaryLabel: 'Discard the original record',
        onSecondary: () => _record('record_discarded', const {}),
      ),
      _ => (
        stepLabel: 'STEP 3 OF 3 · ESCALATION',
        question: 'Choose the final response.',
        primaryLabel: 'Escalate the documented exception',
        onPrimary: () => _record('exception_escalated', const {}),
        secondaryLabel: 'Leave it for the next shift',
        onSecondary: () => _record('exception_ignored', const {}),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final pack = ref.watch(activeSectorPackProvider);
    if (_saving) {
      return const AppStateView(
        icon: Icons.calculate_outlined,
        title: 'Scoring simulation',
        message: 'Applying the published deterministic rubric.',
      );
    }
    if (_score != null) {
      return _buildResult(pack, _score!);
    }
    final step = _currentStep;
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
        _WizardStepCard(
          pack: pack,
          stepLabel: step.stepLabel,
          question: step.question,
          primaryLabel: step.primaryLabel,
          onPrimary: step.onPrimary,
          secondaryLabel: step.secondaryLabel,
          onSecondary: step.onSecondary,
          onRecordFailure: _recordTechnicalFailure,
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

  Widget _buildResult(SectorPack pack, SimulationScore score) {
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
        _ResultCard(pack: pack, score: score, onClose: widget.onClose),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'This evidence is explainable and reviewable. It must not be used as the sole basis for an employer rejection.',
        ),
      ],
    );
  }
}

/// The scored-simulation wizard's per-step focal card: a dark gradient
/// derived from `pack.primaryAccent`, the step counter, the question, and
/// the two answer options -- matches the approved
/// "Practice — remaining screens, styled" mock exactly.
///
/// The dark-gradient-from-`primaryAccent` derivation is the same formula
/// `SectorCredentialCard` already uses (`Color.lerp(primaryAccent, black,
/// 0.55/0.85)`), reused here deliberately: this is a genuine one-off focal
/// card, not persistent chrome, so it's the reviewed, intentional use of
/// that pattern -- not the bug the Learn tab bar hit this session (see
/// `AppColors.navy`'s doc comment in `app_colors.dart` for that story).
///
/// Contrast, computed from the actual `Color.lerp` output (not the
/// approved mock's `color-mix()` approximation -- confirmed they don't
/// land on identical numbers): white body text on warehouse's orange
/// `primaryAccent` (0xFFB85C13) runs 12.4:1 at the gradient's top-left
/// corner (`darkTop`) and 18.9:1 at its bottom-right corner (`darkBottom`),
/// both comfortably past WCAG AA (4.5:1) and AAA (7:1). The mock's caption
/// says "11-14:1 depending on step" -- close to `darkTop`'s real number but
/// not `darkBottom`'s; the real range is wider than the mock estimated.
class _WizardStepCard extends StatelessWidget {
  const _WizardStepCard({
    required this.pack,
    required this.stepLabel,
    required this.question,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
    required this.onRecordFailure,
  });

  final SectorPack pack;
  final String stepLabel;
  final String question;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final VoidCallback onSecondary;
  final VoidCallback onRecordFailure;

  @override
  Widget build(BuildContext context) {
    final darkTop = Color.lerp(pack.primaryAccent, Colors.black, 0.55)!;
    final darkBottom = Color.lerp(pack.primaryAccent, Colors.black, 0.85)!;
    // Same brightness-estimation approach `SectorTaskCard` uses for its
    // tone-coloured tag text: `signalPalette.active` (hazard amber here)
    // is light, so black reads correctly on it -- verified: black on
    // warehouse's hazard amber (0xFFF5B700) runs 11.7:1, comfortably past
    // AA; white on the same amber would only run 1.8:1, which is why this
    // is computed rather than hardcoded to white like the rest of the
    // card.
    final primaryOn =
        ThemeData.estimateBrightnessForColor(pack.signalPalette.active) ==
            Brightness.dark
        ? Colors.white
        : Colors.black;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [darkTop, darkBottom],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stepLabel,
            style: SectorPackTypography.monoLabel(
              color: Colors.white.withValues(alpha: 0.6),
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            question,
            style: SectorPackTypography.displayLabel(
              color: Colors.white,
              fontSize: 18,
              height: 1.22,
            ),
          ),
          const SizedBox(height: 16),
          _WizardOptionButton(
            label: primaryLabel,
            onTap: onPrimary,
            background: pack.signalPalette.active,
            foreground: primaryOn,
          ),
          const SizedBox(height: 8),
          _WizardOptionButton(label: secondaryLabel, onTap: onSecondary),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onRecordFailure,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.6),
                padding: EdgeInsets.zero,
                // TextButton's own default minimumSize is 36dp tall --
                // under Android's 48dp minimum tap target. This override
                // is the same fix `learning_screen.dart`'s
                // `_DownloadUtilityButton` documents for a hand-rolled
                // InkWell; here it's simpler since TextButton already
                // exposes the knob directly.
                minimumSize: const Size(0, kMinInteractiveDimension),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              icon: SectorIcon(
                glyph: SectorGlyph.cross,
                color: Colors.white.withValues(alpha: 0.55),
                size: 13,
              ),
              label: Text(
                'Record a demo network interruption',
                style: SectorPackTypography.monoLabel(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One answer button inside [_WizardStepCard]. `background == null` renders
/// the translucent-outline secondary style from the mock; a non-null
/// [background] (the primary option) fills solid.
class _WizardOptionButton extends StatelessWidget {
  const _WizardOptionButton({
    required this.label,
    required this.onTap,
    this.background,
    this.foreground,
  });

  final String label;
  final VoidCallback onTap;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final isPrimary = background != null;
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: background ?? Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: kMinInteractiveDimension,
            ),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: isPrimary
                ? null
                : BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
            child: Text(
              label,
              style: SectorPackTypography.bodySemiBold(
                color: foreground ?? Colors.white,
                fontSize: 13.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The scored-simulation result screen's focal card: a dark gradient
/// derived from `pack.signalPalette.cleared` for a pass, or
/// `pack.signalPalette.locked` for a fail/below-threshold score -- the
/// approved mock only shows the pass case, so the fail treatment (locked
/// tone, same derivation) is this build's judgement call, kept consistent
/// with how `SectorCredentialCard` already maps `locked` to a "not
/// cleared" state.
///
/// Pass threshold (`>=80`) matches `SimulationScoringEngine`'s own
/// threshold for its `explanation` copy -- kept in sync deliberately so
/// the card's tone always agrees with the text it's showing, not
/// duplicated business logic beyond styling.
///
/// Contrast (actual `Color.lerp` output): white text on warehouse's
/// `signalPalette.cleared` (green, 0xFF176B3A) runs 14.5:1 (`darkTop`) to
/// 19.4:1 (`darkBottom`); on `signalPalette.locked` (grey, 0xFF56635D) it
/// runs 14.1:1 to 19.2:1. Both bands are comfortably past WCAG AAA (7:1)
/// in every case.
class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.pack,
    required this.score,
    required this.onClose,
  });

  final SectorPack pack;
  final SimulationScore score;
  final VoidCallback onClose;

  static const int _passThreshold = 80;

  bool get _passed => score.totalScore >= _passThreshold;

  @override
  Widget build(BuildContext context) {
    final toneBase = _passed
        ? pack.signalPalette.cleared
        : pack.signalPalette.locked;
    final darkTop = Color.lerp(toneBase, Colors.black, 0.55)!;
    final darkBottom = Color.lerp(toneBase, Colors.black, 0.85)!;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [darkTop, darkBottom],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${score.totalScore}%',
            style: SectorPackTypography.monoLabel(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 38,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            score.explanation,
            style: SectorPackTypography.bodyRegular(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 16),
          for (final dimension in score.dimensionScores.entries)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      dimension.key.replaceAll('_', ' '),
                      style: SectorPackTypography.bodyRegular(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${dimension.value}%',
                    style: SectorPackTypography.monoLabel(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              border: Border(
                left: BorderSide(
                  width: 4,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ),
            child: Text(
              'Next improvement: ${score.improvement}',
              style: SectorPackTypography.bodyRegular(
                color: Colors.white.withValues(alpha: 0.86),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: Material(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: kMinInteractiveDimension,
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Text(
                    'Return to practice',
                    style: SectorPackTypography.bodySemiBold(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _correctDemoOption =
    'Recount, preserve records, and escalate the mismatch';

class _InventoryDemo extends StatelessWidget {
  const _InventoryDemo({
    required this.pack,
    required this.selectedDecision,
    required this.onSelect,
    required this.onClose,
  });

  final SectorPack pack;
  final String? selectedDecision;
  final ValueChanged<String> onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
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
          _correctDemoOption,
          'Ignore the difference until the shift ends',
        ]) ...[
          _DemoOptionCard(
            pack: pack,
            label: option,
            selected: selectedDecision == option,
            onTap: () => onSelect(option),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (selectedDecision != null) ...[
          const SizedBox(height: AppSpacing.md),
          // Correct pick reads `signalPalette.cleared`-toned green, same as
          // the mock; an incorrect pick reads `signalPalette.locked`-toned
          // instead of the same green -- this build's judgement call (the
          // mock only shows the correct-pick case), consistent with how
          // the result screen distinguishes pass/fail with the same two
          // tones rather than showing "good practice" green regardless of
          // the actual choice.
          Builder(
            builder: (context) {
              final correct = selectedDecision == _correctDemoOption;
              final tone = correct
                  ? pack.signalPalette.cleared
                  : pack.signalPalette.locked;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Color.lerp(surface, tone, 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border(left: BorderSide(width: 3, color: tone)),
                ),
                child: Text(
                  correct
                      ? 'Good practice: verify the count, keep an audit trail, and escalate according to SOP.'
                      : 'Try again: safe operations preserve records and escalate unexplained discrepancies.',
                  style: SectorPackTypography.bodyRegular(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 12.5,
                  ),
                ),
              );
            },
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

/// One selection card in [_InventoryDemo] -- `pack.primaryAccent`-toned
/// border/tint when selected, and a drawn radio glyph
/// ([SectorGlyph.radioSelected] / [SectorGlyph.radioUnselected]) instead of
/// the raw `Icons.check_circle` / `Icons.radio_button_unchecked` this
/// replaced, per the approved mock.
class _DemoOptionCard extends StatelessWidget {
  const _DemoOptionCard({
    required this.pack,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final SectorPack pack;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final divider = Theme.of(context).dividerColor;
    final ink = Theme.of(context).colorScheme.onSurface;
    final inkSoft = Theme.of(context).colorScheme.onSurfaceVariant;
    return Semantics(
      label: '$label. ${selected ? 'Selected' : 'Not selected'}',
      button: true,
      container: true,
      // excludeSemantics: true hides the descendant Text/icon's own
      // semantics (redundant with `label` above) -- but unlike
      // sector_credential_card.dart's info+CTA split, there's no separate
      // interactive child being protected here, this card *is* the one
      // tap target. Excluding descendants also drops the InkWell's own
      // tap-action semantics, so `onTap` is repeated explicitly on this
      // node to keep it screen-reader-activatable (verified via a real
      // debugDumpSemanticsTree() dump -- see this session's final report).
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected
            ? Color.lerp(surface, pack.primaryAccent, 0.08)
            : surface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: kMinInteractiveDimension,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? pack.primaryAccent : divider,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: ExcludeSemantics(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: SectorPackTypography.bodyRegular(
                        color: ink,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SectorIcon(
                    glyph: selected
                        ? SectorGlyph.radioSelected
                        : SectorGlyph.radioUnselected,
                    color: selected ? pack.primaryAccent : inkSoft,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
