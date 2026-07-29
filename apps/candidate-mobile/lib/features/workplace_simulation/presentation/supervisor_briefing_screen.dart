import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/app_state_view.dart';
import '../application/workplace_simulation_controller.dart';
import '../application/workplace_simulation_state.dart';
import '../domain/simulation_enums.dart';
import 'widgets/simulation_section_card.dart';

class SupervisorBriefingScreen extends ConsumerStatefulWidget {
  const SupervisorBriefingScreen({
    required this.missionId,
    required this.onBackToEntry,
    required this.onOpenWorkplace,
    super.key,
  });

  final String missionId;
  final VoidCallback onBackToEntry;
  final VoidCallback onOpenWorkplace;

  @override
  ConsumerState<SupervisorBriefingScreen> createState() =>
      _SupervisorBriefingScreenState();
}

class _SupervisorBriefingScreenState
    extends ConsumerState<SupervisorBriefingScreen> {
  bool _starting = false;
  bool _openedTracked = false;

  @override
  Widget build(BuildContext context) {
    final simulation = ref.watch(
      workplaceSimulationControllerProvider(widget.missionId),
    );
    return PopScope(
      canPop: !_starting,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_starting) widget.onBackToEntry();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back to simulation entry',
            onPressed: _starting ? null : widget.onBackToEntry,
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('Shift Briefing'),
        ),
        body: SafeArea(
          child: simulation.when(
            loading: _BriefingLoading.new,
            error: (error, stackTrace) => _BriefingRuntimeError(
              onRetry: () => ref.invalidate(
                workplaceSimulationControllerProvider(widget.missionId),
              ),
              onReturn: widget.onBackToEntry,
            ),
            data: (value) => _buildReady(value),
          ),
        ),
      ),
    );
  }

  Widget _buildReady(WorkplaceSimulationState value) {
    final attempt = value.attempt;
    if (attempt == null) {
      return AppErrorState(
        title: 'This mission briefing is unavailable.',
        message:
            'The mission content is incomplete and the shift cannot start.',
        actionLabel: 'Return to Simulations',
        onAction: widget.onBackToEntry,
      );
    }
    if (value.scenario == null) {
      return _BriefingRuntimeError(
        onRetry: () => ref.invalidate(
          workplaceSimulationControllerProvider(widget.missionId),
        ),
        onReturn: widget.onBackToEntry,
      );
    }
    if (attempt.state != MissionState.briefing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onOpenWorkplace();
      });
      return const Center(child: CircularProgressIndicator());
    }
    if (!_openedTracked) {
      _openedTracked = true;
      unawaited(
        ref
            .read(
              workplaceSimulationControllerProvider(widget.missionId).notifier,
            )
            .recordBriefingOpened(),
      );
    }
    return _BriefingContent(
      value: value,
      acknowledged: attempt.briefingAcknowledged,
      starting: _starting,
      onAcknowledgementChanged: _setAcknowledgement,
      onBeginShift: _beginShift,
      onMissionDetails: () => _showMissionDetails(value),
    );
  }

  Future<void> _setAcknowledgement(bool value) async {
    if (_starting) return;
    final failure = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .setBriefingAcknowledged(value);
    if (!mounted || failure == null) return;
    showAppSnackBar(
      context: context,
      message: failure.message,
      tone: AppMessageTone.error,
    );
  }

  Future<void> _beginShift() async {
    if (_starting) return;
    setState(() => _starting = true);
    final result = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .beginShift();
    if (!mounted) return;
    if (result != BeginShiftResult.success) {
      setState(() => _starting = false);
      showAppSnackBar(
        context: context,
        message: _beginShiftMessage(result),
        tone: AppMessageTone.error,
      );
      return;
    }
    if (mounted) widget.onOpenWorkplace();
  }

  Future<void> _showMissionDetails(WorkplaceSimulationState value) async {
    await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordMissionDetailsOpened(screenId: 'supervisor-briefing');
    if (!mounted) return;
    await showAppBottomSheet<void>(
      context: context,
      title: 'Mission Details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${value.mission.title}\n'
            '${value.mission.difficulty.name} • '
            '${value.mission.estimatedDurationMinutes} minutes',
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Pass requirements',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text('• Score ${value.mission.scoringRule.minimumScore}% or higher'),
          const Text('• Complete mandatory tasks'),
          const Text('• Avoid critical errors'),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Assessment areas',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final category in value.mission.scoringRule.categories)
            Text('• ${category.id.split('-').map(_titleCase).join(' ')}'),
          const SizedBox(height: AppSpacing.lg),
          const AppBottomSheetCloseButton(),
        ],
      ),
    );
  }

  String _beginShiftMessage(BeginShiftResult result) => switch (result) {
    BeginShiftResult.acknowledgementRequired =>
      'Confirm that you understand the assignment and workplace rules.',
    BeginShiftResult.alreadyStarting => 'Your shift is already starting.',
    BeginShiftResult.alreadyStarted => 'This shift has already started.',
    BeginShiftResult.invalidState =>
      'This attempt is not ready to start a shift.',
    BeginShiftResult.contentInvalid =>
      'The mission briefing is unavailable or invalid.',
    BeginShiftResult.scenarioUnavailable =>
      'The shift scenario could not be prepared.',
    BeginShiftResult.persistenceFailure =>
      'The shift could not be saved. No timed work was started.',
    BeginShiftResult.success => '',
  };
}

