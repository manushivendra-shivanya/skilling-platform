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
import '../domain/workplace_task_drafts.dart';

class QuarantineZoneScreen extends ConsumerStatefulWidget {
  const QuarantineZoneScreen({
    required this.missionId,
    required this.onBack,
    required this.onOpenReceivingOffice,
    super.key,
  });

  final String missionId;
  final VoidCallback onBack;
  final VoidCallback onOpenReceivingOffice;

  @override
  ConsumerState<QuarantineZoneScreen> createState() =>
      _QuarantineZoneScreenState();
}

class _QuarantineZoneScreenState extends ConsumerState<QuarantineZoneScreen> {
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
        title: const Text('Quarantine Zone'),
      ),
      body: SafeArea(
        child: simulation.when(
          loading: () => const Center(
            child: AppLoadingProgressBar(label: 'Loading your progress…'),
          ),
          error: (_, _) => AppErrorState(
            title: 'Quarantine Zone unavailable',
            message: 'Your saved draft is safe. Retry loading the cartons.',
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
                .firstWhere((item) => item.workstationId == 'quarantine-zone');
            if (value.mission.id != widget.missionId ||
                station.status == WorkstationStatus.locked) {
              return AppErrorState(
                title: 'Quarantine Zone is locked',
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
                ref
                    .read(
                      workplaceSimulationControllerProvider(
                        widget.missionId,
                      ).notifier,
                    )
                    .recordWorkplaceEvent(
                      AttemptAuditEventType.quarantineZoneOpened,
                      screenId: 'quarantine-zone',
                    ),
              );
            }
            final cartons =
                scenario.resources
                    .where((item) => item.resourceType.name == 'carton')
                    .toList()
                  ..sort((left, right) => left.id.compareTo(right.id));
            final draft = value.attempt?.dispositionDraft;
            final dispositionsSubmitted =
                draft?.status == OperationalDraftStatus.submitted;
            final quarantineConfirmed =
                value.attempt?.completedTaskIds.contains(
                  'confirm-quarantine',
                ) ??
                false;
            final heldCartonIds = (draft?.entries ?? const [])
                .where(
                  (entry) =>
                      entry.disposition == DispositionType.quarantine ||
                      entry.disposition == DispositionType.holdForVerification,
                )
                .map((entry) => entry.cartonId)
                .toSet();
            final heldCartons = cartons
                .where((carton) => heldCartonIds.contains(carton.id))
                .toList();
            final releaseDraft = value.attempt?.quarantineReleaseDraft;
            final releaseDecisionsSubmitted =
                releaseDraft?.status == OperationalDraftStatus.submitted;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assign a disposition to every carton',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Keep problematic stock out of available inventory. A reason is required for every disposition except Accept.',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      for (final carton in cartons) ...[
                        Builder(
                          builder: (context) {
                            DispositionEntry? entry;
                            for (final item
                                in draft?.entries ??
                                    const <DispositionEntry>[]) {
                              if (item.cartonId == carton.id) entry = item;
                            }
                            return AppCard(
                              semanticLabel:
                                  '${carton.title}, ${carton.content['sku']}',
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          carton.title,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                        Text('${carton.content['sku']}'),
                                        if (entry == null)
                                          const Text('Not assigned')
                                        else ...[
                                          Text(
                                            _dispositionLabel(
                                              entry.disposition,
                                            ),
                                          ),
                                          if (entry.reason.isNotEmpty)
                                            Text(entry.reason),
                                          Text(
                                            'Revision ${entry.revisionNumber}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.labelSmall,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (entry != null && !dispositionsSubmitted)
                                    IconButton(
                                      tooltip:
                                          'Remove ${carton.title} disposition',
                                      onPressed: _saving
                                          ? null
                                          : () => _removeDisposition(entry!),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  if (!dispositionsSubmitted)
                                    AppButton(
                                      // Shrink-wraps rather than filling
                                      // this Row's remaining width -- the
                                      // sibling text column is already
                                      // Expanded, and AppButton's default
                                      // expand: true would ask for
                                      // infinite width as a bare Row
                                      // child.
                                      expand: false,
                                      variant: AppButtonVariant.secondary,
                                      label: entry == null ? 'Assign' : 'Edit',
                                      onPressed: _saving
                                          ? null
                                          : () => _editDisposition(
                                              carton.id,
                                              entry,
                                            ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      Semantics(
                        liveRegion: true,
                        label:
                            '${draft?.entries.length ?? 0} of '
                            '${cartons.length} cartons assigned',
                        child: Text(
                          'Disposition progress: ${draft?.entries.length ?? 0} '
                          'of ${cartons.length} cartons assigned',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (!dispositionsSubmitted)
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            AppButton(
                              label: 'Save draft',
                              variant: AppButtonVariant.secondary,
                              expand: false,
                              isLoading: _saving,
                              onPressed: _saving ? null : _saveDraft,
                            ),
                            AppButton(
                              label: 'Submit dispositions',
                              expand: false,
                              isLoading: _saving,
                              onPressed: _saving ? null : _submitDispositions,
                            ),
                          ],
                        )
                      else ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Confirm separation',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                          'Confirm every problematic carton has been physically moved to the quarantine cage.',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppButton(
                          label: quarantineConfirmed
                              ? 'Separation confirmed'
                              : 'Confirm all exceptions separated',
                          expand: false,
                          isLoading: _saving,
                          onPressed: quarantineConfirmed || _saving
                              ? null
                              : _confirmQuarantine,
                        ),
                      ],
                      if (quarantineConfirmed) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Request supervisor release decisions',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                          'Releasing held stock to available inventory is a '
                          'supervisor-approval decision. Recommend an outcome '
                          'for every carton still quarantined or on hold, and '
                          'justify it.',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (heldCartons.isEmpty)
                          const Text(
                            'Nothing is currently quarantined or on hold.',
                          )
                        else ...[
                          for (final carton in heldCartons) ...[
                            Builder(
                              builder: (context) {
                                QuarantineReleaseEntry? entry;
                                for (final item
                                    in releaseDraft?.entries ??
                                        const <QuarantineReleaseEntry>[]) {
                                  if (item.cartonId == carton.id) entry = item;
                                }
                                return AppCard(
                                  semanticLabel:
                                      '${carton.title}, ${carton.content['sku']}',
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              carton.title,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleMedium,
                                            ),
                                            Text('${carton.content['sku']}'),
                                            if (entry == null)
                                              const Text('Not recommended')
                                            else ...[
                                              Text(
                                                _releaseDecisionLabel(
                                                  entry.decision,
                                                ),
                                              ),
                                              Text(entry.justification),
                                              Text(
                                                'Revision ${entry.revisionNumber}',
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.labelSmall,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (entry != null &&
                                          !releaseDecisionsSubmitted)
                                        IconButton(
                                          tooltip:
                                              'Remove ${carton.title} release recommendation',
                                          onPressed: _saving
                                              ? null
                                              : () => _removeReleaseDecision(
                                                  entry!,
                                                ),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                        ),
                                      if (!releaseDecisionsSubmitted)
                                        AppButton(
                                          // Same reasoning as the
                                          // disposition row above: this
                                          // sits as a bare (non-Expanded)
                                          // Row child alongside an
                                          // Expanded text column.
                                          expand: false,
                                          variant: AppButtonVariant.secondary,
                                          label: entry == null
                                              ? 'Recommend'
                                              : 'Edit',
                                          onPressed: _saving
                                              ? null
                                              : () => _editReleaseDecision(
                                                  carton.id,
                                                  entry,
                                                ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          Semantics(
                            liveRegion: true,
                            label:
                                '${releaseDraft?.entries.length ?? 0} of '
                                '${heldCartons.length} release decisions recommended',
                            child: Text(
                              'Release progress: '
                              '${releaseDraft?.entries.length ?? 0} of '
                              '${heldCartons.length} recommended',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        if (!releaseDecisionsSubmitted)
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              AppButton(
                                label: 'Save draft',
                                variant: AppButtonVariant.secondary,
                                expand: false,
                                isLoading: _saving,
                                onPressed: _saving ? null : _saveReleaseDraft,
                              ),
                              AppButton(
                                label: 'Submit release decisions',
                                expand: false,
                                isLoading: _saving,
                                onPressed: _saving
                                    ? null
                                    : _submitQuarantineRelease,
                              ),
                            ],
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

  Future<void> _editDisposition(
    String cartonId,
    DispositionEntry? entry,
  ) async {
    final input = await _showDispositionEditor(entry);
    if (input == null) return;
    if (entry == null) {
      final result = await ref
          .read(
            workplaceSimulationControllerProvider(widget.missionId).notifier,
          )
          .recordDisposition(
            RecordDispositionCommand(
              cartonId: cartonId,
              disposition: input.$1,
              reason: input.$2,
            ),
          );
      if (mounted && result != RecordDispositionResult.success) {
        _showMessage(
          result == RecordDispositionResult.reasonRequired
              ? 'Enter a reason for this disposition.'
              : 'The disposition could not be recorded.',
        );
      }
    } else {
      final result = await ref
          .read(
            workplaceSimulationControllerProvider(widget.missionId).notifier,
          )
          .updateDisposition(
            UpdateDispositionCommand(
              entryId: entry.id,
              disposition: input.$1,
              reason: input.$2,
            ),
          );
      if (mounted && result != UpdateDispositionResult.success) {
        _showMessage(
          result == UpdateDispositionResult.reasonRequired
              ? 'Enter a reason for this disposition.'
              : 'The disposition could not be updated.',
        );
      }
    }
  }

  Future<(DispositionType, String)?> _showDispositionEditor(
    DispositionEntry? entry,
  ) async {
    var disposition = entry?.disposition ?? DispositionType.accept;
    final reason = TextEditingController(text: entry?.reason);
    String? validation;
    final result = await showDialog<(DispositionType, String)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            entry == null ? 'Assign disposition' : 'Edit disposition',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<DispositionType>(
                  initialValue: disposition,
                  decoration: const InputDecoration(
                    labelText: 'Disposition',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final value in DispositionType.values)
                      DropdownMenuItem(
                        value: value,
                        child: Text(_dispositionLabel(value)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => disposition = value);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: reason,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: disposition == DispositionType.accept
                        ? 'Reason (optional)'
                        : 'Reason (required)',
                    errorText: validation,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (disposition != DispositionType.accept &&
                    reason.text.trim().isEmpty) {
                  setDialogState(
                    () => validation =
                        'A reason is required for this disposition.',
                  );
                  return;
                }
                Navigator.pop(context, (disposition, reason.text.trim()));
              },
              child: const Text('Save disposition'),
            ),
          ],
        ),
      ),
    );
    reason.dispose();
    return result;
  }

  Future<void> _removeDisposition(DispositionEntry entry) async {
    final result = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .removeDisposition(RemoveDispositionCommand(entry.id));
    if (mounted && result != RemoveDispositionResult.success) {
      _showMessage('The disposition could not be removed.');
    }
  }

  Future<void> _saveDraft() async {
    setState(() => _saving = true);
    final result = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .saveDispositionDraft(const SaveDispositionDraftCommand());
    if (!mounted) return;
    setState(() => _saving = false);
    _showMessage(
      result == SaveDispositionDraftResult.success
          ? 'Draft saved.'
          : 'Draft could not be saved.',
    );
  }

  Future<void> _submitDispositions() async {
    setState(() => _saving = true);
    final result = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .submitDispositions(const SubmitDispositionsCommand());
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case SubmitDispositionsResult.success:
        _showMessage('Dispositions submitted.');
      case SubmitDispositionsResult.incompleteDispositions:
        _showMessage('Assign a disposition to every carton before submitting.');
      default:
        _showMessage('The dispositions could not be submitted.');
    }
  }

  Future<void> _confirmQuarantine() async {
    setState(() => _saving = true);
    final result = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .confirmQuarantine(const ConfirmQuarantineCommand());
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case ConfirmQuarantineResult.success:
        _showMessage('Separation confirmed. Request release decisions next.');
      case ConfirmQuarantineResult.dispositionsNotSubmitted:
        _showMessage('Submit dispositions for every carton first.');
      default:
        _showMessage('The separation could not be confirmed.');
    }
  }

  Future<void> _editReleaseDecision(
    String cartonId,
    QuarantineReleaseEntry? entry,
  ) async {
    final input = await _showReleaseDecisionEditor(entry);
    if (input == null) return;
    final controller = ref.read(
      workplaceSimulationControllerProvider(widget.missionId).notifier,
    );
    if (entry == null) {
      final result = await controller.recordReleaseDecision(
        RecordReleaseDecisionCommand(
          cartonId: cartonId,
          decision: input.$1,
          justification: input.$2,
        ),
      );
      if (mounted && result != RecordReleaseDecisionResult.success) {
        _showMessage(
          result == RecordReleaseDecisionResult.justificationRequired
              ? 'Enter a justification for this recommendation.'
              : 'The release recommendation could not be recorded.',
        );
      }
    } else {
      final result = await controller.updateReleaseDecision(
        UpdateReleaseDecisionCommand(
          entryId: entry.id,
          decision: input.$1,
          justification: input.$2,
        ),
      );
      if (mounted && result != UpdateReleaseDecisionResult.success) {
        _showMessage(
          result == UpdateReleaseDecisionResult.justificationRequired
              ? 'Enter a justification for this recommendation.'
              : 'The release recommendation could not be updated.',
        );
      }
    }
  }

  Future<(ReleaseDecision, String)?> _showReleaseDecisionEditor(
    QuarantineReleaseEntry? entry,
  ) async {
    var decision = entry?.decision ?? ReleaseDecision.continueHold;
    final justification = TextEditingController(text: entry?.justification);
    String? validation;
    final result = await showDialog<(ReleaseDecision, String)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            entry == null
                ? 'Recommend release decision'
                : 'Edit recommendation',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<ReleaseDecision>(
                  initialValue: decision,
                  decoration: const InputDecoration(
                    labelText: 'Release decision',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    // notApplicable is system-recorded only -- see its doc
                    // comment in simulation_enums.dart -- never offered as a
                    // candidate choice.
                    for (final value in ReleaseDecision.values)
                      if (value != ReleaseDecision.notApplicable)
                        DropdownMenuItem(
                          value: value,
                          child: Text(_releaseDecisionLabel(value)),
                        ),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => decision = value);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: justification,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Justification (required)',
                    errorText: validation,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (justification.text.trim().isEmpty) {
                  setDialogState(
                    () => validation =
                        'A justification is required for every recommendation.',
                  );
                  return;
                }
                Navigator.pop(context, (decision, justification.text.trim()));
              },
              child: const Text('Save recommendation'),
            ),
          ],
        ),
      ),
    );
    justification.dispose();
    return result;
  }

  Future<void> _removeReleaseDecision(QuarantineReleaseEntry entry) async {
    final result = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .removeReleaseDecision(RemoveReleaseDecisionCommand(entry.id));
    if (mounted && result != RemoveReleaseDecisionResult.success) {
      _showMessage('The release recommendation could not be removed.');
    }
  }

  Future<void> _saveReleaseDraft() async {
    setState(() => _saving = true);
    final result = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .saveQuarantineReleaseDraft(const SaveQuarantineReleaseDraftCommand());
    if (!mounted) return;
    setState(() => _saving = false);
    _showMessage(
      result == SaveQuarantineReleaseDraftResult.success
          ? 'Draft saved.'
          : 'Draft could not be saved.',
    );
  }

  Future<void> _submitQuarantineRelease() async {
    setState(() => _saving = true);
    final result = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .submitQuarantineRelease(const SubmitQuarantineReleaseCommand());
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case SubmitQuarantineReleaseResult.success:
        _showMessage('Release decisions submitted. Receiving Office unlocked.');
        widget.onOpenReceivingOffice();
      case SubmitQuarantineReleaseResult.incompleteReleaseDecisions:
        _showMessage(
          'Recommend a release decision for every held carton first.',
        );
      case SubmitQuarantineReleaseResult.quarantineNotConfirmed:
        _showMessage('Confirm exception separation first.');
      default:
        _showMessage('The release decisions could not be submitted.');
    }
  }

  Future<void> _exit() async {
    await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordWorkplaceEvent(
          AttemptAuditEventType.quarantineZoneExited,
          screenId: 'quarantine-zone',
        );
    if (mounted) widget.onBack();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

String _dispositionLabel(DispositionType disposition) => switch (disposition) {
  DispositionType.accept => 'Accept',
  DispositionType.quarantine => 'Quarantine',
  DispositionType.holdForVerification => 'Hold for verification',
  DispositionType.rejectReturn => 'Reject / return',
  DispositionType.escalate => 'Escalate',
};

String _releaseDecisionLabel(ReleaseDecision decision) => switch (decision) {
  ReleaseDecision.releaseToStock => 'Release to stock',
  ReleaseDecision.continueHold => 'Continue hold',
  ReleaseDecision.returnToSupplier => 'Return to supplier',
  ReleaseDecision.disposeOnSite => 'Dispose on site',
  ReleaseDecision.notApplicable => 'Not applicable',
};
