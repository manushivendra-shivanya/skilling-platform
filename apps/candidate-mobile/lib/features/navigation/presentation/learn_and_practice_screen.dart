import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../certification_exam/presentation/certification_exam_controller.dart';
import '../../certification_exam/presentation/certification_exam_section.dart';
import '../../learning/presentation/learning_controller.dart';
import '../../learning/presentation/learning_screen.dart';
import '../../practice/presentation/practice_screen.dart';
import '../../sector_pack/application/active_sector_pack_provider.dart';
import '../../sector_pack/presentation/sector_pack_typography.dart';
import '../../sector_pack/presentation/sector_signal_dot.dart';
import '../../workplace_simulation/application/workplace_simulation_controller.dart';

/// Combines Lessons, Practise, and Certification into one destination with
/// an internal 3-way segmented switch. All three screens are embedded
/// unmodified -- this is purely a navigation-level merge.
///
/// Certification used to be a section scrolled-to at the bottom of
/// Lessons (`CertificationExamSection` rendered inside `LearningScreen`,
/// past every lesson unit and the whole clips section). It's now a third,
/// equal segment here instead -- see the "Certification as its own tab"
/// proposal in the published Shift Floor coverage mock.
///
/// Uses a custom segmented bar (not [TabBar]) paired with [IndexedStack]
/// rather than [TabBarView] -- [TabBarView] wraps a [PageView], which is
/// itself a [Scrollable], and that extra scrollable in the tree broke
/// every test that located "the" scrollable via
/// `find.byType(Scrollable).first`. [IndexedStack] adds no such ancestor
/// and keeps all three screens' state alive when switching, same as
/// before. The bar itself is a state readout, not just a label -- each
/// segment shows the real state of its screen (docs/26-sector-pack-
/// rollout.md's IA proposal), built from [activeSectorPackProvider] so it
/// stays sector-blind rather than hardcoding warehouse copy or colour.
class LearnAndPracticeScreen extends StatefulWidget {
  const LearnAndPracticeScreen({
    required this.onOpenWorkplaceSimulation,
    this.startOnPractice = false,
    super.key,
  });

  final void Function(String missionId) onOpenWorkplaceSimulation;

  /// True when arriving here from a workplace-simulation exit route, so the
  /// candidate lands back on Practise rather than Lessons (matches the exact
  /// tab they left, same as when Practise was its own bottom-nav tab).
  final bool startOnPractice;

  @override
  State<LearnAndPracticeScreen> createState() => _LearnAndPracticeScreenState();
}

class _LearnAndPracticeScreenState extends State<LearnAndPracticeScreen> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.startOnPractice ? 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: _SectorSegmentedTabBar(
            selectedIndex: _selectedIndex,
            onSelected: (index) => setState(() => _selectedIndex = index),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _selectedIndex,
            children: [
              LearningScreen(
                onOpenSimulation: widget.onOpenWorkplaceSimulation,
              ),
              PracticeScreen(
                onOpenWorkplaceSimulation: widget.onOpenWorkplaceSimulation,
              ),
              const SingleChildScrollView(child: CertificationExamSection()),
            ],
          ),
        ),
      ],
    );
  }
}

class _SegmentData {
  const _SegmentData({
    required this.label,
    required this.stateText,
    required this.signalState,
  });

  final String label;
  final String stateText;

  /// Null while the underlying data hasn't resolved yet -- rendered as a
  /// dim, colourless placeholder rather than guessing a colour.
  final SectorSignalState? signalState;
}

class _SectorSegmentedTabBar extends ConsumerWidget {
  const _SectorSegmentedTabBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final pack = ref.watch(activeSectorPackProvider);
    final segments = [
      _lessonsSegment(ref, l10n),
      _practiseSegment(ref, l10n),
      _certificationSegment(ref, l10n),
    ];
    // Fixed chrome, not derived from pack.primaryAccent -- see
    // AppColors.navy's doc comment for why (a real bug caught on-device:
    // darkening warehouse's orange accent produced brown, which read as an
    // error state next to the light screens below it).
    const base = AppColors.navy;

