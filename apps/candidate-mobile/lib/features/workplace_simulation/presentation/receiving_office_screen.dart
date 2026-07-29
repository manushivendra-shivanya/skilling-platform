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

class ReceivingOfficeScreen extends ConsumerStatefulWidget {
  const ReceivingOfficeScreen({
    required this.missionId,
    required this.onBack,
    required this.onMissionComplete,
    super.key,
  });

  final String missionId;
  final VoidCallback onBack;
  final VoidCallback onMissionComplete;

  @override
  ConsumerState<ReceivingOfficeScreen> createState() =>
      _ReceivingOfficeScreenState();
}

class _ReceivingOfficeScreenState extends ConsumerState<ReceivingOfficeScreen> {
  bool _saving = false;
  bool _tracked = false;
  bool _shortage = false;
  bool _unauthorizedSku = false;
  bool _damage = false;
  bool _barcodeIssue = false;
  bool _nearExpiry = false;
  bool _flagsInitialized = false;

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
        title: const Text('Receiving Office'),
      ),
      body: SafeArea(
        child: simulation.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AppErrorState(
            title: 'Receiving Office unavailable',
            message: 'Your saved draft is safe. Retry loading the shift.',
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
                .firstWhere((item) => item.workstationId == 'receiving-office');
            if (value.mission.id != widget.missionId ||
                station.status == WorkstationStatus.locked) {
              return AppErrorState(
                title: 'Receiving Office is locked',
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
                      AttemptAuditEventType.receivingOfficeOpened,
                      screenId: 'receiving-office',
                    ),
              );
            }
            final draft = value.attempt?.discrepancyReportDraft;
            if (!_flagsInitialized && draft != null) {
              _flagsInitialized = true;
              _shortage = draft.shortageRecorded;
              _unauthorizedSku = draft.unauthorizedSkuRecorded;
              _damage = draft.damageRecorded;
              _barcodeIssue = draft.barcodeIssueRecorded;
              _nearExpiry = draft.nearExpiryRecorded;
            }
            final reportSubmitted =
                draft?.status == OperationalDraftStatus.submitted;
            final decision = controller.selectedReceivingDecision;
            final supervisorNotified = controller.supervisorNotified;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Discrepancy report',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'PO ${value.mission.briefing.purchaseOrderNumber} — record every discrepancy you identified this shift.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _shortage,
                              title: const Text('Quantity shortage recorded'),
                              onChanged: reportSubmitted || _saving
                                  ? null
                                  : (v) =>
                                        setState(() => _shortage = v ?? false),
                            ),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _unauthorizedSku,
                              title: const Text('Unauthorized SKU recorded'),
                              onChanged: reportSubmitted || _saving
                                  ? null
                                  : (v) => setState(
                                      () => _unauthorizedSku = v ?? false,
                                    ),
                            ),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _damage,
                              title: const Text('Packaging damage recorded'),
                              onChanged: reportSubmitted || _saving
                                  ? null
                                  : (v) => setState(() => _damage = v ?? false),
                            ),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _barcodeIssue,
                              title: const Text('Barcode issue recorded'),
                              onChanged: reportSubmitted || _saving
                                  ? null
                                  : (v) => setState(
                                      () => _barcodeIssue = v ?? false,
                                    ),
                            ),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _nearExpiry,
                              title: const Text('Near-expiry stock recorded'),
                              onChanged: reportSubmitted || _saving
                                  ? null
                                  : (v) => setState(
                                      () => _nearExpiry = v ?? false,
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (!reportSubmitted)
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            AppButton(
                              label: 'Save draft',
                              variant: AppButtonVariant.secondary,
                              expand: false,
                              isLoading: _saving,
                              onPressed: _saving ? null : _saveFlags,
                            ),
                            AppButton(
                              label: 'Submit report',
                              expand: false,
                              isLoading: _saving,
                              onPressed: _saving ? null : _submitReport,
                            ),
                          ],
                        )
                      else
                        const Text('Discrepancy report submitted.'),
                      if (reportSubmitted) ...[
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          'Receiving decision',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        const Text(
                          'Choose the outcome consistent with the dispositions already assigned in the Quarantine Zone.',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (decision == null)
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              for (final option
                                  in ReceivingDecisionOutcome.values)
                                AppButton(
                                  label: _decisionLabel(option),
                                  variant: AppButtonVariant.secondary,
                                  expand: false,
                                  isLoading: _saving,
                                  onPressed: _saving
                                      ? null
                                      : () => _selectDecision(option),
                                ),
                            ],
                          )
                        else
                          Text('Decision: ${_decisionLabel(decision)}'),
                      ],
                      if (decision != null) ...[
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          'Shift report',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        const Text(
                          'Notify the Receiving Supervisor with the facts, actions taken and outstanding risk, including the audit trail.',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppButton(
                          label: supervisorNotified
                              ? 'Supervisor notified'
                              : 'Notify supervisor',
                          expand: false,
                          isLoading: _saving,
                          onPressed: supervisorNotified || _saving
                              ? null
                              : _notifySupervisor,
                        ),
                      ],
                      if (supervisorNotified) ...[
                        const SizedBox(height: AppSpacing.xl),
                        AppButton(
                          label: 'Complete shift',
                          isLoading: _saving,
                          onPressed: _saving ? null : _completeMission,
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

  Future<void> _saveFlags() async {
    setState(() => _saving = true);
    final result = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .setDiscrepancyReportFlags(
          SetDiscrepancyReportFlagsCommand(
            shortageRecorded: _shortage,
            unauthorizedSkuRecorded: _unauthorizedSku,
            damageRecorded: _damage,
            barcodeIssueRecorded: _barcodeIssue,
            nearExpiryRecorded: _nearExpiry,
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    _showMessage(
      result == SetDiscrepancyReportFlagsResult.success
          ? 'Draft saved.'
          : 'Draft could not be saved.',
    );
  }

  Future<void> _submitReport() async {
    setState(() => _saving = true);
    final controller = ref.read(
      workplaceSimulationControllerProvider(widget.missionId).notifier,
    );
    final flagsResult = await controller.setDiscrepancyReportFlags(
      SetDiscrepancyReportFlagsCommand(
        shortageRecorded: _shortage,
        unauthorizedSkuRecorded: _unauthorizedSku,
        damageRecorded: _damage,
        barcodeIssueRecorded: _barcodeIssue,
        nearExpiryRecorded: _nearExpiry,
      ),
    );
    if (flagsResult != SetDiscrepancyReportFlagsResult.success) {
      if (mounted) {
        setState(() => _saving = false);
        _showMessage('The report could not be saved.');
      }
      return;
    }
    final result = await controller.submitDiscrepancyReport(
      const SubmitDiscrepancyReportCommand(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    _showMessage(
      result == SubmitDiscrepancyReportResult.success
          ? 'Discrepancy report submitted.'
          : 'The report could not be submitted.',
    );
  }

  Future<void> _selectDecision(ReceivingDecisionOutcome decision) async {
    setState(() => _saving = true);
    final result = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .selectReceivingDecision(SelectReceivingDecisionCommand(decision));
    if (!mounted) return;
    setState(() => _saving = false);
    if (result != SelectReceivingDecisionResult.success) {
      _showMessage('The decision could not be recorded.');
    }
  }

  Future<void> _notifySupervisor() async {
    setState(() => _saving = true);
    final result = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .notifySupervisor(const NotifySupervisorCommand());
    if (!mounted) return;
    setState(() => _saving = false);
    if (result != NotifySupervisorResult.success) {
      _showMessage('The supervisor could not be notified.');
    }
  }

  Future<void> _completeMission() async {
    setState(() => _saving = true);
    final result = await ref
        .read(workplaceSimulationControllerProvider(widget.missionId).notifier)
        .completeMission();
    if (!mounted) return;
    setState(() => _saving = false);
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
          AttemptAuditEventType.receivingOfficeExited,
          screenId: 'receiving-office',
        );
    if (mounted) widget.onBack();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

String _decisionLabel(ReceivingDecisionOutcome decision) => switch (decision) {
  ReceivingDecisionOutcome.accept => 'Accept shipment',
  ReceivingDecisionOutcome.partiallyAccept => 'Partially accept',
  ReceivingDecisionOutcome.reject => 'Reject shipment',
};
