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

class DocumentDeskScreen extends ConsumerStatefulWidget {
  const DocumentDeskScreen({
    required this.missionId,
    required this.onBack,
    super.key,
  });

  final String missionId;
  final VoidCallback onBack;

  @override
  ConsumerState<DocumentDeskScreen> createState() => _DocumentDeskScreenState();
}

class _DocumentDeskScreenState extends ConsumerState<DocumentDeskScreen> {
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
        title: const Text('Document Desk'),
      ),
      body: SafeArea(
        child: simulation.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AppErrorState(
            title: 'Documents unavailable',
            message: 'Your saved draft is safe. Retry loading the documents.',
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
                .firstWhere((item) => item.workstationId == 'document-desk');
            if (value.mission.id != widget.missionId ||
                station.status == WorkstationStatus.locked) {
              return AppErrorState(
                title: 'Document Desk is locked',
                message: station.supportingText,
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
                      AttemptAuditEventType.documentDeskOpened,
                      screenId: 'document-desk',
                    ),
              );
            }
            final po = value.mission.resources.firstWhere(
              (item) => item.id == 'purchase-order-po-2026-001',
            );
            final note = value.mission.resources.firstWhere(
              (item) => item.id == 'delivery-note-dn-2026-001',
            );
            final ordered = _quantities(po.content['items'], 'orderedQuantity');
            final delivered = _quantities(
              note.content['items'],
              'deliveredQuantity',
            );
            final rows = {...ordered.keys, ...delivered.keys}.toList()..sort();
            final draft = value.attempt?.documentReviewDraft;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Compare PO-2026-001 with DN-2026-001',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Record every discrepancy you identify. Findings are not graded on this screen.',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      for (final sku in rows) ...[
                        AppCard(
                          semanticLabel:
                              '$sku, ordered ${ordered[sku] ?? 0}, delivery note ${delivered[sku] ?? 0}',
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sku,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    Text(
                                      'Ordered ${ordered[sku] ?? 0} · '
                                      'Delivery note ${delivered[sku] ?? 0}',
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              OutlinedButton(
                                onPressed: _saving
                                    ? null
                                    : () => _addFinding(sku),
                                child: const Text('Add finding'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      Text(
                        'Recorded findings',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (draft == null || draft.findings.isEmpty)
                        const AppCard(
                          child: Text(
                            'No findings recorded. Select a document row to add one.',
                          ),
                        )
                      else
                        for (final finding in draft.findings) ...[
                          AppCard(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        finding.itemReference,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      Text(_findingLabel(finding.findingType)),
                                      if (finding.learnerNotes.isNotEmpty)
                                        Text(finding.learnerNotes),
                                      Text(
                                        'Revision ${finding.revisionNumber}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelSmall,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip:
                                      'Edit finding ${finding.itemReference}',
                                  onPressed: _saving
                                      ? null
                                      : () => _editFinding(finding),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip:
                                      'Remove finding ${finding.itemReference}',
                                  onPressed: _saving
                                      ? null
                                      : () => _removeFinding(finding),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                      const SizedBox(height: AppSpacing.lg),
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
                            label: 'Submit review',
                            expand: false,
                            isLoading: _saving,
                            onPressed:
                                !_saving &&
                                    (draft?.findings.isNotEmpty ?? false)
                                ? _submit
                                : null,
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

  Map<String, int> _quantities(Object? rawItems, String quantityKey) => {
    for (final raw in rawItems! as List)
      (raw as Map<String, Object?>)['sku']! as String: raw[quantityKey]! as int,
  };

  Future<void> _addFinding(String sku) async {
    final input = await _showFindingEditor(itemReference: sku);
    if (input == null) return;
    final result = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .addDocumentFinding(input);
    if (!mounted) return;
    if (result != AddDocumentFindingResult.success) {
      _showMessage(
        result == AddDocumentFindingResult.duplicateFinding
            ? 'That finding is already recorded.'
            : 'The finding could not be added.',
      );
    }
  }

  Future<void> _editFinding(DocumentFinding finding) async {
    final input = await _showFindingEditor(
      itemReference: finding.itemReference,
      finding: finding,
    );
    if (input == null) return;
    final result = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .updateDocumentFinding(
          UpdateDocumentFindingCommand(
            findingId: finding.id,
            sourceDocument: input.sourceDocument,
            itemReference: input.itemReference,
            findingType: input.findingType,
            learnerNotes: input.learnerNotes,
          ),
        );
    if (mounted && result != UpdateDocumentFindingResult.success) {
      _showMessage('The finding could not be updated.');
    }
  }

  Future<void> _removeFinding(DocumentFinding finding) async {
    final result = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .removeDocumentFinding(RemoveDocumentFindingCommand(finding.id));
    if (mounted && result != RemoveDocumentFindingResult.success) {
      _showMessage('The finding could not be removed.');
    }
  }

  Future<AddDocumentFindingCommand?> _showFindingEditor({
    required String itemReference,
    DocumentFinding? finding,
  }) async {
    var source = finding?.sourceDocument ?? DocumentSource.both;
    var type = finding?.findingType ?? DocumentFindingType.quantityMismatch;
    final notes = TextEditingController(text: finding?.learnerNotes);
    final result = await showDialog<AddDocumentFindingCommand>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(finding == null ? 'Add finding' : 'Edit finding'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<DocumentSource>(
                  initialValue: source,
                  decoration: const InputDecoration(
                    labelText: 'Source document',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final value in DocumentSource.values)
                      DropdownMenuItem(
                        value: value,
                        child: Text(_sourceLabel(value)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => source = value);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<DocumentFindingType>(
                  initialValue: type,
                  decoration: const InputDecoration(
                    labelText: 'Finding type',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final value in DocumentFindingType.values)
                      DropdownMenuItem(
                        value: value,
                        child: Text(_findingLabel(value)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => type = value);
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
              onPressed: () => Navigator.pop(
                context,
                AddDocumentFindingCommand(
                  sourceDocument: source,
                  itemReference: itemReference,
                  findingType: type,
                  learnerNotes: notes.text,
                ),
              ),
              child: const Text('Save finding'),
            ),
          ],
        ),
      ),
    );
    notes.dispose();
    return result;
  }

  Future<void> _saveDraft() async {
    setState(() => _saving = true);
    final result = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .saveDocumentReviewDraft(const SaveDocumentReviewDraftCommand());
    if (!mounted) return;
    setState(() => _saving = false);
    _showMessage(
      result == SaveDocumentReviewDraftResult.success
          ? 'Draft saved.'
          : 'Draft could not be saved.',
    );
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final result = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .submitDocumentReview(const SubmitDocumentReviewCommand());
    if (!mounted) return;
    setState(() => _saving = false);
    if (result == SubmitDocumentReviewResult.success) {
      _showMessage('Review submitted. Receiving Dock unlocked.');
      widget.onBack();
    } else {
      _showMessage(
        result == SubmitDocumentReviewResult.noFindings
            ? 'Add at least one finding before submitting.'
            : 'The review could not be submitted.',
      );
    }
  }

  Future<void> _exit() async {
    await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordWorkplaceEvent(
          AttemptAuditEventType.documentDeskExited,
          screenId: 'document-desk',
        );
    if (mounted) widget.onBack();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

String _findingLabel(DocumentFindingType type) => switch (type) {
  DocumentFindingType.quantityMismatch => 'Quantity mismatch',
  DocumentFindingType.unexpectedItem => 'Unexpected item',
  DocumentFindingType.missingItem => 'Missing item',
  DocumentFindingType.documentMismatch => 'Document mismatch',
  DocumentFindingType.other => 'Other',
};

String _sourceLabel(DocumentSource source) => switch (source) {
  DocumentSource.purchaseOrder => 'Purchase order',
  DocumentSource.deliveryNote => 'Delivery note',
  DocumentSource.both => 'Both documents',
};
