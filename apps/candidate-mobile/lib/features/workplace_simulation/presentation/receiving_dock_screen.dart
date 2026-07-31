import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_state_view.dart';
import '../application/workplace_interaction_contracts.dart';
import '../application/workplace_simulation_controller.dart';
import '../domain/simulation_enums.dart';
import '../domain/workplace_task_drafts.dart';

class ReceivingDockScreen extends ConsumerStatefulWidget {
  const ReceivingDockScreen({
    required this.missionId,
    required this.onBack,
    required this.onOpenInspectionZone,
    required this.onMissionComplete,
    super.key,
  });

  final String missionId;
  final VoidCallback onBack;
  final VoidCallback onOpenInspectionZone;
  final VoidCallback onMissionComplete;

  @override
  ConsumerState<ReceivingDockScreen> createState() =>
      _ReceivingDockScreenState();
}

class _ReceivingDockScreenState extends ConsumerState<ReceivingDockScreen> {
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
        title: const Text('Receiving Dock'),
      ),
      body: SafeArea(
        child: simulation.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AppErrorState(
            title: 'Receiving Dock unavailable',
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
                .firstWhere((item) => item.workstationId == 'receiving-dock');
            if (value.mission.id != widget.missionId ||
                station.status == WorkstationStatus.locked) {
              return AppErrorState(
                title: 'Receiving Dock is locked',
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
                      AttemptAuditEventType.receivingDockOpened,
                      screenId: 'receiving-dock',
                    ),
              );
            }
            final cartons =
                scenario.resources
                    .where((item) => item.resourceType.name == 'carton')
                    .toList()
                  ..sort((left, right) => left.id.compareTo(right.id));
            final draft = value.attempt?.receivingCountDraft;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Confirm and count the delivery',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Apex Consumer Products · PO-2026-001 · DN-2026-001',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Shipment identity',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Confirm whether the physical shipment matches these delivery references before submission.',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          AppButton(
                            label: 'Matches expected delivery',
                            variant: draft?.shipmentConfirmed == true
                                ? AppButtonVariant.primary
                                : AppButtonVariant.secondary,
                            expand: false,
                            onPressed: _saving
                                ? null
                                : () => _confirmIdentity(true),
                          ),
                          AppButton(
                            label: "Doesn't match — wrong supplier",
                            variant: draft?.shipmentConfirmed == false
                                ? AppButtonVariant.primary
                                : AppButtonVariant.secondary,
                            expand: false,
                            onPressed: _saving
                                ? null
                                : () => _confirmIdentity(false),
                          ),
                        ],
                      ),
                      if (draft?.shipmentConfirmed == false) ...[
                        const SizedBox(height: AppSpacing.md),
                        AppCard(
                          backgroundColor: AppColors.warningSoft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'This does not match the expected delivery',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              const Text(
                                'Rejecting here ends the shift immediately. '
                                'No further counting or inspection is needed '
                                'for stock that should never be accepted '
                                'onto the dock.',
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              AppButton(
                                label: 'Reject shipment & end shift',
                                variant: AppButtonVariant.destructive,
                                expand: false,
                                isLoading: _saving,
                                onPressed: _saving ? null : _rejectShipment,
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Carton counts',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Text(
                        'Count every carton. Expected physical quantities are not shown.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      for (final carton in cartons) ...[
                        Builder(
                          builder: (context) {
                            ReceivingCountEntry? entry;
                            for (final item
                                in draft?.countEntries ??
                                    const <ReceivingCountEntry>[]) {
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
                                          const Text('Not counted')
                                        else ...[
                                          Text(
                                            'Entered ${entry.enteredQuantity} · '
                                            '${_methodLabel(entry.countMethod)}',
                                          ),
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
                                  if (entry != null)
                                    IconButton(
                                      tooltip: 'Remove ${carton.title} count',
                                      onPressed: _saving
                                          ? null
                                          : () => _removeEntry(entry!),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  OutlinedButton(
                                    onPressed: _saving
                                        ? null
                                        : () => _editCount(carton.id, entry),
                                    child: Text(
                                      entry == null ? 'Record count' : 'Edit',
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
                            '${draft?.countEntries.length ?? 0} of '
                            '${cartons.length} cartons counted',
                        child: Text(
                          'Count progress: ${draft?.countEntries.length ?? 0} '
                          'of ${cartons.length} cartons counted',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
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
                            label: 'Submit receiving count',
                            expand: false,
                            isLoading: _saving,
                            onPressed: _saving ? null : _submit,
                          ),
                        ],
                      ),
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

  Future<void> _confirmIdentity(bool confirmed) async {
    final result = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .confirmShipmentIdentity(
          ConfirmShipmentIdentityCommand(confirmed: confirmed),
        );
    if (mounted && result != ConfirmShipmentIdentityResult.success) {
      _showMessage('Shipment confirmation could not be saved.');
    }
  }

  Future<void> _rejectShipment() async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: 'End the shift now?',
      message:
          'Rejecting this delivery submits your shift immediately. You '
          "won't be able to count, inspect or dispose of any cartons "
          'afterwards.',
      confirmLabel: 'Reject & end shift',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    final result = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .rejectShipmentIdentity();
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case RejectShipmentIdentityResult.success:
        widget.onMissionComplete();
      case RejectShipmentIdentityResult.notYetRejected:
        _showMessage('Mark the delivery as not matching before rejecting.');
      case RejectShipmentIdentityResult.alreadySubmitted:
        _showMessage('The receiving count has already been submitted.');
      default:
        _showMessage('The shipment could not be rejected.');
    }
  }

  Future<void> _editCount(String cartonId, ReceivingCountEntry? entry) async {
    final input = await _showCountEditor(entry);
    if (input == null) return;
    if (entry == null) {
      final result = await ref
          .read(
            workplaceSimulationControllerProvider(widget.missionId).notifier,
          )
          .recordCartonCount(
            RecordCartonCountCommand(
              cartonId: cartonId,
              enteredQuantity: input.$1,
              countMethod: input.$2,
              learnerNotes: input.$3,
            ),
          );
      if (mounted && result != RecordCartonCountResult.success) {
        _showMessage('The carton count could not be recorded.');
      }
    } else {
      final result = await ref
          .read(
            workplaceSimulationControllerProvider(widget.missionId).notifier,
          )
          .updateCartonCount(
            UpdateCartonCountCommand(
              entryId: entry.id,
              enteredQuantity: input.$1,
              countMethod: input.$2,
              learnerNotes: input.$3,
            ),
          );
      if (mounted && result != UpdateCartonCountResult.success) {
        _showMessage('The carton count could not be updated.');
      }
    }
  }

  Future<(int, CountMethod, String)?> _showCountEditor(
    ReceivingCountEntry? entry,
  ) async {
    final quantity = TextEditingController(
      text: entry?.enteredQuantity.toString(),
    );
    final notes = TextEditingController(text: entry?.learnerNotes);
    var method = entry?.countMethod ?? CountMethod.individual;
    String? validation;
    final result = await showDialog<(int, CountMethod, String)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(entry == null ? 'Record carton count' : 'Edit count'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: quantity,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Physical quantity',
                    helperText: 'Whole number from 0 to 500',
                    errorText: validation,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<CountMethod>(
                  initialValue: method,
                  decoration: const InputDecoration(
                    labelText: 'Count method',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final value in CountMethod.values)
                      DropdownMenuItem(
                        value: value,
                        child: Text(_methodLabel(value)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => method = value);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: notes,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
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
                final entered = int.tryParse(quantity.text);
                if (entered == null || entered < 0 || entered > 500) {
                  setDialogState(
                    () => validation = 'Enter a whole number from 0 to 500.',
                  );
                  return;
                }
                Navigator.pop(context, (entered, method, notes.text));
              },
              child: const Text('Save count'),
            ),
          ],
        ),
      ),
    );
    quantity.dispose();
    notes.dispose();
    return result;
  }

  Future<void> _removeEntry(ReceivingCountEntry entry) async {
    final result = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .removeCartonCount(RemoveCartonCountCommand(entry.id));
    if (mounted && result != RemoveCartonCountResult.success) {
      _showMessage('The carton count could not be removed.');
    }
  }

  Future<void> _saveDraft() async {
    setState(() => _saving = true);
    final result = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .saveReceivingCountDraft(const SaveReceivingCountDraftCommand());
    if (!mounted) return;
    setState(() => _saving = false);
    _showMessage(
      result == SaveReceivingCountDraftResult.success
          ? 'Draft saved.'
          : 'Draft could not be saved.',
    );
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final result = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .submitReceivingCount(const SubmitReceivingCountCommand());
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case SubmitReceivingCountResult.success:
        _showMessage('Receiving count submitted. Inspection Zone unlocked.');
        widget.onOpenInspectionZone();
      case SubmitReceivingCountResult.shipmentNotConfirmed:
        _showMessage('Confirm the shipment identity before submitting.');
      case SubmitReceivingCountResult.incompleteCounts:
        _showMessage('Record a count for every carton before submitting.');
      default:
        _showMessage('The receiving count could not be submitted.');
    }
  }

  Future<void> _exit() async {
    await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordWorkplaceEvent(
          AttemptAuditEventType.receivingDockExited,
          screenId: 'receiving-dock',
        );
    if (mounted) widget.onBack();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

String _methodLabel(CountMethod method) => switch (method) {
  CountMethod.individual => 'Individual count',
  CountMethod.sealedCarton => 'Sealed carton',
  CountMethod.estimated => 'Estimated',
};
