import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/analytics/analytics_event.dart';
import '../../../core/errors/app_failure_localization.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../intelligence/domain/candidate_intelligence.dart';
import '../../intelligence/domain/simulation_scoring_engine.dart';
import '../../intelligence/presentation/candidate_intelligence_controller.dart';
import '../../micro_lessons/presentation/not_employer_evidence_banner.dart';
import '../../sector_pack/application/active_sector_pack_provider.dart';
import '../../sector_pack/domain/sector_pack.dart';
import '../../sector_pack/presentation/sector_index_row.dart';
import '../../sector_pack/presentation/sector_pack_icons.dart';
import '../../sector_pack/presentation/sector_pack_typography.dart';
import '../../sector_pack/presentation/sector_signal_dot.dart';
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

  List<_WorkplaceMissionEntry> _missions(AppLocalizations l10n) => [
    _WorkplaceMissionEntry(
      missionId: WorkplaceSimulationController.missionId,
      workOrderLabel: 'WM-01',
      title: l10n.practiceMissionReceiveTitle,
      meta: l10n.practiceMissionMeta(20),
      difficultyLabel: l10n.practiceDifficultyBeginner,
    ),
    _WorkplaceMissionEntry(
      missionId: WorkplaceSimulationController.putAwayMissionId,
      workOrderLabel: 'WM-02',
      title: l10n.practiceMissionPutAwayTitle,
      meta: l10n.practiceMissionMeta(20),
      difficultyLabel: l10n.practiceDifficultyBeginner,
    ),
    _WorkplaceMissionEntry(
      missionId: WorkplaceSimulationController.processingMissionId,
      workOrderLabel: 'WM-03',
      title: l10n.practiceMissionProcessTitle,
      meta: l10n.practiceMissionMeta(22),
      difficultyLabel: l10n.practiceDifficultyIntermediate,
    ),
    _WorkplaceMissionEntry(
      missionId: WorkplaceSimulationController.dispatchMissionId,
      workOrderLabel: 'WM-04',
      title: l10n.practiceMissionDispatchTitle,
      meta: l10n.practiceMissionMeta(24),
      difficultyLabel: l10n.practiceDifficultyIntermediate,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
        // Shared with micro_lessons' clip list/detail screens -- this was a
        // near-verbatim hand-rolled duplicate of NotEmployerEvidenceBanner
        // (same AppColors.warningSoft container, same 12px radius). Practice
        // sits above scored simulations too, so it keeps its own wording via
        // the optional `message` override rather than the micro-lesson
        // default.
        NotEmployerEvidenceBanner(message: l10n.practiceBannerMessage),
        const SizedBox(height: AppSpacing.md),
        SectorTaskCard(
          pack: pack,
          workOrderLabel: 'SIM-01',
          tagLabel: l10n.practiceTagScored,
          tone: SectorTaskTone.emphasis,
          title: l10n.practiceScoredSimTitle,
          description: l10n.practiceScoredSimDescription,
          tearLabel: l10n.practiceTearStart,
          onTap: () => setState(() => _scoredOpen = true),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final mission in _missions(l10n)) ...[
          _WorkplaceMissionCard(
            pack: pack,
            entry: mission,
            onOpen: () => widget.onOpenWorkplaceSimulation(mission.missionId),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Text(
          l10n.practiceRecommendedTitle,
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
          tagLabel: l10n.practiceTagPractice,
          tone: _demoCompleted ? SectorTaskTone.cleared : SectorTaskTone.active,
          title: l10n.practiceDemoTitle,
          description: l10n.practiceDemoDescription,
          statLeft: _demoCompleted
              ? l10n.practiceStatCompleted
              : l10n.practiceStatNotStarted,
          tearLabel: _demoCompleted
              ? l10n.practiceTearRetry
              : l10n.practiceTearStart,
          onTap: () => setState(() => _demoOpen = true),
          semanticLabel: l10n.practiceDemoSemanticLabel(
            _demoCompleted
                ? l10n.practiceStatCompleted
                : l10n.practiceStatNotStarted,
            _demoCompleted ? l10n.practiceTearRetry : l10n.practiceTearStart,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          l10n.practiceCatalogueTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        // SectorIndexRow, the same structural row Learning uses for its
        // lesson list -- these two entries were previously a plain
        // AppCard+ListTile, the exact seam this pass closes: Practice
        // otherwise commits to the sector-pack idiom top to bottom.
        // `locked: true` is this widget's existing "unavailable" state
        // (muted colours + lock glyph), reused here for "not built yet"
        // rather than a generic disabled ListTile -- it preserves the same
        // "Preview planned • demonstration only" honesty, just in the
        // sector-pack visual language.
        SectorIndexRow(
          pack: pack,
          indexLabel: 'CAT-01',
          glyph: SectorGlyph.truck,
          title: l10n.practiceCatDispatchTitle,
          statusText: l10n.practicePreviewPlannedStatus,
          locked: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        SectorIndexRow(
          pack: pack,
          indexLabel: 'CAT-02',
          glyph: SectorGlyph.mic,
          title: l10n.practiceCatVoiceTitle,
          statusText: l10n.practiceMicPlannedStatus,
          locked: true,
          onTap: () => showAppSnackBar(
            context: context,
            message: l10n.practiceVoiceSnackbar,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          l10n.practiceAttemptHistoryTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        ref
            .watch(candidateIntelligenceControllerProvider)
            .when(
              loading: () => AppStateView(
                icon: Icons.hourglass_top,
                title: l10n.practiceLoadingAttemptsTitle,
                message: l10n.practiceLoadingAttemptsMessage,
              ),
              error: (error, stackTrace) => AppErrorState(
                title: l10n.practiceAttemptErrorTitle,
                message: l10n.practiceAttemptErrorMessage,
              ),
              data: (state) => state.simulationScores.isEmpty
                  ? SizedBox(
                      height: 220,
                      child: AppEmptyState(
                        title: l10n.practiceNoAttemptsTitle,
                        message: l10n.practiceNoAttemptsMessage,
                      ),
                    )
                  : Column(
                      children: [
                        // Same SectorIndexRow shape as the Catalogue rows
                        // above and Learning's own lesson list -- was
                        // AppCard+ListTile. `signalState: cleared` (rather
                        // than `locked`) matches how Learning marks a
                        // completed lesson: the check glyph plus a cleared
                        // signal dot, not a recoloured icon.
                        for (final (index, score)
                            in state.simulationScores.reversed.indexed)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: SectorIndexRow(
                              pack: pack,
                              indexLabel:
                                  'ATT-${(index + 1).toString().padLeft(2, '0')}',
                              glyph: SectorGlyph.check,
                              title: l10n.practiceAttemptRowTitle(
                                score.totalScore,
                              ),
                              statusText: score.explanation,
                              signalState: SectorSignalState.cleared,
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
    final l10n = AppLocalizations.of(context);
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
        statLeft: l10n.practiceStatLoadingSimulation,
        tearLabel: '···',
        unavailable: true,
      ),
      error: (error, stackTrace) => SectorTaskCard(
        pack: pack,
        workOrderLabel: entry.workOrderLabel,
        tagLabel: l10n.practiceTagUnavailable,
        tone: SectorTaskTone.muted,
        title: entry.title,
        description: entry.meta,
        statLeft: l10n.practiceStatContentUnavailable,
        tearLabel: l10n.practiceTearNA,
        unavailable: true,
      ),
      data: (value) {
        final attempt = value.attempt;
        final SectorTaskTone tone;
        final String statLeft;
        final String tearLabel;
        if (attempt == null) {
          tone = SectorTaskTone.emphasis;
          statLeft = l10n.practiceStatNotStarted;
          tearLabel = l10n.practiceTearStart;
        } else if (attempt.state == MissionState.completed ||
            attempt.state == MissionState.failed) {
          tone = SectorTaskTone.cleared;
          statLeft = attempt.state == MissionState.completed
              ? l10n.practiceStatCompleted
              : l10n.practiceStatAttemptFailed;
          tearLabel = l10n.practiceTearRetry;
        } else {
          tone = SectorTaskTone.active;
          statLeft = l10n.practiceStatInProgress;
          tearLabel = l10n.practiceTearContinue;
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
          semanticLabel: l10n.practiceMissionCardSemantic(
            entry.title,
            statLeft,
            tearLabel,
          ),
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
  _currentStep(AppLocalizations l10n) {
    return switch (_step) {
      0 => (
        stepLabel: l10n.practiceStep1Label,
        question: l10n.practiceStep1Question,
        primaryLabel: l10n.practiceStep1Primary,
        onPrimary: () => _record('decision_selected', {'decision': 'recount'}),
        secondaryLabel: l10n.practiceStep1Secondary,
        onSecondary: () =>
            _record('decision_selected', {'decision': 'overwrite'}),
      ),
      1 => (
        stepLabel: l10n.practiceStep2Label,
        question: l10n.practiceStep2Question,
        primaryLabel: l10n.practiceStep2Primary,
        onPrimary: () => _record('records_preserved', const {}),
        secondaryLabel: l10n.practiceStep2Secondary,
        onSecondary: () => _record('record_discarded', const {}),
      ),
      _ => (
        stepLabel: l10n.practiceStep3Label,
        question: l10n.practiceStep3Question,
        primaryLabel: l10n.practiceStep3Primary,
        onPrimary: () => _record('exception_escalated', const {}),
        secondaryLabel: l10n.practiceStep3Secondary,
        onSecondary: () => _record('exception_ignored', const {}),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pack = ref.watch(activeSectorPackProvider);
    if (_saving) {
      return AppStateView(
        icon: Icons.calculate_outlined,
        title: l10n.practiceScoringTitle,
        message: l10n.practiceScoringMessage,
      );
    }
    if (_score != null) {
      return _buildResult(context, pack, _score!);
    }
    final step = _currentStep(l10n);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        112,
      ),
      children: [
        Text(
          l10n.practiceAssessmentHeadline,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(l10n.practiceScenarioLine),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          backgroundColor: AppColors.infoSoft,
          child: Text(l10n.practiceScoringDisclaimer),
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
      message: AppLocalizations.of(context).practiceTechnicalEventSnackbar,
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
        message: failure.localizedMessage(AppLocalizations.of(context)),
        tone: AppMessageTone.error,
      );
    } else {
      await ref
          .read(analyticsTrackerProvider)
          .track(AnalyticsEvent.simulationSubmitted(score.simulationVersion));
    }
  }

  Widget _buildResult(
    BuildContext context,
    SectorPack pack,
    SimulationScore score,
  ) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        112,
      ),
      children: [
        Text(
          l10n.practiceResultHeadline,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.md),
        _ResultCard(pack: pack, score: score, onClose: widget.onClose),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.practiceResultDisclaimer),
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
                AppLocalizations.of(context).practiceRecordFailureButton,
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
          // `container: true` gives this informational block its own
          // semantics boundary, scoped separately from the "Return to
          // practice" button below. Before this fix, neither this Column
          // nor anything else in the card declared a boundary at all, so
          // Flutter's default merge climbed all the way up through every
          // Text/Container here *and* the button's own InkWell into one
          // single node -- a real debugDumpSemanticsTree() dump confirmed
          // the merged label concatenated the score, explanation, all
          // three dimension rows, and the improvement note *before*
          // "Return to practice", the actionable button's own text landing
          // last inside an unlabelled wall of text instead of being its
          // own clean, independently reachable node (same trap class as
          // sector_credential_card.dart's pre-fix bug, just without an
          // author-supplied `semanticLabel` making it as obvious from
          // source).
          Semantics(
            container: true,
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
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
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
                    AppLocalizations.of(
                      context,
                    ).practiceNextImprovement(score.improvement),
                    style: SectorPackTypography.bodyRegular(
                      color: Colors.white.withValues(alpha: 0.86),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            // container: true here too -- without it, this button's own
            // actionable config (having no boundary of its own) became the
            // *owner* of the merge scope shared with the informational
            // Semantics above, and the informational block ended up
            // re-parented as this node's child instead of its plain
            // preceding sibling -- confirmed via a real
            // debugDumpSemanticsTree() dump: traversal order put "Return
            // to practice" *before* the score breakdown, backwards from
            // the visual top-to-bottom layout. Giving both pieces their
            // own explicit boundary makes them clean, independent
            // siblings in the correct order, matching how
            // certification_exam_result_screen.dart's `_ResultBanner` and
            // `AppButton('Back to Learn')` already sit as siblings with no
            // such inversion.
            container: true,
            button: true,
            child: SizedBox(
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
                      AppLocalizations.of(context).practiceReturnButton,
                      style: SectorPackTypography.bodySemiBold(
                        color: Colors.white,
                        fontSize: 13,
                      ),
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
    final l10n = AppLocalizations.of(context);
    final surface = Theme.of(context).colorScheme.surface;
    final correctOption = l10n.practiceDemoOptionCorrect;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        112,
      ),
      children: [
        Text(
          l10n.practiceDemoHeadline,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(l10n.practiceDemoScenarioLine),
        const SizedBox(height: AppSpacing.lg),
        for (final option in [
          l10n.practiceDemoOptionOverwrite,
          correctOption,
          l10n.practiceDemoOptionIgnore,
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
              final correct = selectedDecision == correctOption;
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
                      ? l10n.practiceDemoFeedbackCorrect
                      : l10n.practiceDemoFeedbackIncorrect,
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
        Text(l10n.practiceDemoFooterDisclaimer),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: l10n.practiceReturnButton,
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
    final l10n = AppLocalizations.of(context);
    final surface = Theme.of(context).colorScheme.surface;
    final divider = Theme.of(context).dividerColor;
    final ink = Theme.of(context).colorScheme.onSurface;
    final inkSoft = Theme.of(context).colorScheme.onSurfaceVariant;
    return Semantics(
      label: l10n.practiceOptionSemantic(
        label,
        selected ? l10n.practiceOptionSelected : l10n.practiceOptionNotSelected,
      ),
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
