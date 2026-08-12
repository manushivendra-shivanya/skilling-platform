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
import '../domain/simulation_content.dart';
import '../domain/simulation_enums.dart';
import '../domain/workplace_task_drafts.dart';
import 'widgets/supervisor_dialogue.dart';

/// A carton fails its scan whenever the scenario has assigned it an
/// unreadable-barcode issue -- a real scanner is a mechanical device, not a
/// judgment call, so the outcome is deterministic rather than a candidate
/// choice. What the candidate is actually assessed on is how they respond
/// to a failed scan (retry, manual override, or escalate), not whether they
/// can predict the outcome.
const _maxRetries = 2;

class BarcodeStationScreen extends ConsumerStatefulWidget {
  const BarcodeStationScreen({
    required this.missionId,
    required this.onBack,
    required this.onOpenQuarantineZone,
    super.key,
  });

  final String missionId;
  final VoidCallback onBack;
  final VoidCallback onOpenQuarantineZone;

  @override
  ConsumerState<BarcodeStationScreen> createState() =>
      _BarcodeStationScreenState();
}

class _BarcodeStationScreenState extends ConsumerState<BarcodeStationScreen> {
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
        title: const Text('Barcode Station'),
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
          loading: () => const Center(
            child: AppLoadingProgressBar(label: 'Loading your progress…'),
          ),
          error: (_, _) => AppErrorState(
            title: 'Barcode Station unavailable',
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
                .firstWhere((item) => item.workstationId == 'barcode-station');
            if (value.mission.id != widget.missionId ||
                station.status == WorkstationStatus.locked) {
              return AppErrorState(
                title: 'Barcode Station is locked',
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
                      AttemptAuditEventType.barcodeStationOpened,
                      screenId: 'barcode-station',
                    ),
              );
            }
            final cartons =
                scenario.resources
                    .where((item) => item.resourceType.name == 'carton')
                    .toList()
                  ..sort((left, right) => left.id.compareTo(right.id));
            final draft = value.attempt?.barcodeScanDraft;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan every carton',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Every carton passes under the scanner once. If a '
                        'scan fails, resolve it before moving on -- unreadable '
                        'barcodes require hold or escalation.',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      for (final carton in cartons) ...[
                        Builder(
                          builder: (context) {
                            BarcodeScanEntry? entry;
                            for (final item
                                in draft?.entries ??
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
                                          Text(_summaryLabel(entry)),
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
                                  AppButton(
                                    // Bare Row child alongside an Expanded
                                    // sibling -- see quarantine_zone
                                    // _screen.dart's identical fix.
                                    expand: false,
                                    variant: AppButtonVariant.secondary,
                                    label: entry == null ? 'Scan' : 'Edit',
                                    onPressed: _saving
                                        ? null
                                        : () => _scanCarton(carton, entry),
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
                            '${cartons.length} cartons scanned',
                        child: Text(
                          'Scan progress: ${draft?.entries.length ?? 0} of '
                          '${cartons.length} cartons scanned',
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
                            label: 'Submit scans',
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

  Future<void> _scanCarton(
    SimulationResource carton,
    BarcodeScanEntry? existing,
  ) async {
    final result = await _showScanFlow(carton, existing);
    if (result == null) return;
    final controller = ref.read(
      workplaceSimulationControllerProvider(widget.missionId).notifier,
    );
    if (existing == null) {
      final commandResult = await controller.recordBarcodeScan(
        RecordBarcodeScanCommand(
          cartonId: carton.id,
          status: result.status,
          resolutionMethod: result.resolutionMethod,
          manualCode: result.manualCode,
        ),
      );
      if (mounted && commandResult != RecordBarcodeScanResult.success) {
        _showMessage('The scan could not be recorded.');
      }
    } else {
      final commandResult = await controller.updateBarcodeScan(
        UpdateBarcodeScanCommand(
          entryId: existing.id,
          status: result.status,
          scanAttempts: result.scanAttempts,
          resolutionMethod: result.resolutionMethod,
          manualCode: result.manualCode,
        ),
      );
      if (mounted && commandResult != UpdateBarcodeScanResult.success) {
        _showMessage('The scan could not be updated.');
      }
    }
  }

  /// Runs the whole scan-and-resolve flow inside one dialog session: scan,
  /// then (only if the scan failed) retry / manual entry / flag. Returns
  /// null if the candidate cancels before reaching a resolved state.
  Future<_ScanOutcome?> _showScanFlow(
    SimulationResource carton,
    BarcodeScanEntry? existing,
  ) async {
    final truthUnreadable = carton.issues.any(
      (issue) => issue.issueType == 'unreadable_barcode',
    );
    var status = existing?.status;
    var attempts = existing?.scanAttempts ?? 0;
    var resolutionMethod = existing?.resolutionMethod;
    var manualCode = existing?.manualCode;
    final manualCodeController = TextEditingController(text: manualCode);

    final result = await showDialog<_ScanOutcome>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void scan() {
            setDialogState(() {
              attempts += 1;
              status = truthUnreadable
                  ? BarcodeStatus.unreadable
                  : BarcodeStatus.readable;
              resolutionMethod = truthUnreadable
                  ? null
                  : BarcodeResolutionMethod.scanned;
            });
          }

          final unresolved =
              status == BarcodeStatus.unreadable && resolutionMethod == null;
          return AlertDialog(
            title: Text(existing == null ? 'Scan barcode' : 'Edit scan'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (status == null) ...[
                    Text('${carton.title} -- ${carton.content['sku']}'),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: 'Scan',
                      onPressed: scan,
                      leadingIcon: Icons.qr_code_scanner,
                    ),
                  ] else if (status == BarcodeStatus.readable) ...[
                    const Text('Barcode read successfully.'),
                  ] else ...[
                    Text(
                      'Scan failed -- barcode unreadable '
                      '(attempt $attempts of ${_maxRetries + 1}).',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (unresolved) ...[
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          if (attempts <= _maxRetries)
                            AppButton(
                              // Same expand: false as the Save
                              // draft/Submit scans pair above -- these
                              // sit side by side in a Wrap, not filling
                              // its full width each.
                              expand: false,
                              variant: AppButtonVariant.secondary,
                              label: 'Retry scan',
                              onPressed: scan,
                            ),
                          AppButton(
                            expand: false,
                            variant: AppButtonVariant.secondary,
                            label: 'Enter barcode manually',
                            onPressed: () => setDialogState(
                              () => resolutionMethod =
                                  BarcodeResolutionMethod.manualEntry,
                            ),
                          ),
                          AppButton(
                            expand: false,
                            variant: AppButtonVariant.secondary,
                            label: 'Flag for verification',
                            onPressed: () => setDialogState(
                              () => resolutionMethod =
                                  BarcodeResolutionMethod.flagged,
                            ),
                          ),
                        ],
                      ),
                    ] else if (resolutionMethod ==
                        BarcodeResolutionMethod.manualEntry) ...[
                      TextField(
                        controller: manualCodeController,
                        decoration: const InputDecoration(
                          labelText: 'Barcode value',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const Text(
                        'Recorded as unreadable with a manual override -- '
                        'still requires hold or escalation.',
                      ),
                    ] else if (resolutionMethod ==
                        BarcodeResolutionMethod.flagged) ...[
                      const Text('Flagged unreadable for manual verification.'),
                    ],
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed:
                    status == null ||
                        (unresolved) ||
                        (resolutionMethod ==
                                BarcodeResolutionMethod.manualEntry &&
                            manualCodeController.text.trim().isEmpty)
                    ? null
                    : () => Navigator.pop(
                        context,
                        _ScanOutcome(
                          status: status!,
                          scanAttempts: attempts,
                          resolutionMethod:
                              resolutionMethod ??
                              BarcodeResolutionMethod.scanned,
                          manualCode:
                              resolutionMethod ==
                                  BarcodeResolutionMethod.manualEntry
                              ? manualCodeController.text.trim()
                              : null,
                        ),
                      ),
                child: const Text('Save scan'),
              ),
            ],
          );
        },
      ),
    );
    manualCodeController.dispose();
    return result;
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
        .saveBarcodeScanDraft(const SaveBarcodeScanDraftCommand());
    if (!mounted) return;
    setState(() => _saving = false);
    _showMessage(
      result == SaveBarcodeScanDraftResult.success
          ? 'Draft saved.'
          : 'Draft could not be saved.',
    );
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final result = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .submitBarcodeScan(const SubmitBarcodeScanCommand());
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case SubmitBarcodeScanResult.success:
        _showMessage('Scans submitted. Quarantine Zone unlocked.');
        widget.onOpenQuarantineZone();
      case SubmitBarcodeScanResult.incompleteScans:
        _showMessage('Scan every carton before submitting.');
      default:
        _showMessage('The scans could not be submitted.');
    }
  }

  Future<void> _exit() async {
    await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .recordWorkplaceEvent(
          AttemptAuditEventType.barcodeStationExited,
          screenId: 'barcode-station',
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

class _ScanOutcome {
  const _ScanOutcome({
    required this.status,
    required this.scanAttempts,
    required this.resolutionMethod,
    this.manualCode,
  });

  final BarcodeStatus status;
  final int scanAttempts;
  final BarcodeResolutionMethod resolutionMethod;
  final String? manualCode;
}

String _summaryLabel(BarcodeScanEntry entry) {
  if (entry.status == BarcodeStatus.readable) return 'Readable';
  return switch (entry.resolutionMethod) {
    BarcodeResolutionMethod.manualEntry =>
      'Unreadable -- manual entry (${entry.manualCode ?? ''})',
    BarcodeResolutionMethod.flagged => 'Unreadable -- flagged for verification',
    BarcodeResolutionMethod.scanned => 'Unreadable',
  };
}
