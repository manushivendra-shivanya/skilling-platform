import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/application/workplace_simulation_controller.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/asset_simulation_content_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/local_simulation_attempt_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_enums.dart';
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
      final firstAttemptId = state.attempt!.id;

      expect(await controller.beginShift(), isNull);
      expect(await controller.pause(), isNull);
      expect(
        container
            .read(workplaceSimulationControllerProvider)
            .requireValue
            .attempt!
            .state,
        MissionState.paused,
      );
      expect(await controller.resume(), isNull);
      expect(
        container
            .read(workplaceSimulationControllerProvider)
            .requireValue
            .attempt!
            .state,
        MissionState.inProgress,
      );

      expect(await controller.submit(), isNull);
      state = container
          .read(workplaceSimulationControllerProvider)
          .requireValue;
      expect(state.result!.status, MissionStatus.incomplete);
      expect(state.attempt!.state, MissionState.failed);

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
}
