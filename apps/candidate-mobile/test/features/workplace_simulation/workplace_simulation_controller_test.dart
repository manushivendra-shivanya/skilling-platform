import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/application/workplace_interaction_contracts.dart';
import 'package:candidate_mobile/features/workplace_simulation/application/workplace_simulation_controller.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/asset_simulation_content_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/local_simulation_attempt_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_enums.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/workplace_task_drafts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'controller starts, pauses, resumes and retries a fresh attempt',
    () async {
      var tick = 0;
      final attempts = InMemorySimulationAttemptRepository(
        clock: () =>
            DateTime.utc(2026, 7, 28).add(Duration(microseconds: tick++)),
      );
      final container = ProviderContainer(
        overrides: [
          candidateSessionRepositoryProvider.overrideWithValue(
            InMemoryCandidateSessionRepository(
              session: const CandidateSession(
                candidateId: 'controller-candidate',
                isAuthenticated: true,
              ),
            ),
          ),
          simulationContentRepositoryProvider.overrideWithValue(
            AssetSimulationContentRepository(),
          ),
          simulationAttemptRepositoryProvider.overrideWithValue(attempts),
        ],
      );
      addTearDown(container.dispose);

      final initial = await container.read(
        workplaceSimulationControllerProvider.future,
      );
      expect(initial.attempt, isNull);

      final controller = container.read(
        workplaceSimulationControllerProvider.notifier,
      );
      expect(await controller.startMission(scenarioSeed: 48127), isNull);
      var state = container
          .read(workplaceSimulationControllerProvider)
          .requireValue;
      expect(state.attempt!.state, MissionState.briefing);
      expect(state.attempt!.timerStatus, SimulationTimerStatus.notStarted);
      expect(state.attempt!.shiftStartedAt, isNull);
      final firstAttemptId = state.attempt!.id;

      expect(await controller.setBriefingAcknowledged(true), isNull);
      state = container
          .read(workplaceSimulationControllerProvider)
          .requireValue;
      expect(state.attempt!.briefingAcknowledgedAt, isNotNull);
      expect(state.attempt!.shiftStartedAt, isNull);
      final shiftStart = DateTime.utc(2026, 7, 28, 10);
      expect(
        await controller.beginShift(at: shiftStart),
        BeginShiftResult.success,
      );
      state = container
          .read(workplaceSimulationControllerProvider)
          .requireValue;
      expect(state.attempt!.shiftStartedAt, isNotNull);
      expect(state.attempt!.timerStatus, SimulationTimerStatus.running);
      expect(state.attempt!.currentStageId, 'document-verification');
      expect(
        state.attempt!.auditEvents.map((event) => event.type),
        containsAllInOrder([
          'attemptCreated',
          'briefingAcknowledged',
          'shiftStartRequested',
          'shiftStarted',
        ]),
      );
      final originalShiftStart = state.attempt!.shiftStartedAt;
      expect(
        await controller.beginShift(
          at: shiftStart.add(const Duration(days: 1)),
        ),
        BeginShiftResult.alreadyStarted,
      );
      expect(
        container
            .read(workplaceSimulationControllerProvider)
            .requireValue
            .attempt!
            .auditEvents
            .where(
              (event) => event.eventType == AttemptAuditEventType.shiftStarted,
            ),
        hasLength(1),
      );
      expect(
        container
            .read(workplaceSimulationControllerProvider)
            .requireValue
            .attempt!
            .shiftStartedAt,
        originalShiftStart,
      );
      expect(
        await controller.pauseAttempt(
          at: shiftStart.add(const Duration(seconds: 10)),
        ),
        isNull,
      );
      expect(
        container
            .read(workplaceSimulationControllerProvider)
            .requireValue
            .attempt!
            .state,
        MissionState.paused,
      );
      state = container
          .read(workplaceSimulationControllerProvider)
          .requireValue;
      expect(state.attempt!.elapsedSimulationSeconds, 10);
      expect(state.attempt!.timerStatus, SimulationTimerStatus.paused);
      expect(
        await controller.resumeAttempt(
          at: shiftStart.add(const Duration(seconds: 40)),
        ),
        isNull,
      );
      expect(
        container
            .read(workplaceSimulationControllerProvider)
            .requireValue
            .attempt!
            .state,
        MissionState.inProgress,
      );
      expect(
        await controller.pauseAttempt(
          at: shiftStart.add(const Duration(seconds: 50)),
        ),
        isNull,
      );
      state = container
          .read(workplaceSimulationControllerProvider)
          .requireValue;
      expect(state.attempt!.elapsedSimulationSeconds, 20);
      expect(state.attempt!.timerStatus, SimulationTimerStatus.paused);
      expect(
        await controller.resumeAttempt(
          at: shiftStart.add(const Duration(seconds: 60)),
        ),
        isNull,
      );

      expect(await controller.submit(), isNull);
      state = container
          .read(workplaceSimulationControllerProvider)
          .requireValue;
      expect(state.result!.status, MissionStatus.incomplete);
      expect(state.attempt!.state, MissionState.failed);
      expect(state.attempt!.timerStatus, SimulationTimerStatus.stopped);

      expect(await controller.retry(scenarioSeed: 90210), isNull);
      state = container
          .read(workplaceSimulationControllerProvider)
          .requireValue;
      expect(state.attempt!.id, isNot(firstAttemptId));
      expect(state.attempt!.attemptNumber, 2);
      expect(state.attempt!.scenarioSeed, 90210);
      expect(state.attempt!.state, MissionState.briefing);
      expect(state.result, isNull);
    },
  );

  test(
    'controller rejects actions before shift begins without corrupting state',
    () async {
      final container = ProviderContainer(
        overrides: [
          candidateSessionRepositoryProvider.overrideWithValue(
            InMemoryCandidateSessionRepository(
              session: const CandidateSession(
                candidateId: 'controller-candidate',
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
      addTearDown(container.dispose);
      await container.read(workplaceSimulationControllerProvider.future);
      final controller = container.read(
        workplaceSimulationControllerProvider.notifier,
      );
      await controller.startMission();

      final failure = await controller.recordAction(
        stageId: 'document-verification',
        taskId: 'open-purchase-order',
        actionType: ActionType.openResource,
        targetId: 'purchase-order-po-2026-001',
      );

      expect(failure, isNotNull);
      final state = container
          .read(workplaceSimulationControllerProvider)
          .requireValue;
      expect(state.attempt!.actions, isEmpty);
      expect(state.attempt!.state, MissionState.briefing);
    },
  );

  test(
    'begin shift returns a typed acknowledgement result without starting time',
    () async {
      final container = ProviderContainer(
        overrides: [
          candidateSessionRepositoryProvider.overrideWithValue(
            InMemoryCandidateSessionRepository(
              session: const CandidateSession(
                candidateId: 'unacknowledged-candidate',
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
      addTearDown(container.dispose);
      await container.read(workplaceSimulationControllerProvider.future);
      final controller = container.read(
        workplaceSimulationControllerProvider.notifier,
      );
      await controller.startMission(scenarioSeed: 48127);

      expect(
        await controller.beginShift(),
        BeginShiftResult.acknowledgementRequired,
      );
      final attempt = container
          .read(workplaceSimulationControllerProvider)
          .requireValue
          .attempt!;
      expect(attempt.state, MissionState.briefing);
      expect(attempt.timerStatus, SimulationTimerStatus.notStarted);
      expect(attempt.shiftStartedAt, isNull);
      expect(
        attempt.auditEvents.last.eventType,
        AttemptAuditEventType.shiftStartRejected,
      );
      expect(attempt.actions, isEmpty);
    },
  );

  test(
    'typed operational commands unlock stations independent of correctness',
    () async {
      final attempts = InMemorySimulationAttemptRepository();
      final container = ProviderContainer(
        overrides: [
          candidateSessionRepositoryProvider.overrideWithValue(
            InMemoryCandidateSessionRepository(
              session: const CandidateSession(
                candidateId: 'operations-candidate',
                isAuthenticated: true,
              ),
            ),
          ),
          simulationContentRepositoryProvider.overrideWithValue(
            AssetSimulationContentRepository(),
          ),
          simulationAttemptRepositoryProvider.overrideWithValue(attempts),
        ],
      );
      addTearDown(container.dispose);
      await container.read(workplaceSimulationControllerProvider.future);
      final controller = container.read(
        workplaceSimulationControllerProvider.notifier,
      );
      await controller.startMission(scenarioSeed: 48127);
      await controller.setBriefingAcknowledged(true);
      expect(await controller.beginShift(), BeginShiftResult.success);

      expect(
        controller.workstationStatus('document-desk'),
        WorkstationStatus.available,
      );
      expect(
        controller.workstationStatus('receiving-dock'),
        WorkstationStatus.locked,
      );
      expect(controller.recommendedWorkstationId, 'document-desk');
      expect(
        await controller.openWorkstation('receiving-dock'),
        OpenWorkstationResult.workstationLocked,
      );

      expect(
        await controller.addDocumentFinding(
          const AddDocumentFindingCommand(
            sourceDocument: DocumentSource.both,
            itemReference: 'SKU-1001',
            findingType: DocumentFindingType.other,
          ),
        ),
        AddDocumentFindingResult.success,
      );
      final finding = controller.documentReviewDraft!.findings.single;
      expect(
        await controller.updateDocumentFinding(
          UpdateDocumentFindingCommand(
            findingId: finding.id,
            sourceDocument: DocumentSource.both,
            itemReference: finding.itemReference,
            findingType: DocumentFindingType.documentMismatch,
          ),
        ),
        UpdateDocumentFindingResult.success,
      );
      expect(controller.documentReviewDraft!.findings.single.revisionNumber, 2);
      expect(
        await controller.submitDocumentReview(
          const SubmitDocumentReviewCommand(),
        ),
        SubmitDocumentReviewResult.success,
      );
      expect(
        controller.workstationStatus('document-desk'),
        WorkstationStatus.completed,
      );
      expect(
        controller.workstationStatus('receiving-dock'),
        WorkstationStatus.available,
      );
      expect(controller.recommendedWorkstationId, 'receiving-dock');
      expect(
        await controller.submitDocumentReview(
          const SubmitDocumentReviewCommand(),
        ),
        SubmitDocumentReviewResult.alreadySubmitted,
      );

      expect(
        await controller.confirmShipmentIdentity(
          const ConfirmShipmentIdentityCommand(confirmed: true),
        ),
        ConfirmShipmentIdentityResult.success,
      );
      final state = container
          .read(workplaceSimulationControllerProvider)
          .requireValue;
      for (final cartonId
          in state.mission.task('confirm-received-counts').targetResourceIds) {
        expect(
          await controller.recordCartonCount(
            RecordCartonCountCommand(
              cartonId: cartonId,
              enteredQuantity: 0,
              countMethod: CountMethod.individual,
            ),
          ),
          RecordCartonCountResult.success,
        );
      }
      final firstCount = controller.receivingCountDraft!.countEntries.first;
      expect(
        await controller.updateCartonCount(
          UpdateCartonCountCommand(
            entryId: firstCount.id,
            enteredQuantity: 1,
            countMethod: CountMethod.individual,
          ),
        ),
        UpdateCartonCountResult.success,
      );
      expect(
        controller.receivingCountDraft!.countEntries.first.revisionNumber,
        2,
      );
      expect(
        await controller.submitReceivingCount(
          const SubmitReceivingCountCommand(),
        ),
        SubmitReceivingCountResult.success,
      );
      expect(
        controller.workstationStatus('receiving-dock'),
        WorkstationStatus.completed,
      );
      expect(
        controller.workstationStatus('inspection-zone'),
        WorkstationStatus.available,
      );
      expect(controller.recommendedWorkstationId, 'inspection-zone');

      final completedAttempt = container
          .read(workplaceSimulationControllerProvider)
          .requireValue
          .attempt!;
      expect(
        completedAttempt.actions.map((action) => action.sequenceNumber),
        orderedEquals(
          List<int>.generate(
            completedAttempt.actions.length,
            (index) => index + 1,
          ),
        ),
      );
      expect(
        completedAttempt.auditEvents.map((event) => event.sequenceNumber),
        orderedEquals(
          List<int>.generate(
            completedAttempt.auditEvents.length,
            (index) => index + 1,
          ),
        ),
      );
    },
  );
}