    return Semantics(
      // Mirrors the bottom nav's own `role: tabBar` / `role: tab` shape
      // (see main_navigation_shell.dart's NavigationBar, which gets this
      // for free from Material) -- this is a hand-rolled segmented control
      // standing in for a real TabBar (see this class's doc comment for
      // why), so it has to declare the same roles itself.
      container: true,
      role: SemanticsRole.tabBar,
      child: Container(
        color: base,
        child: Row(
          children: [
            for (final (index, segment) in segments.indexed)
              Expanded(
                child: Semantics(
                  // Before this fix, this segment had no Semantics node of
                  // its own at all -- Flutter's default merge behaviour
                  // still made it reachable and tappable (a real
                  // debugDumpSemanticsTree() dump confirmed
                  // `actions: focus, tap`), but the tab's *selected* state
                  // was never announced: no `isSelected` flag, ever, on any
                  // segment, even the active one. A screen-reader user had
                  // no way to tell which of Lessons/Practise/Certification
                  // they were currently on. `container: true` +
                  // `excludeSemantics: true` replaces the auto-merged raw
                  // text (index digit, label, state readout) with one
                  // deliberate label, and `onTap` is repeated explicitly on
                  // this node -- excludeSemantics wrapping the InkWell
                  // itself would otherwise drop its own tap action, the
                  // same fix already shipped on practice_screen.dart's
                  // `_DemoOptionCard` and certification_exam_screen.dart's
                  // `_ExamOptionCard`.
                  label: l10n.learnTabSemanticLabel(
                    segment.label,
                    segment.stateText,
                    index + 1,
                    segments.length,
                  ),
                  button: true,
                  selected: index == selectedIndex,
                  role: SemanticsRole.tab,
                  container: true,
                  excludeSemantics: true,
                  onTap: () => onSelected(index),
                  child: InkWell(
                    onTap: () => onSelected(index),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
                      decoration: BoxDecoration(
                        border: Border(
                          right: index == segments.length - 1
                              ? BorderSide.none
                              : BorderSide(
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                          bottom: BorderSide(
                            width: 3,
                            color: index == selectedIndex
                                ? pack.signalPalette.active
                                : Colors.transparent,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            (index + 1).toString().padLeft(2, '0'),
                            style: SectorPackTypography.monoLabel(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 9.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            segment.label,
                            style: SectorPackTypography.displayLabel(
                              color: Colors.white.withValues(
                                alpha: index == selectedIndex ? 1 : 0.55,
                              ),
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (segment.signalState != null) ...[
                                SectorSignalDot(
                                  pack: pack,
                                  state: segment.signalState!,
                                  size: 6,
                                ),
                                const SizedBox(width: 5),
                              ],
                              Flexible(
                                child: Text(
                                  segment.stateText,
                                  overflow: TextOverflow.ellipsis,
                                  style: SectorPackTypography.monoLabel(
                                    color: index == selectedIndex
                                        ? pack.signalPalette.active
                                        : Colors.white.withValues(alpha: 0.5),
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  _SegmentData _lessonsSegment(WidgetRef ref, AppLocalizations l10n) {
    final state = ref.watch(learningControllerProvider);
    final learning = state.valueOrNull;
    if (state.hasError) {
      return _SegmentData(
        label: l10n.learnTabLessons,
        stateText: l10n.learnStateUnavailable,
        signalState: SectorSignalState.locked,
      );
    }
    if (learning == null) {
      return _SegmentData(
        label: l10n.learnTabLessons,
        stateText: l10n.learnStateLoading,
        signalState: null,
      );
    }
    final total = learning.units.length;
    final completed = learning.completedIds.length;
    final signalState = total == 0 || completed == 0
        ? SectorSignalState.locked
        : completed == total
        ? SectorSignalState.cleared
        : SectorSignalState.active;
    return _SegmentData(
      label: l10n.learnTabLessons,
      stateText: total == 0
          ? l10n.learningEmptyTitle
          : l10n.learnLessonsClearedCount(completed, total),
      signalState: signalState,
    );
  }

  _SegmentData _practiseSegment(WidgetRef ref, AppLocalizations l10n) {
    const missionIds = [
      WorkplaceSimulationController.missionId,
      WorkplaceSimulationController.putAwayMissionId,
      WorkplaceSimulationController.processingMissionId,
      WorkplaceSimulationController.dispatchMissionId,
    ];
    var ready = 0;
    var errored = 0;
    for (final id in missionIds) {
      final state = ref.watch(workplaceSimulationControllerProvider(id));
      if (state.hasValue) {
        ready += 1;
      } else if (state.hasError) {
        errored += 1;
      }
    }
    if (ready == missionIds.length) {
      return _SegmentData(
        label: l10n.learnTabPractise,
        stateText: l10n.learnPractiseMissionsReady(ready),
        signalState: SectorSignalState.cleared,
      );
    }
    if (ready > 0) {
      return _SegmentData(
        label: l10n.learnTabPractise,
        stateText: l10n.learnPractiseSomeReady(ready, missionIds.length),
        signalState: SectorSignalState.active,
      );
    }
    if (errored == missionIds.length) {
      return _SegmentData(
        label: l10n.learnTabPractise,
        stateText: l10n.learnStateUnavailable,
        signalState: SectorSignalState.locked,
      );
    }
    return _SegmentData(
      label: l10n.learnTabPractise,
      stateText: l10n.learnStateLoading,
      signalState: null,
    );
  }

  _SegmentData _certificationSegment(WidgetRef ref, AppLocalizations l10n) {
    final learningState = ref.watch(learningControllerProvider);
    final examState = ref.watch(certificationExamControllerProvider);
    if (learningState.hasError || examState.hasError) {
      return _SegmentData(
        label: l10n.learnTabCertification,
        stateText: l10n.learnStateUnavailable,
        signalState: SectorSignalState.locked,
      );
    }
    final learning = learningState.valueOrNull;
    final exam = examState.valueOrNull;
    if (learning == null || exam == null) {
      return _SegmentData(
        label: l10n.learnTabCertification,
        stateText: l10n.learnStateLoading,
        signalState: null,
      );
    }
    if (!isCertificationEligible(learning)) {
      return _SegmentData(
        label: l10n.learnTabCertification,
        stateText: l10n.learnCertLocked,
        signalState: SectorSignalState.locked,
      );
    }
    if (exam.lastAttempt == null) {
      return _SegmentData(
        label: l10n.learnTabCertification,
        stateText: l10n.learnCertEligible,
        signalState: SectorSignalState.cleared,
      );
    }
    if (exam.lastAttemptPassed) {
      return _SegmentData(
        label: l10n.learnTabCertification,
        stateText: l10n.learnCertPassed,
        signalState: SectorSignalState.cleared,
      );
    }
    return _SegmentData(
      label: l10n.learnTabCertification,
      stateText: l10n.learnCertRetryAvailable,
      signalState: SectorSignalState.active,
    );
  }
}
