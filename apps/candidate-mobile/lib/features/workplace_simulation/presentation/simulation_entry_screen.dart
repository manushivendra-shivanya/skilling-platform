import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/app_state_view.dart';
import '../application/workplace_simulation_controller.dart';
import '../application/workplace_simulation_state.dart';
import '../domain/simulation_content.dart';
import '../domain/simulation_enums.dart';
import 'widgets/simulation_section_card.dart';

class SimulationEntryScreen extends ConsumerStatefulWidget {
  const SimulationEntryScreen({
    required this.onOpenBriefing,
    required this.onContinueWorkplace,
    required this.onExit,
    super.key,
  });

  final VoidCallback onOpenBriefing;
  final VoidCallback onContinueWorkplace;
  final VoidCallback onExit;

  @override
  ConsumerState<SimulationEntryScreen> createState() =>
      _SimulationEntryScreenState();
}

class _SimulationEntryScreenState extends ConsumerState<SimulationEntryScreen> {
  bool _isStarting = false;
  bool _entryTracked = false;

  @override
  Widget build(BuildContext context) {
    final simulation = ref.watch(workplaceSimulationControllerProvider);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_confirmExit());
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Workplace Management Simulation')),
        body: SafeArea(
          child: simulation.when(
            loading: _EntryLoading.new,
            error: (error, stackTrace) => _EntryError(
              onRetry: () =>
                  ref.invalidate(workplaceSimulationControllerProvider),
              onBack: widget.onExit,
            ),
            data: (value) {
              if (!_entryTracked && value.attempt != null) {
                _entryTracked = true;
                unawaited(
                  ref
                      .read(workplaceSimulationControllerProvider.notifier)
                      .recordSimulationEntryOpened(),
                );
              }
              if (value.pack.status != 'published') {
                return AppEmptyState(
                  title: 'No workplace simulations are currently available.',
                  message: 'Return to Practice and try again later.',
                  actionLabel: 'Back to Practice',
                  onAction: widget.onExit,
                );
              }
              return _EntryContent(
                value: value,
                progress: ref
                    .read(workplaceSimulationControllerProvider.notifier)
                    .progress,
                isStarting: _isStarting,
                onPrimaryAction: () => _handlePrimaryAction(value),
                onMissionDetails: () => _showMissionDetails(value),
                onExit: _confirmExit,
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _handlePrimaryAction(WorkplaceSimulationState value) async {
    if (_isStarting) return;
    setState(() => _isStarting = true);
    final controller = ref.read(workplaceSimulationControllerProvider.notifier);
    final attempt = value.attempt;
    final AppFailure? failure;
    if (attempt == null) {
      failure = await controller.startMission();
    } else if (attempt.state == MissionState.completed ||
        attempt.state == MissionState.failed) {
      failure = await controller.retry();
    } else {
      failure = await controller.continueMission();
    }
    if (!mounted) return;
    setState(() => _isStarting = false);
    if (failure != null) {
      showAppSnackBar(
        context: context,
        message: failure.message,
        tone: AppMessageTone.error,
      );
      return;
    }
    final updated = ref
        .read(workplaceSimulationControllerProvider)
        .requireValue;
    final state = updated.attempt?.state;
    if (state == MissionState.briefing) {
      widget.onOpenBriefing();
    } else {
      widget.onContinueWorkplace();
    }
  }

  Future<void> _showMissionDetails(WorkplaceSimulationState value) async {
    final attempt = value.attempt;
    if (attempt != null) {
      await ref
          .read(workplaceSimulationControllerProvider.notifier)
          .recordMissionDetailsOpened(screenId: 'simulation-entry');
    }
    if (!mounted) return;
    await showAppBottomSheet<void>(
      context: context,
      title: value.mission.title,
      child: _MissionDetails(mission: value.mission),
    );
  }

  Future<void> _confirmExit() async {
    final attempt = ref
        .read(workplaceSimulationControllerProvider)
        .valueOrNull
        ?.attempt;
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: "Exit today's shift?",
      message: attempt == null
          ? 'You can return to this simulation from Practice.'
          : 'Your current progress will be saved securely on this device.',
      confirmLabel: 'Yes, exit',
      cancelLabel: 'No',
    );
    if (confirmed && mounted) widget.onExit();
  }
}

class _EntryLoading extends StatelessWidget {
  const _EntryLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Semantics(
          liveRegion: true,
          label: 'Loading workplace simulation.',
          child: Text('Loading workplace simulation...'),
        ),
        const SizedBox(height: AppSpacing.md),
        const AppSkeletonCard(),
        const SizedBox(height: AppSpacing.md),
        const AppSkeletonCard(),
        const SizedBox(height: AppSpacing.md),
        const AppSkeletonCard(),
        const SizedBox(height: AppSpacing.lg),
        const AppButton(label: 'Start Shift', onPressed: null),
      ],
    );
  }
}

