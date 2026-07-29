import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/application/workplace_interaction_contracts.dart';
import 'package:candidate_mobile/features/workplace_simulation/application/workplace_simulation_controller.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/asset_simulation_content_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/local_simulation_attempt_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_enums.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Proves Put Away is genuinely playable end to end through the real
/// repository and family-provider controller -- the same recordAction() and
/// completeMission() calls the four workstation screens make, driven
/// through real content resolution and real unlock-requirement gating,
/// rather than the bypass used in put_away_content_test.dart.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a diligent Put Away shift completes end to end and unlocks every '
      'workstation in sequence', () async {
    final missionId = WorkplaceSimulationController.putAwayMissionId;
    final container = ProviderContainer(
      overrides: [
        candidateSessionRepositoryProvider.overrideWithValue(
          InMemoryCandidateSessionRepository(
            session: const CandidateSession(
              candidateId: 'put-away-playthrough-candidate',
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

    expect(await controller.startMission(scenarioSeed: 71204), isNull);
    expect(await controller.setBriefingAcknowledged(true), isNull);
    expect(await controller.beginShift(), BeginShiftResult.success);

    expect(
      controller.workstationStatus('staging-area'),
      WorkstationStatus.available,
    );
    expect(
      controller.workstationStatus('location-planning'),
      WorkstationStatus.locked,
    );

    expect(
      await controller.recordAction(
        stageId: 'review-putaway-list',
        taskId: 'open-putaway-list',
        actionType: ActionType.openResource,
        targetId: 'putaway-task-list',
      ),
      isNull,
    );

    expect(
      controller.workstationStatus('location-planning'),
      WorkstationStatus.available,
    );
    expect(
      controller.workstationStatus('transport-placement'),
      WorkstationStatus.locked,
    );

    final scenario = container
        .read(workplaceSimulationControllerProvider(missionId))
        .requireValue
        .scenario!;
    final items =
        scenario.resources
            .where((item) => item.resourceType.name == 'carton')
            .toList()
          ..sort((left, right) => left.id.compareTo(right.id));

    String zoneFor(String? issue) => switch (issue) {
      'hazmat_item' => 'hazmat-locker',
      'cold_chain_item' => 'cold-storage-unit',
      'high_value_item' => 'secure-cage',
      'zone_at_capacity' => 'overflow-storage',
      _ => 'standard-shelving',
    };

    for (final item in items) {
      final issue = item.issues.isEmpty ? null : item.issues.single.issueType;
      expect(
        await controller.recordAction(
          stageId: 'plan-locations',
          taskId: 'assign-storage-zone',
          actionType: ActionType.classifyIssue,
          targetId: item.id,
          payload: {'selectedZone': zoneFor(issue)},
        ),
        isNull,
      );
      if (issue == 'zone_at_capacity') {
        expect(
          await controller.recordAction(
            stageId: 'plan-locations',
            taskId: 'record-location-exception',
            actionType: ActionType.classifyIssue,
            targetId: item.id,
            payload: const {'exceptionType': 'zone_at_capacity'},
          ),
          isNull,
        );
      }
    }

    expect(
      controller.workstationStatus('transport-placement'),
      WorkstationStatus.available,
    );
    expect(
      controller.workstationStatus('putaway-office'),
      WorkstationStatus.locked,
    );

    for (final item in items) {
      expect(
        await controller.recordAction(
          stageId: 'transport-and-place',
          taskId: 'transport-and-place-items',
          actionType: ActionType.moveItem,
          targetId: item.id,
          payload: const {'placed': true, 'safeHandlingConfirmed': true},
        ),
        isNull,
      );
    }
    for (final item in items) {
      expect(
        await controller.recordAction(
          stageId: 'transport-and-place',
          taskId: 'scan-items-to-bins',
          actionType: ActionType.scanBarcode,
          targetId: item.id,
          payload: const {'scanStatus': 'matched'},
        ),
        isNull,
      );
    }
    for (final item in items) {
      expect(
        await controller.recordAction(
          stageId: 'transport-and-place',
          taskId: 'confirm-quantities-placed',
          actionType: ActionType.countQuantity,
          targetId: item.id,
          payload: {'placedQuantity': item.content['quantity']},
        ),
        isNull,
      );
    }

    expect(
      controller.workstationStatus('putaway-office'),
      WorkstationStatus.available,
    );

    expect(
      await controller.recordAction(
        stageId: 'putaway-decision',
        taskId: 'complete-putaway-report',
        actionType: ActionType.completeForm,
        targetId: 'putaway-report',
        payload: const {'allItemsPlaced': true, 'exceptionsRecorded': true},
      ),
      isNull,
    );
    expect(
      await controller.recordAction(
        stageId: 'putaway-decision',
        taskId: 'make-putaway-decision',
        actionType: ActionType.makeDecision,
        targetId: 'putaway-report',
        payload: const {'decision': 'putaway_complete'},
      ),
      isNull,
    );
    expect(
      await controller.recordAction(
        stageId: 'putaway-decision',
        taskId: 'notify-supervisor',
        actionType: ActionType.confirmAction,
        targetId: 'supervisor-notification',
        payload: const {'supervisorNotified': true, 'exceptionsIncluded': true},
      ),
      isNull,
    );

    final completion = await controller.completeMission(
      screenId: 'putaway-office',
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