class _BriefingLoading extends StatelessWidget {
  const _BriefingLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Semantics(
          liveRegion: true,
          label: 'Preparing your shift',
          child: Text('Preparing your shift...'),
        ),
        const SizedBox(height: AppSpacing.md),
        const AppSkeletonCard(),
        const SizedBox(height: AppSpacing.md),
        const AppSkeletonCard(),
        const SizedBox(height: AppSpacing.md),
        const AppSkeletonCard(),
        const SizedBox(height: AppSpacing.lg),
        const CheckboxListTile(
          value: false,
          onChanged: null,
          title: Text('I understand the assignment and workplace rules.'),
        ),
        const AppButton(label: 'Begin Shift', onPressed: null),
      ],
    );
  }
}

class _BriefingRuntimeError extends StatelessWidget {
  const _BriefingRuntimeError({required this.onRetry, required this.onReturn});

  final VoidCallback onRetry;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: AppErrorState(
            title: 'Your shift could not be prepared.',
            message: 'No timed work has started. Retry preparation safely.',
            actionLabel: 'Retry Preparation',
            onAction: onRetry,
          ),
        ),
        AppButton(
          label: 'Return to Simulations',
          variant: AppButtonVariant.text,
          onPressed: onReturn,
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

class _BriefingContent extends StatelessWidget {
  const _BriefingContent({
    required this.value,
    required this.acknowledged,
    required this.starting,
    required this.onAcknowledgementChanged,
    required this.onBeginShift,
    required this.onMissionDetails,
  });

  final WorkplaceSimulationState value;
  final bool acknowledged;
  final bool starting;
  final ValueChanged<bool> onAcknowledgementChanged;
  final VoidCallback onBeginShift;
  final VoidCallback onMissionDetails;

  @override
  Widget build(BuildContext context) {
    final briefing = value.mission.briefing;
    final department = value.workplace.departments.firstWhere(
      (item) => item.id == value.mission.departmentId,
    );
    return SimulationScreenReveal(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            children: [
              SimulationSectionCard(
                title: briefing.supervisorTitle,
                icon: Icons.supervisor_account_outlined,
                child: Text('${department.name}\n${value.workplace.name}'),
              ),
              const SizedBox(height: AppSpacing.md),
              SimulationSectionCard(
                title: 'Incoming Shipment',
                icon: Icons.local_shipping_outlined,
                child: _BriefingFacts(
                  values: {
                    'Supplier': briefing.supplier,
                    'Purchase order': briefing.purchaseOrderNumber,
                    'Delivery reference': briefing.deliveryReference,
                    'Delivery type': briefing.deliveryType,
                    'Department': department.name,
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SimulationSectionCard(
                title: 'Supervisor Message',
                icon: Icons.campaign_outlined,
                backgroundColor: AppColors.brandSoft,
                child: Semantics(
                  container: true,
                  label: 'Supervisor message. ${briefing.message}',
                  child: ExcludeSemantics(child: Text(briefing.message)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SimulationSectionCard(
                title: 'Your Responsibilities',
                icon: Icons.assignment_turned_in_outlined,
                child: _IconList(
                  values: briefing.responsibilities,
                  icon: Icons.circle_outlined,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SimulationSectionCard(
                title: 'Important Workplace Rules',
                icon: Icons.policy_outlined,
                backgroundColor: AppColors.warningSoft,
                child: _IconList(
                  values: briefing.workplaceRules,
                  icon: Icons.priority_high,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              CheckboxListTile(
                key: const ValueKey('briefing-acknowledgement'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: acknowledged,
                onChanged: starting
                    ? null
                    : (value) => onAcknowledgementChanged(value ?? false),
                title: const Text(
                  'I understand the assignment and workplace rules.',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Begin Shift',
                semanticLabel: acknowledged
                    ? 'Begin Shift button. Starts timed warehouse work.'
                    : 'Begin Shift button, disabled. Confirm that you understand the assignment and workplace rules to continue.',
                isLoading: starting,
                onPressed: acknowledged && !starting ? onBeginShift : null,
              ),
              AppButton(
                label: 'Mission Details',
                variant: AppButtonVariant.text,
                onPressed: starting ? null : onMissionDetails,
              ),
              if (starting)
                Semantics(
                  liveRegion: true,
                  child: Center(child: Text('Shift Starting...')),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BriefingFacts extends StatelessWidget {
  const _BriefingFacts({required this.values});

  final Map<String, String> values;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final entry in values.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 138, child: Text(entry.key)),
                Expanded(
                  child: Text(
                    entry.value,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _IconList extends StatelessWidget {
  const _IconList({required this.values, required this.icon});

  final List<String> values;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final value in values)
          ListTile(
            minTileHeight: 48,
            contentPadding: EdgeInsets.zero,
            leading: Icon(icon, size: 20),
            title: Text(value),
          ),
      ],
    );
  }
}

String _titleCase(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