class _EntryError extends StatelessWidget {
  const _EntryError({required this.onRetry, required this.onBack});

  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: AppErrorState(
            title: 'The workplace simulation could not be loaded.',
            message: 'Your saved attempt was not changed.',
            actionLabel: 'Retry',
            onAction: onRetry,
          ),
        ),
        AppButton(
          label: 'Back to Practice',
          variant: AppButtonVariant.text,
          onPressed: onBack,
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

class _EntryContent extends StatelessWidget {
  const _EntryContent({
    required this.value,
    required this.progress,
    required this.isStarting,
    required this.onPrimaryAction,
    required this.onMissionDetails,
    required this.onExit,
  });

  final WorkplaceSimulationState value;
  final double progress;
  final bool isStarting;
  final VoidCallback onPrimaryAction;
  final VoidCallback onMissionDetails;
  final Future<void> Function() onExit;

  @override
  Widget build(BuildContext context) {
    final mission = value.mission;
    final department = value.workplace.departments.firstWhere(
      (item) => item.id == mission.departmentId,
    );
    final attempt = value.attempt;
    return SimulationScreenReveal(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            children: [
              Text(
                value.workplace.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text('${value.pack.title} • ${mission.briefing.shiftName}'),
              const SizedBox(height: AppSpacing.md),
              const _OfflineNotice(),
              const SizedBox(height: AppSpacing.md),
              SimulationSectionCard(
                title: 'Your role',
                icon: Icons.badge_outlined,
                child: _KeyValueList(
                  values: {
                    'Role': mission.role.title,
                    'Department': department.name,
                    'Level': _titleCase(mission.role.level),
                    'Reporting to': mission.briefing.supervisorTitle,
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SimulationSectionCard(
                title: "Today's shift",
                icon: Icons.assignment_outlined,
                backgroundColor: AppColors.brandSoft,
                child: _KeyValueList(
                  values: {
                    'Mission': mission.title,
                    'Difficulty': _titleCase(mission.difficulty.name),
                    'Estimated duration':
                        '${mission.estimatedDurationMinutes} minutes',
                    'Mission version': mission.version,
                    'Status': _statusLabel(attempt?.state),
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SimulationSectionCard(
                title: 'Progress',
                icon: Icons.trending_up_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${(progress * 100).round()}% • '
                      '${_stageLabel(value)} • ${_statusLabel(attempt?.state)}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SimulationSectionCard(
                title: 'Mission objectives',
                icon: Icons.checklist_outlined,
                child: Column(
                  children: [
                    for (final objective in mission.objectives.take(5))
                      ListTile(
                        minTileHeight: 48,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.circle_outlined, size: 20),
                        title: Text(objective),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: _primaryLabel(attempt?.state),
                semanticLabel:
                    '${_primaryLabel(attempt?.state)} button. Begins or resumes today’s warehouse receiving simulation.',
                isLoading: isStarting,
                onPressed: isStarting ? null : onPrimaryAction,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Mission Details',
                variant: AppButtonVariant.text,
                onPressed: isStarting ? null : onMissionDetails,
              ),
              AppButton(
                label: 'Exit Simulation',
                variant: AppButtonVariant.text,
                onPressed: isStarting ? null : () => unawaited(onExit()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _stageLabel(WorkplaceSimulationState value) {
    final stageId = value.attempt?.currentStageId;
    if (stageId == null) return 'Not Started';
    return value.mission.stages
        .firstWhere((stage) => stage.id == stageId)
        .title;
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: AppColors.infoSoft,
      child: const Row(
        children: [
          Icon(Icons.offline_bolt_outlined),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Available offline. Progress is encrypted and saved on this device.',
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyValueList extends StatelessWidget {
  const _KeyValueList({required this.values});

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
                SizedBox(
                  width: 132,
                  child: Text(
                    entry.key,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
                  ),
                ),
                Expanded(child: Text(entry.value)),
              ],
            ),
          ),
      ],
    );
  }
}

class _MissionDetails extends StatelessWidget {
  const _MissionDetails({required this.mission});

  final MissionDefinition mission;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_titleCase(mission.difficulty.name)} • '
          '${mission.estimatedDurationMinutes} minutes • '
          'Version ${mission.version}',
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Pass requirements',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text('• Score ${mission.scoringRule.minimumScore}% or higher'),
        const Text('• Complete mandatory tasks'),
        const Text('• Avoid critical errors'),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Assessment areas',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final category in mission.scoringRule.categories)
          Text('• ${_categoryLabel(category.id)}'),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'Critical safety or compliance errors may prevent completion even when the numeric score is high.',
        ),
        const SizedBox(height: AppSpacing.lg),
        const AppBottomSheetCloseButton(),
      ],
    );
  }
}

String _titleCase(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

String _categoryLabel(String value) =>
    value.split('-').map(_titleCase).join(' ');

String _statusLabel(MissionState? state) => switch (state) {
  null || MissionState.notStarted => 'Not Started',
  MissionState.briefing ||
  MissionState.inProgress ||
  MissionState.submitted ||
  MissionState.evaluated => 'In Progress',
  MissionState.paused => 'Paused',
  MissionState.completed => 'Completed',
  MissionState.failed => 'Retry Available',
};

String _primaryLabel(MissionState? state) => switch (state) {
  null || MissionState.notStarted => 'Start Shift',
  MissionState.completed || MissionState.failed => 'Retry Mission',
  _ => 'Continue Shift',
};
