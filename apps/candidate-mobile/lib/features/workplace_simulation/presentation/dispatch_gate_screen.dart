import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_loading_progress.dart';
import '../../../core/widgets/app_state_view.dart';
import '../application/workplace_interaction_contracts.dart';
import '../application/workplace_simulation_controller.dart';
import '../domain/simulation_enums.dart';

const _decisionOptions = [
  ('dispatch_complete', 'Dispatch complete'),
  ('hold_for_review', 'Hold for review'),
  ('escalate_to_supervisor', 'Escalate to supervisor'),
];

/// Final stage of the Dispatch mission: gate scan, exception handling,
/// route settlement report, decision, and supervisor notification.
class DispatchGateScreen extends ConsumerStatefulWidget {
  const DispatchGateScreen({
    required this.missionId,
    required this.onBack,
    required this.onMissionComplete,
    super.key,
  });

  final String missionId;
  final VoidCallback onBack;
  final VoidCallback onMissionComplete;

  @override
  ConsumerState<DispatchGateScreen> createState() => _DispatchGateScreenState();
}

class _DispatchGateScreenState extends ConsumerState<DispatchGateScreen> {
  static const _stageId = 'gate-and-exceptions';
  static const _gateScanTaskId = 'final-gate-scan';
  static const _exceptionsTaskId = 'handle-dispatch-exceptions';
  static const _reportTaskId = 'complete-dispatch-report';
  static const _decisionTaskId = 'make-dispatch-decision';
  static const _notifyTaskId = 'notify-supervisor';

