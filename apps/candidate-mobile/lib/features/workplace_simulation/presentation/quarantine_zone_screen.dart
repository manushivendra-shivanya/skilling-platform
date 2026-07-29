import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
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
    final simulation = ref.watch(workplaceSimulationControllerProvider);
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
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AppErrorState(
            title: 'Quarantine Zone unavailable',
            message: 'Your saved draft is safe. Retry loading the cartons.',
            actionLabel: 'Retry',
            onAction: () =>
                ref.invalidate(workplaceSimulationControllerProvider),
          ),
          data: (value) {
            final controller = ref.read(
              workplaceSimulationControllerProvider.notifier,
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
                    .read(workplaceSimulationControllerProvider.notifier)
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
                                    OutlinedButton(
                                      onPressed: _saving
                                          ? null
                                          : () => _editDisposition(
                                              carton.id,
                                              entry,
                                            ),
                                      child: Text(
                                        entry == null ? 'Assign' : 'Edit',
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
          .read(workplaceSimulationControllerProvider.notifier)
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
          .read(workplaceSimulationControllerProvider.notifier)
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
        .read(workplaceSimulationControllerProvider.notifier)
        .removeDisposition(RemoveDispositionCommand(entry.id));
    if (mounted && result != RemoveDispositionResult.success) {
      _showMessage('The disposition could not be removed.');
    }
  }

  Future<void> _saveDraft() async {
    setState(() => _saving = true);
    final result = await ref
        .read(workplaceSimulationControllerProvider.notifier)
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
        .read(workplaceSimulationControllerProvider.notifier)
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
        .read(workplaceSimulationControllerProvider.notifier)
        .confirmQuarantine(const ConfirmQuarantineCommand());
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case ConfirmQuarantineResult.success:
        _showMessage('Separation confirmed. Receiving Office unlocked.');
        widget.onOpenReceivingOffice();
      case ConfirmQuarantineResult.dispositionsNotSubmitted:
        _showMessage('Submit dispositions for every carton first.');
      default:
        _showMessage('The separation could not be confirmed.');
    }
  }

  Future<void> _exit() async {
    await ref
        .read(workplaceSimulationControllerProvider.notifier)
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
