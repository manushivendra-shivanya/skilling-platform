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

class InspectionZoneScreen extends ConsumerStatefulWidget {
  const InspectionZoneScreen({
    required this.missionId,
    required this.onBack,
    required this.onOpenQuarantineZone,
    super.key,
  });

  final String missionId;
  final VoidCallback onBack;
  final VoidCallback onOpenQuarantineZone;

  @override
  ConsumerState<InspectionZoneScreen> createState() =>
      _InspectionZoneScreenState();
}

class _InspectionZoneScreenState extends ConsumerState<InspectionZoneScreen> {
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
        title: const Text('Inspection Zone'),
      ),
      body: SafeArea(
        child: simulation.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AppErrorState(
            title: 'Inspection Zone unavailable',
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
                .firstWhere((item) => item.workstationId == 'inspection-zone');
            if (value.mission.id != widget.missionId ||
                station.status == WorkstationStatus.locked) {
              return AppErrorState(
                title: 'Inspection Zone is locked',
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
                      AttemptAuditEventType.inspectionZoneOpened,
                      screenId: 'inspection-zone',
                    ),
              );
            }
            final cartons =
                scenario.resources
                    .where((item) => item.resourceType.name == 'carton')
                    .toList()
                  ..sort((left, right) => left.id.compareTo(right.id));
            final draft = value.attempt?.inspectionDraft;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inspect and scan every carton',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Record what you observe. Expected findings are not shown.',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Carton inspection',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      for (final carton in cartons) ...[
                        Builder(
                          builder: (context) {
                            CartonInspectionEntry? entry;
                            for (final item
                                in draft?.cartonInspections ??
                                    const <CartonInspectionEntry>[]) {
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
                                          const Text('Not inspected')
                                        else ...[
                                          Text(_findingLabel(entry.finding)),
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
                                      tooltip:
                                          'Remove ${carton.title} inspection',
                                      onPressed: _saving
                                          ? null
                                          : () => _removeInspection(entry!),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  OutlinedButton(
                                    onPressed: _saving
                                        ? null
                                        : () =>
                                              _editInspection(carton.id, entry),
                                    child: Text(
                                      entry == null ? 'Inspect' : 'Edit',
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
                            '${draft?.cartonInspections.length ?? 0} of '
                            '${cartons.length} cartons inspected',
                        child: Text(
                          'Inspection progress: '
                          '${draft?.cartonInspections.length ?? 0} of '
                          '${cartons.length} cartons inspected',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Barcode scanning',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      for (final carton in cartons) ...[
                        Builder(
                          builder: (context) {
                            BarcodeScanEntry? entry;
                            for (final item
                                in draft?.barcodeScans ??
                                    const <BarcodeScanEntry>[]) {
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
                                          const Text('Not scanned')
                                        else ...[
                                          Text(_statusLabel(entry.status)),
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
                                      tooltip: 'Remove ${carton.title} scan',
                                      onPressed: _saving
                                          ? null
                                          : () => _removeScan(entry!),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  OutlinedButton(
                                    onPressed: _saving
                                        ? null
                                        : () => _editScan(carton.id, entry),
                                    child: Text(
                                      entry == null ? 'Scan' : 'Edit',
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
                            '${draft?.barcodeScans.length ?? 0} of '
                            '${cartons.length} cartons scanned',
                        child: Text(
                          'Scan progress: ${draft?.barcodeScans.length ?? 0} '
                          'of ${cartons.length} cartons scanned',
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
                            label: 'Submit inspection',
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

  Future<void> _editInspection(
    String cartonId,
    CartonInspectionEntry? entry,
  ) async {
    final input = await _showInspectionEditor(entry);
    if (input == null) return;
    if (entry == null) {
      final result = await ref
          .read(
            workplaceSimulationControllerProvider(widget.missionId).notifier,
          )
          .recordCartonInspection(
            RecordCartonInspectionCommand(
              cartonId: cartonId,
              finding: input.$1,
              learnerNotes: input.$2,
            ),
          );
      if (mounted && result != RecordCartonInspectionResult.success) {
        _showMessage('The inspection could not be recorded.');
      }
    } else {
      final result = await ref
          .read(
            workplaceSimulationControllerProvider(widget.missionId).notifier,
          )
          .updateCartonInspection(
            UpdateCartonInspectionCommand(
              entryId: entry.id,
              finding: input.$1,
              learnerNotes: input.$2,
            ),
          );
      if (mounted && result != UpdateCartonInspectionResult.success) {
        _showMessage('The inspection could not be updated.');
      }
    }
  }

  Future<(CartonFinding, String)?> _showInspectionEditor(
    CartonInspectionEntry? entry,
  ) async {
    var finding = entry?.finding ?? CartonFinding.compliant;
    final notes = TextEditingController(text: entry?.learnerNotes);
    final result = await showDialog<(CartonFinding, String)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(entry == null ? 'Inspect carton' : 'Edit inspection'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<CartonFinding>(
                  initialValue: finding,
                  decoration: const InputDecoration(
                    labelText: 'Finding',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final value in CartonFinding.values)
                      DropdownMenuItem(
                        value: value,
                        child: Text(_findingLabel(value)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => finding = value);
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
              onPressed: () => Navigator.pop(context, (finding, notes.text)),
              child: const Text('Save finding'),
            ),
          ],
        ),
      ),
    );
    notes.dispose();
    return result;
  }

  Future<void> _removeInspection(CartonInspectionEntry entry) async {
    final result = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .removeCartonInspection(RemoveCartonInspectionCommand(entry.id));
    if (mounted && result != RemoveCartonInspectionResult.success) {
      _showMessage('The inspection could not be removed.');
    }
  }

  Future<void> _editScan(String cartonId, BarcodeScanEntry? entry) async {
    final input = await _showScanEditor(entry);
    if (input == null) return;
    if (entry == null) {
      final result = await ref
          .read(
            workplaceSimulationControllerProvider(widget.missionId).notifier,
          )
          .recordBarcodeScan(
            RecordBarcodeScanCommand(cartonId: cartonId, status: input),
          );
      if (mounted && result != RecordBarcodeScanResult.success) {
        _showMessage('The scan could not be recorded.');
      }
    } else {
      final result = await ref
          .read(
            workplaceSimulationControllerProvider(widget.missionId).notifier,
          )
          .updateBarcodeScan(
            UpdateBarcodeScanCommand(entryId: entry.id, status: input),
          );
      if (mounted && result != UpdateBarcodeScanResult.success) {
        _showMessage('The scan could not be updated.');
      }
    }
  }

  Future<BarcodeStatus?> _showScanEditor(BarcodeScanEntry? entry) async {
    var status = entry?.status ?? BarcodeStatus.readable;
    return showDialog<BarcodeStatus>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(entry == null ? 'Scan barcode' : 'Edit scan'),
          content: DropdownButtonFormField<BarcodeStatus>(
            initialValue: status,
            decoration: const InputDecoration(
              labelText: 'Barcode status',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final value in BarcodeStatus.values)
                DropdownMenuItem(
                  value: value,
                  child: Text(_statusLabel(value)),
                ),
            ],
            onChanged: (value) {
              if (value != null) setDialogState(() => status = value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, status),
              child: const Text('Save scan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeScan(BarcodeScanEntry entry) async {
    final result = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .removeBarcodeScan(RemoveBarcodeScanCommand(entry.id));
    if (mounted && result != RemoveBarcodeScanResult.success) {
      _showMessage('The scan could not be removed.');
    }
  }

  Future<void> _saveDraft() async {
    setState(() => _saving = true);
    final result = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .saveInspectionDraft(const SaveInspectionDraftCommand());
    if (!mounted) return;
    setState(() => _saving = false);
    _showMessage(
      result == SaveInspectionDraftResult.success
          ? 'Draft saved.'
          : 'Draft could not be saved.',
    );
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final result = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .submitInspection(const SubmitInspectionCommand());
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case SubmitInspectionResult.success:
        _showMessage('Inspection submitted. Quarantine Zone unlocked.');
        widget.onOpenQuarantineZone();
      case SubmitInspectionResult.incompleteInspection:
        _showMessage('Inspect every carton before submitting.');
      case SubmitInspectionResult.incompleteScans:
        _showMessage('Scan every barcode before submitting.');
      default:
        _showMessage('The inspection could not be submitted.');
    }
  }

  Future<void> _exit() async {
    await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordWorkplaceEvent(
          AttemptAuditEventType.inspectionZoneExited,
          screenId: 'inspection-zone',
        );
    if (mounted) widget.onBack();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

String _findingLabel(CartonFinding finding) => switch (finding) {
  CartonFinding.compliant => 'Compliant',
  CartonFinding.packagingDamage => 'Packaging damage',
  CartonFinding.nearExpiry => 'Near expiry',
  CartonFinding.incorrectSku => 'Incorrect SKU',
  CartonFinding.quantityShortage => 'Quantity shortage',
  CartonFinding.unreadableBarcode => 'Unreadable barcode',
};

String _statusLabel(BarcodeStatus status) => switch (status) {
  BarcodeStatus.readable => 'Readable',
  BarcodeStatus.unreadable => 'Unreadable',
};
