import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/application/workplace_interaction_contracts.dart';
import 'package:candidate_mobile/features/workplace_simulation/application/workplace_simulation_controller.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/asset_simulation_content_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/local_simulation_attempt_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_enums.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Proves Processing is genuinely playable end to end through the real
/// repository and family-provider controller -- the same recordAction() and
/// completeMission() calls the four workstation screens make, driven
/// through real content resolution and real unlock-requirement gating,
/// rather than the bypass used in processing_content_test.dart.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a diligent Processing shift completes end to end and unlocks every '
      'workstation in sequence', () async {
    final missionId = WorkplaceSimulationController.processingMissionId;
    final container = ProviderContainer(
      overrides: [
        candidateSessionRepositoryProvider.overrideWithValue(
          InMemoryCandidateSessionRepository(
            session: const CandidateSession(
              candidateId: 'processing-playthrough-candidate',
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

    await container.read(
      workplaceSimulationControllerProvider(missionId).future,
    );
    final controller = container.read(
      workplaceSimulationControllerProvider(missionId).notifier,
    );

    expect(await controller.startMission(scenarioSeed: 63910), isNull);
    expect(await controller.setBriefingAcknowledged(true), isNull);
    expect(await controller.beginShift(), BeginShiftResult.success);

    expect(
      controller.workstationStatus('processing-entry'),
      WorkstationStatus.available,
    );
    expect(
      controller.workstationStatus('packing-station'),
      WorkstationStatus.locked,
    );

    final scenario = container
        .read(workplaceSimulationControllerProvider(missionId))
        .requireValue
        .scenario!;
    final hygieneChecklist = scenario.resource('hygiene-checklist');
    final hygieneGap = hygieneChecklist.issues.any(
      (issue) => issue.issueType == 'hygiene_missed',
    );
    final batches =
        scenario.resources
            .where((item) => item.resourceType.name == 'carton')
            .toList()
          ..sort((left, right) => left.id.compareTo(right.id));

    expect(
      await controller.recordAction(
        stageId: 'hygiene-and-scan',
        taskId: 'confirm-hygiene-compliance',
        actionType: ActionType.confirmAction,
        targetId: 'hygiene-checklist',
        payload: {'compliant': !hygieneGap},
      ),
      isNull,
    );
    for (final batch in batches) {
      expect(
        await controller.recordAction(
          stageId: 'hygiene-and-scan',
          taskId: 'scan-processing-batches',
          actionType: ActionType.scanBarcode,
          targetId: batch.id,
          payload: const {'scanStatus': 'matched'},
        ),
        isNull,
      );
    }

    expect(
      controller.workstationStatus('packing-station'),
      WorkstationStatus.available,
    );
    expect(
      controller.workstationStatus('quality-check'),
      WorkstationStatus.locked,
    );

    for (final batch in batches) {
      expect(
        await controller.recordAction(
          stageId: 'packing',
          taskId: 'pack-batch-items',
          actionType: ActionType.moveItem,
          targetId: batch.id,
          payload: const {'packed': true},
        ),
        isNull,
      );
    }
    for (final batch in batches) {
      expect(
        await controller.recordAction(
          stageId: 'packing',
          taskId: 'record-batch-weight',
          actionType: ActionType.recordWeight,
          targetId: batch.id,
          payload: {'recordedWeightKg': batch.content['packedWeightKg']},
        ),
        isNull,
      );
    }

    expect(
      controller.workstationStatus('quality-check'),
      WorkstationStatus.available,
    );
    expect(
      controller.workstationStatus('processing-office'),
      WorkstationStatus.locked,
    );

    for (final batch in batches) {
      expect(
        await controller.recordAction(
          stageId: 'quality-and-sample',
          taskId: 'verify-batch-labels',
          actionType: ActionType.inspectItem,
          targetId: batch.id,
          payload: const {'labelVerified': true},
        ),
        isNull,
      );
    }
    expect(
      await controller.recordAction(
        stageId: 'quality-and-sample',
        taskId: 'supervisor-sample-check',
        actionType: ActionType.confirmAction,
        targetId: 'supervisor-sample',
        payload: const {'sampleReviewed': true},
      ),
      isNull,
    );

    expect(
      controller.workstationStatus('processing-office'),
      WorkstationStatus.available,
    );

    for (final batch in batches) {
      final disposition = batch.issues.isEmpty
          ? 'accept'
          : 'hold_for_verification';
      expect(
        await controller.recordAction(
          stageId: 'processing-decision',
          taskId: 'classify-batch-exceptions',
          actionType: ActionType.selectDisposition,
          targetId: batch.id,
          payload: {
            'disposition': disposition,
            if (disposition != 'accept') 'reason': 'Batch exception flagged',
          },
        ),
        isNull,
      );
    }

    expect(
      await controller.recordAction(
        stageId: 'processing-decision',
        taskId: 'complete-processing-report',
        actionType: ActionType.completeForm,
        targetId: 'processing-report',
        payload: const {
          'allBatchesProcessed': true,
          'exceptionsRecorded': true,
        },
      ),
      isNull,
    );
    expect(
      await controller.recordAction(
        stageId: 'processing-decision',
        taskId: 'make-processing-decision',
        actionType: ActionType.makeDecision,
        targetId: 'processing-report',
        payload: const {'decision': 'processing_complete'},
      ),
      isNull,
    );
    expect(
      await controller.recordAction(
        stageId: 'processing-decision',
        taskId: 'notify-supervisor',
        actionType: ActionType.confirmAction,
        targetId: 'supervisor-notification',
        payload: const {'supervisorNotified': true, 'exceptionsIncluded': true},
      ),
      isNull,
    );

    final completion = await controller.completeMission(
      screenId: 'processing-office',
    );
    expect(completion, CompleteMissionResult.success);

    final finalState = container
        .read(workplaceSimulationControllerProvider(missionId))
        .requireValue;
    expect(finalState.attempt!.state, MissionState.completed);
    expect(finalState.result, isNotNull);
    expect(finalState.result!.status, MissionStatus.passed);
    expect(finalState.result!.mandatoryTasksCompleted, isTrue);
    expect(finalState.result!.criticalErrors, isEmpty);
  });
}
