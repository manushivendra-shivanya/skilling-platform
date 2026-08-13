import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_loading_progress.dart';
import '../../../../core/widgets/app_state_view.dart';
import '../../../../core/widgets/app_sticky_footer.dart';
import '../../application/workplace_interaction_contracts.dart';
import '../../application/workplace_simulation_controller.dart';
import '../../application/workplace_simulation_state.dart';
import '../../domain/simulation_enums.dart';

/// Shared scaffold for a workplace-simulation station screen.
///
/// Every station screen (Receiving Dock, Packing Station, Quality Check,
/// Quarantine Zone, and ~18 others) used to hand-roll a near-identical
/// ~15-line shell: an [AppBar] whose back button records an exit audit
/// event before calling `onBack`, a four-branch
/// `simulation.when(loading/error/data)` ladder that also checks the
/// station's lock status and the generated scenario, a one-time `_tracked`
/// flag guarding a "screen opened" audit event, and a
/// `SingleChildScrollView` + `Center` + `ConstrainedBox(maxWidth: 920)`
/// content shell. [StationScaffold] owns all of that so each screen keeps
/// only its own training content and handlers.
///
/// It also fixes the underlying design-audit complaint that motivated this
/// extraction: a station's one primary action used to just be the last
/// item in a long scrolling [Column]. Supply [footerBuilder] to pin that
/// action in a real sticky footer (via [AppStickyFooter]) instead. Return
/// `null` from [footerBuilder] for a build where nothing should currently
/// be pinned (e.g. a station between phases) -- the content then fills the
/// full body with no footer reserved.
class StationScaffold extends ConsumerStatefulWidget {
  const StationScaffold({
    required this.missionId,
    required this.workstationId,
    required this.title,
    required this.openedEvent,
    required this.exitedEvent,
    required this.onBack,
    required this.contentBuilder,
    this.footerBuilder,
    this.saving = false,
    super.key,
  });

  final String missionId;

  /// Matches `Workstation.id` / `WorkplaceOverviewViewModel`'s
  /// `workstationId`, and is reused as the audit `screenId` -- exactly how
  /// every retrofitted screen already used its station id for both.
  final String workstationId;

  /// Shown as the [AppBar] title and reused to phrase the locked /
  /// unavailable error states ("$title is locked", "$title unavailable").
  final String title;

  final AttemptAuditEventType openedEvent;
  final AttemptAuditEventType exitedEvent;

  final VoidCallback onBack;

  final Widget Function(BuildContext context, WorkplaceSimulationState value)
  contentBuilder;

  /// Builds the sticky footer for the current [WorkplaceSimulationState].
  /// Return `null` to render no footer for this build -- lets a station
  /// with several phases (e.g. Quarantine Zone) show a different primary
  /// action per phase, or none at all between them.
  final Widget? Function(BuildContext context, WorkplaceSimulationState value)?
  footerBuilder;

  /// True while the caller has an in-flight save/submit. Disables the back
  /// button so a candidate can't exit mid-write -- every screen previously
  /// guarded its own back button with `_saving ? null : _exit`.
  final bool saving;

  @override
  ConsumerState<StationScaffold> createState() => _StationScaffoldState();
}

class _StationScaffoldState extends ConsumerState<StationScaffold> {
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
          onPressed: widget.saving ? null : _exit,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(widget.title),
      ),
      body: SafeArea(
        child: simulation.when(
          loading: () => const Center(
            child: AppLoadingProgressBar(label: 'Loading your progress…'),
          ),
          error: (_, _) => AppErrorState(
            title: '${widget.title} unavailable',
            message: 'Your saved progress is safe. Retry loading the station.',
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(
              workplaceSimulationControllerProvider(widget.missionId),
            ),
          ),
          data: _buildData,
        ),
      ),
    );
  }

  Widget _buildData(WorkplaceSimulationState value) {
    final controller = ref.read(
      workplaceSimulationControllerProvider(widget.missionId).notifier,
    );
    final station = controller.workplaceOverview.workstations.firstWhere(
      (item) => item.workstationId == widget.workstationId,
    );
    if (value.mission.id != widget.missionId ||
        station.status == WorkstationStatus.locked) {
      return AppErrorState(
        title: '${widget.title} is locked',
        message: station.supportingText,
        actionLabel: 'Back to Workplace',
        onAction: widget.onBack,
      );
    }
    final scenario = value.scenario;
    if (scenario == null) {
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
          widget.openedEvent,
          screenId: widget.workstationId,
        ),
      );
    }
    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Builder(
            builder: (context) => widget.contentBuilder(context, value),
          ),
        ),
      ),
    );
    final footerBuilder = widget.footerBuilder;
    if (footerBuilder == null) return content;
    return Column(
      children: [
        Expanded(child: content),
        _StickyFooterIfPresent(builder: footerBuilder, value: value),
      ],
    );
  }

  Future<void> _exit() async {
    await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordWorkplaceEvent(
          widget.exitedEvent,
          screenId: widget.workstationId,
        );
    if (mounted) widget.onBack();
  }
}

/// Renders [AppStickyFooter] only when `builder` returns a non-null widget
/// for the current [value] -- otherwise renders nothing, so a station
/// between phases (nothing to pin yet) doesn't reserve empty footer chrome.
class _StickyFooterIfPresent extends StatelessWidget {
  const _StickyFooterIfPresent({required this.builder, required this.value});

  final Widget? Function(BuildContext context, WorkplaceSimulationState value)
  builder;
  final WorkplaceSimulationState value;

  @override
  Widget build(BuildContext context) {
    final footer = builder(context, value);
    if (footer == null) return const SizedBox.shrink();
    return AppStickyFooter(child: footer);
  }
}