  String? _savingTargetId;
  bool _tracked = false;
  bool _allCratesLoaded = false;
  bool _exceptionsRecorded = false;
  bool _mismatchResolved = false;

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
        title: const Text('Dispatch Gate'),
      ),
      body: SafeArea(
        child: simulation.when(
          loading: () => const Center(
            child: AppLoadingProgressBar(label: 'Loading your progress…'),
          ),
          error: (_, _) => AppErrorState(
            title: 'Dispatch Gate unavailable',
            message: 'Your saved progress is safe. Retry loading the shift.',
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
                .firstWhere((item) => item.workstationId == 'dispatch-gate');
            if (value.mission.id != widget.missionId ||
                station.status == WorkstationStatus.locked) {
              return AppErrorState(
                title: 'Dispatch Gate is locked',
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
                  screenId: 'dispatch-gate',
                ),
              );
            }
            bool attempted(String taskId) =>
                attempt.actions.any((action) => action.taskId == taskId);
            final gateScanned = attempted(_gateScanTaskId);
            final crates = value.mission
                .task(_exceptionsTaskId)
                .targetResourceIds
                .map(scenario.resource)
                .toList();
            final classified = {
              for (final action in attempt.actions)
                if (action.taskId == _exceptionsTaskId &&
                    action.targetId != null)
                  action.targetId,
            };
            final exceptionsDone = attempt.completedTaskIds.contains(
              _exceptionsTaskId,
            );
            final reportResource = scenario.resource('dispatch-report');
            final hasMismatch = reportResource.issues.any(
              (issue) => issue.issueType == 'route_close_exception',
            );
            final reportSubmitted = attempted(_reportTaskId);
            final decisionMade = attempted(_decisionTaskId);
            final supervisorNotified = attempted(_notifyTaskId);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan the manifest at the gate',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (!gateScanned)
                        AppButton(
                          label: 'Scan manifest',
                          expand: false,
                          isLoading: _savingTargetId == 'dispatch-manifest',
                          onPressed: _savingTargetId == null
                              ? _scanManifest
                              : null,
                        )
                      else
                        const Text('Manifest scanned.'),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Classify every crate exception',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (final crate in crates) ...[
                        AppCard(
                          semanticLabel: crate.title,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                crate.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text('${crate.content['routeId']}'),
                              if (crate.issues.isNotEmpty)
                                Text(
                                  'Flagged: '
                                  '${crate.issues.map((i) => i.issueType.replaceAll('_', ' ')).join(', ')}',
                                ),
                              const SizedBox(height: AppSpacing.xs),
                              if (classified.contains(crate.id))
                                const Text('Classified')
                              else if (gateScanned)
                                Row(
                                  children: [
                                    Expanded(
                                      child: AppButton(
                                        label: 'Accept',
                                        expand: false,
                                        variant: AppButtonVariant.secondary,
                                        isLoading: _savingTargetId == crate.id,
                                        onPressed: _savingTargetId == null
                                            ? () => _classifyCrate(
                                                crate.id,
                                                'accept',
                                              )
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: AppButton(
                                        label: 'Hold for verification',
                                        expand: false,
                                        isLoading: _savingTargetId == crate.id,
                                        onPressed: _savingTargetId == null
                                            ? () => _classifyCrate(
                                                crate.id,
                                                'hold_for_verification',
                                              )
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                      if (exceptionsDone) ...[
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          'Route settlement report',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _allCratesLoaded,
                                title: const Text('All crates loaded'),
                                onChanged: reportSubmitted
                                    ? null
                                    : (v) => setState(
                                        () => _allCratesLoaded = v ?? false,
                                      ),
                              ),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _exceptionsRecorded,
                                title: const Text('Exceptions recorded'),
                                onChanged: reportSubmitted
                                    ? null
                                    : (v) => setState(
                                        () => _exceptionsRecorded = v ?? false,
                                      ),
                              ),
                              if (hasMismatch)
                                CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  value: _mismatchResolved,
                                  title: const Text(
                                    'Cash/crate mismatch resolved',
                                  ),
                                  onChanged: reportSubmitted
                                      ? null
                                      : (v) => setState(
                                          () => _mismatchResolved = v ?? false,
                                        ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        if (!reportSubmitted)
                          AppButton(
                            label: 'Submit report',
                            expand: false,
                            isLoading: _savingTargetId == 'dispatch-report',
                            onPressed: _savingTargetId == null
                                ? _submitReport
                                : null,
                          )
                        else
                          const Text('Route settlement report submitted.'),
                      ],
                      if (reportSubmitted) ...[
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          'Dispatch decision',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        if (!decisionMade)
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              for (final option in _decisionOptions)
                                AppButton(
                                  label: option.$2,
                                  variant: AppButtonVariant.secondary,
                                  expand: false,
                                  isLoading:
                                      _savingTargetId == 'dispatch-report',
                                  onPressed: _savingTargetId == null
                                      ? () => _selectDecision(option.$1)
                                      : null,
                                ),
                            ],
                          )
                        else
                          const Text('Decision recorded.'),
                      ],
                      if (decisionMade) ...[
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          'Notify supervisor',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppButton(
                          label: supervisorNotified
                              ? 'Supervisor notified'
                              : 'Notify supervisor',
                          expand: false,
                          isLoading:
                              _savingTargetId == 'supervisor-notification',
                          onPressed: supervisorNotified
                              ? null
                              : (_savingTargetId == null
                                    ? _notifySupervisor
                                    : null),
                        ),
                      ],
                      if (supervisorNotified) ...[
                        const SizedBox(height: AppSpacing.xl),
                        AppButton(
                          label: 'Complete shift',
                          isLoading: _savingTargetId == 'complete-mission',
                          onPressed: _savingTargetId == null
                              ? _completeMission
                              : null,
                        ),
                      ],
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

  Future<void> _scanManifest() async {
    setState(() => _savingTargetId = 'dispatch-manifest');
    final failure = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordAction(
          stageId: _stageId,
          taskId: _gateScanTaskId,
          actionType: ActionType.scanBarcode,
          targetId: 'dispatch-manifest',
          payload: const {'gateScanStatus': 'matched'},
        );
    if (!mounted) return;
    setState(() => _savingTargetId = null);
    if (failure != null) {
      _showMessage('The manifest could not be scanned.');
    }
  }

  Future<void> _classifyCrate(String crateId, String disposition) async {
    setState(() => _savingTargetId = crateId);
    final failure = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordAction(
          stageId: _stageId,
          taskId: _exceptionsTaskId,
          actionType: ActionType.selectDisposition,
          targetId: crateId,
          payload: {
            'disposition': disposition,
            if (disposition != 'accept') 'reason': 'Crate exception flagged',
          },
        );
    if (!mounted) return;
    setState(() => _savingTargetId = null);
    if (failure != null) {
      _showMessage('The crate could not be classified.');
    }
  }

  Future<void> _submitReport() async {
    setState(() => _savingTargetId = 'dispatch-report');
    final failure = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordAction(
          stageId: _stageId,
          taskId: _reportTaskId,
          actionType: ActionType.completeForm,
          targetId: 'dispatch-report',
          payload: {
            'allCratesLoaded': _allCratesLoaded,
            'exceptionsRecorded': _exceptionsRecorded,
            'mismatchResolved': _mismatchResolved,
          },
        );
    if (!mounted) return;
    setState(() => _savingTargetId = null);
    if (failure != null) {
      _showMessage('The report could not be submitted.');
    }
  }

  Future<void> _selectDecision(String decision) async {
    setState(() => _savingTargetId = 'dispatch-report');
    final failure = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordAction(
          stageId: _stageId,
          taskId: _decisionTaskId,
          actionType: ActionType.makeDecision,
          targetId: 'dispatch-report',
          payload: {'decision': decision},
        );
    if (!mounted) return;
    setState(() => _savingTargetId = null);
    if (failure != null) {
      _showMessage('The decision could not be recorded.');
    }
  }

  Future<void> _notifySupervisor() async {
    setState(() => _savingTargetId = 'supervisor-notification');
    final failure = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordAction(
          stageId: _stageId,
          taskId: _notifyTaskId,
          actionType: ActionType.confirmAction,
          targetId: 'supervisor-notification',
          payload: const {
            'supervisorNotified': true,
            'exceptionsIncluded': true,
          },
        );
    if (!mounted) return;
    setState(() => _savingTargetId = null);
    if (failure != null) {
      _showMessage('The supervisor could not be notified.');
    }
  }

  Future<void> _completeMission() async {
    setState(() => _savingTargetId = 'complete-mission');
    final result = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .completeMission(screenId: 'dispatch-gate');
    if (!mounted) return;
    setState(() => _savingTargetId = null);
    if (result == CompleteMissionResult.success) {
      widget.onMissionComplete();
    } else {
      _showMessage('The shift could not be completed.');
    }
  }

  Future<void> _exit() async {
    await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordWorkplaceEvent(
          AttemptAuditEventType.workstationScreenExited,
          screenId: 'dispatch-gate',
        );
    if (mounted) widget.onBack();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
