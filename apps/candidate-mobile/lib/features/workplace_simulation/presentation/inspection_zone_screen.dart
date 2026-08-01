import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_state_view.dart';
import '../application/workplace_interaction_contracts.dart';
import '../application/workplace_simulation_controller.dart';
import '../domain/simulation_content.dart';
import '../domain/simulation_enums.dart';
import '../domain/workplace_task_drafts.dart';
import 'widgets/supervisor_dialogue.dart';

class InspectionZoneScreen extends ConsumerStatefulWidget {
  const InspectionZoneScreen({
    required this.missionId,
    required this.onBack,
    required this.onOpenBarcodeStation,
    super.key,
  });

  final String missionId;
  final VoidCallback onBack;
  final VoidCallback onOpenBarcodeStation;

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
        actions: [
          IconButton(
            tooltip: 'Ask the supervisor',
            onPressed: _saving ? null : _askSupervisor,
            icon: const Icon(Icons.forum_outlined),
          ),
        ],
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
                        'Inspect every carton',
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
                                          Text(
                                            entry.findings
                                                .map(_findingLabel)
                                                .join(', '),
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
              findings: input.$1,
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
              findings: input.$1,
              learnerNotes: input.$2,
            ),
          );
      if (mounted && result != UpdateCartonInspectionResult.success) {
        _showMessage('The inspection could not be updated.');
      }
    }
  }

  Future<(List<CartonFinding>, String)?> _showInspectionEditor(
    CartonInspectionEntry? entry,
  ) async {
    var findings = (entry?.findings ?? const [CartonFinding.compliant]).toSet();
    final notes = TextEditingController(text: entry?.learnerNotes);
    final result = await showDialog<(List<CartonFinding>, String)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(entry == null ? 'Inspect carton' : 'Edit inspection'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select every finding that applies. A compliant carton '
                  "can't also carry another finding.",
                ),
                for (final value in CartonFinding.values)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: findings.contains(value),
                    title: Text(_findingLabel(value)),
                    onChanged: (selected) {
                      setDialogState(() {
                        if (selected != true) {
                          findings = {...findings}..remove(value);
                          return;
                        }
                        findings = value == CartonFinding.compliant
                            ? {CartonFinding.compliant}
                            : ({...findings}
                                ..remove(CartonFinding.compliant)
                                ..add(value));
                      });
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
              onPressed: findings.isEmpty
                  ? null
                  : () => Navigator.pop(context, (
                      findings.toList(growable: false),
                      notes.text,
                    )),
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
        _showMessage('Inspection submitted. Barcode Station unlocked.');
        widget.onOpenBarcodeStation();
      case SubmitInspectionResult.incompleteInspection:
        _showMessage('Inspect every carton before submitting.');
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

  Future<void> _askSupervisor() async {
    final scenario = ref
        .read(workplaceSimulationControllerProvider(widget.missionId))
        .valueOrNull
        ?.scenario;
    if (scenario == null) return;
    SimulationResource? supervisor;
    for (final item in scenario.resources) {
      if (item.resourceType == ResourceType.person) supervisor = item;
    }
    if (supervisor == null) return;
    final topics = npcDialogueLines(
      supervisor,
    ).where((item) => item.trigger == 'learner_asks').toList();
    if (topics.isEmpty || !mounted) return;
    await showAskSupervisorMenu(
      context,
      supervisorTitle: supervisor.title,
      topics: topics,
    );
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
