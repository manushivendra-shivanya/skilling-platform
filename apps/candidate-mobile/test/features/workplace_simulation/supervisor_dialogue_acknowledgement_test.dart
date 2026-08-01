import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/app/theme/app_theme.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/application/workplace_interaction_contracts.dart';
import 'package:candidate_mobile/features/workplace_simulation/application/workplace_simulation_controller.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/asset_simulation_content_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/local_simulation_attempt_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_enums.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/workplace_task_drafts.dart';
import 'package:candidate_mobile/features/workplace_simulation/presentation/receiving_office_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Proves the NPC supervisor's `supervisor_notified` acknowledgement line
/// shipped in the content-deepening pass is shown once the candidate
/// actually notifies the supervisor on Receiving Office.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Receiving Office shows the supervisor acknowledging the shift report '
    'once notified',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = await _activeContainer();
      addTearDown(container.dispose);
      await _completeDocumentAndCountStages(container);
      await _completeInspectionAndQuarantineStages(container);
      final controller = container.read(
        workplaceSimulationControllerProvider(
          WorkplaceSimulationController.missionId,
        ).notifier,
      );
      expect(
        await controller.setDiscrepancyReportFlags(
          const SetDiscrepancyReportFlagsCommand(
            shortageRecorded: true,
            unauthorizedSkuRecorded: true,
            damageRecorded: true,
            barcodeIssueRecorded: true,
            nearExpiryRecorded: true,
          ),
        ),
        SetDiscrepancyReportFlagsResult.success,
      );
      expect(
        await controller.submitDiscrepancyReport(
          const SubmitDiscrepancyReportCommand(),
        ),
        SubmitDiscrepancyReportResult.success,
      );
      expect(
        await controller.selectReceivingDecision(
          const SelectReceivingDecisionCommand(
            ReceivingDecisionOutcome.partiallyAccept,
          ),
        ),
        SelectReceivingDecisionResult.success,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: ReceivingOfficeScreen(
              missionId: WorkplaceSimulationController.missionId,
              onBack: () {},
              onMissionComplete: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Notify supervisor'));
      await tester.pumpAndSettle();

      expect(find.textContaining("I've got the audit trail"), findsOneWidget);
    },
  );
}

Future<ProviderContainer> _activeContainer() async {
  final container = ProviderContainer(
    overrides: [
      candidateSessionRepositoryProvider.overrideWithValue(
        InMemoryCandidateSessionRepository(
          session: const CandidateSession(
            candidateId: 'supervisor-acknowledgement-candidate',
            isAuthenticated: true,
          ),
        ),
      ),
      simulationContentRepositoryProvider.overrideWithValue(
        AssetSimulationContentRepository(),
      ),
      simulationAttemptRepositoryProvider.overrideWithValue(
        InMemorySimulationAttemptRepository(),
      ),
    ],
  );
  await container.read(
    workplaceSimulationControllerProvider(
      WorkplaceSimulationController.missionId,
    ).future,
  );
  final controller = container.read(
    workplaceSimulationControllerProvider(
      WorkplaceSimulationController.missionId,
    ).notifier,
  );
  await controller.startMission(scenarioSeed: 48127);
  await controller.setBriefingAcknowledged(true);
  final result = await controller.beginShift();
  if (result != BeginShiftResult.success) {
    container.dispose();
    throw StateError('Could not prepare active WMS test attempt: $result');
  }
  return container;
}

/// Drives document review and receiving count to completion, unlocking
/// Inspection Zone. Mirrors the sequence proven in
/// workplace_simulation_controller_test.dart.
Future<void> _completeDocumentAndCountStages(
  ProviderContainer container,
) async {
  final controller = container.read(
    workplaceSimulationControllerProvider(
      WorkplaceSimulationController.missionId,
    ).notifier,
  );
  await controller.addDocumentFinding(
    const AddDocumentFindingCommand(
      sourceDocument: DocumentSource.both,
      itemReference: 'SKU-1001',
      findingType: DocumentFindingType.other,
    ),
  );
  await controller.submitDocumentReview(const SubmitDocumentReviewCommand());
  await controller.confirmShipmentIdentity(
    const ConfirmShipmentIdentityCommand(confirmed: true),
  );
  final state = container
      .read(
        workplaceSimulationControllerProvider(
          WorkplaceSimulationController.missionId,
        ),
      )
      .requireValue;
  for (final cartonId
      in state.mission.task('confirm-received-counts').targetResourceIds) {
    await controller.recordCartonCount(
      RecordCartonCountCommand(
        cartonId: cartonId,
        enteredQuantity: 0,
        countMethod: CountMethod.individual,
      ),
    );
  }
  await controller.submitReceivingCount(const SubmitReceivingCountCommand());
}

/// Drives inspection, barcode scanning, dispositions and quarantine
/// confirmation to completion, unlocking Receiving Office.
Future<void> _completeInspectionAndQuarantineStages(
  ProviderContainer container,
) async {
  final controller = container.read(
    workplaceSimulationControllerProvider(
      WorkplaceSimulationController.missionId,
    ).notifier,
  );
  final state = container
      .read(
        workplaceSimulationControllerProvider(
          WorkplaceSimulationController.missionId,
        ),
      )
      .requireValue;
  for (final cartonId
      in state.mission.task('inspect-cartons').targetResourceIds) {
    await controller.recordCartonInspection(
      RecordCartonInspectionCommand(
        cartonId: cartonId,
        findings: const [CartonFinding.compliant],
      ),
    );
  }
  for (final cartonId
      in state.mission.task('scan-barcodes').targetResourceIds) {
    await controller.recordBarcodeScan(
      RecordBarcodeScanCommand(
        cartonId: cartonId,
        status: BarcodeStatus.readable,
      ),
    );
  }
  await controller.submitInspection(const SubmitInspectionCommand());

  const dispositions = {
    'carton-001': DispositionType.holdForVerification,
    'carton-002': DispositionType.holdForVerification,
    'carton-003': DispositionType.rejectReturn,
    'carton-004': DispositionType.accept,
    'carton-005': DispositionType.escalate,
    'carton-006': DispositionType.quarantine,
  };
  for (final entry in dispositions.entries) {
    await controller.recordDisposition(
      RecordDispositionCommand(
        cartonId: entry.key,
        disposition: entry.value,
        reason: entry.value == DispositionType.accept
            ? ''
            : 'Matches inspection finding',
      ),
    );
  }
  await controller.submitDispositions(const SubmitDispositionsCommand());
  await controller.confirmQuarantine(const ConfirmQuarantineCommand());

  const releaseDecisions = {
    'carton-001': ReleaseDecision.continueHold,
    'carton-002': ReleaseDecision.continueHold,
    'carton-006': ReleaseDecision.returnToSupplier,
  };
  for (final entry in releaseDecisions.entries) {
    await controller.recordReleaseDecision(
      RecordReleaseDecisionCommand(
        cartonId: entry.key,
        decision: entry.value,
        justification: 'Matches disposition finding',
      ),
    );
  }
  await controller.submitQuarantineRelease(
    const SubmitQuarantineReleaseCommand(),
  );
}
