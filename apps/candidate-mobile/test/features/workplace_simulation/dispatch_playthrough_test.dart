import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/application/workplace_interaction_contracts.dart';
import 'package:candidate_mobile/features/workplace_simulation/application/workplace_simulation_controller.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/asset_simulation_content_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/local_simulation_attempt_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_enums.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Proves Dispatch is genuinely playable end to end through the real
/// repository and family-provider controller -- the same recordAction() and
/// completeMission() calls the four workstation screens make, driven
/// through real content resolution and real unlock-requirement gating,
/// rather than the bypass used in dispatch_content_test.dart.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a diligent Dispatch shift completes end to end and unlocks every '
      'workstation in sequence', () async {
    final missionId = WorkplaceSimulationController.dispatchMissionId;
    final container = ProviderContainer(
      overrides: [
        candidateSessionRepositoryProvider.overrideWithValue(
          InMemoryCandidateSessionRepository(
            session: const CandidateSession(
              candidateId: 'dispatch-playthrough-candidate',
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

    expect(await controller.startMission(scenarioSeed: 82441), isNull);
    expect(await controller.setBriefingAcknowledged(true), isNull);
    expect(await controller.beginShift(), BeginShiftResult.success);

    expect(
      controller.workstationStatus('picking-station'),
      WorkstationStatus.available,
    );
    expect(
      controller.workstationStatus('consolidation-bay'),
      WorkstationStatus.locked,
    );

    final scenario = container
        .read(workplaceSimulationControllerProvider(missionId))
        .requireValue
        .scenario!;
    final crates =
        scenario.resources
            .where((item) => item.resourceType.name == 'carton')
            .toList()
          ..sort((left, right) => left.id.compareTo(right.id));
    final vehicle = scenario.resource('dispatch-vehicle');
    final vehicleTempFailure = vehicle.issues.any(
      (issue) => issue.issueType == 'vehicle_temp_failure',
    );
    final report = scenario.resource('dispatch-report');
    final routeCloseException = report.issues.any(
      (issue) => issue.issueType == 'route_close_exception',
    );

    for (final crate in crates) {
      final issue = crate.issues.isEmpty ? null : crate.issues.single.issueType;
      final payload = switch (issue) {
        'wrong_route' => const {'flagged': true},
        'failed_scan' => const {'rescanned': true},
        _ => const {'scanStatus': 'matched'},
      };
      expect(
        await controller.recordAction(
          stageId: 'picking',
          taskId: 'pick-order-items',
          actionType: ActionType.scanBarcode,
          targetId: crate.id,
          payload: payload,
        ),
        isNull,
      );
    }

    expect(
      controller.workstationStatus('consolidation-bay'),
      WorkstationStatus.available,
    );
    expect(
      controller.workstationStatus('vehicle-check'),
      WorkstationStatus.locked,
    );

    for (final crate in crates) {
      expect(
        await controller.recordAction(
          stageId: 'consolidation-and-staging',
          taskId: 'consolidate-order-items',
          actionType: ActionType.moveItem,
          targetId: crate.id,
          payload: const {'consolidated': true},
        ),
        isNull,
      );
    }
    for (final crate in crates) {
      expect(
        await controller.recordAction(
          stageId: 'consolidation-and-staging',
          taskId: 'stage-route-crates',
          actionType: ActionType.confirmAction,
          targetId: crate.id,
          payload: const {'staged': true},
        ),
        isNull,
      );
    }

    expect(
      controller.workstationStatus('vehicle-check'),
      WorkstationStatus.available,
    );
    expect(
      controller.workstationStatus('dispatch-gate'),
      WorkstationStatus.locked,
    );

    expect(
      await controller.recordAction(
        stageId: 'vehicle-verification',
        taskId: 'verify-vehicle-temperature',
        actionType: ActionType.recordTemperatureReading,
        targetId: 'dispatch-vehicle',
        payload: {
          'heldForRecheck': vehicleTempFailure,
          'proceededWithoutHold': false,
        },
      ),
      isNull,
    );
    for (final crate in crates) {
      expect(
        await controller.recordAction(
          stageId: 'vehicle-verification',
          taskId: 'confirm-load-sequence',
          actionType: ActionType.moveItem,
          targetId: crate.id,
          payload: const {'loadedInSequence': true},
        ),
        isNull,
      );
    }

    expect(
      controller.workstationStatus('dispatch-gate'),
      WorkstationStatus.available,
    );

    expect(
      await controller.recordAction(
        stageId: 'gate-and-exceptions',
        taskId: 'final-gate-scan',
        actionType: ActionType.scanBarcode,
        targetId: 'dispatch-manifest',
        payload: const {'gateScanStatus': 'matched'},
      ),
      isNull,
    );
    for (final crate in crates) {
      final issue = crate.issues.isEmpty ? null : crate.issues.single.issueType;
      final disposition = (issue == 'wrong_route' || issue == 'partial_hold')
          ? 'hold_for_verification'
          : 'accept';
      expect(
        await controller.recordAction(
          stageId: 'gate-and-exceptions',
          taskId: 'handle-dispatch-exceptions',
          actionType: ActionType.selectDisposition,
          targetId: crate.id,
          payload: {
            'disposition': disposition,
            if (disposition != 'accept') 'reason': 'Crate exception flagged',
          },
        ),
        isNull,
      );
    }
    expect(
      await controller.recordAction(
        stageId: 'gate-and-exceptions',
        taskId: 'complete-dispatch-report',
        actionType: ActionType.completeForm,
        targetId: 'dispatch-report',
        payload: {
          'allCratesLoaded': true,
          'exceptionsRecorded': true,
          if (routeCloseException) 'mismatchResolved': true,
        },
      ),
      isNull,
    );
    expect(
      await controller.recordAction(
        stageId: 'gate-and-exceptions',
        taskId: 'make-dispatch-decision',
        actionType: ActionType.makeDecision,
        targetId: 'dispatch-report',
        payload: const {'decision': 'dispatch_complete'},
      ),
      isNull,
    );
    expect(
      await controller.recordAction(
        stageId: 'gate-and-exceptions',
        taskId: 'notify-supervisor',
        actionType: ActionType.confirmAction,
        targetId: 'supervisor-notification',
        payload: const {'supervisorNotified': true, 'exceptionsIncluded': true},
      ),
      isNull,
    );

    final completion = await controller.completeMission(
      screenId: 'dispatch-gate',
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
