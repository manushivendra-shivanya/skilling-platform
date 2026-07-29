import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/application/workplace_simulation_controller.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/asset_simulation_content_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/local_simulation_attempt_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Proves the scenario catalog is a real, controller-level capability, not
/// just something the generator can do in isolation: selecting a named
/// scenario at mission start persists on the attempt and survives a reload
/// (the same path a resumed attempt goes through), so a candidate who closes
/// and reopens the app mid-shift keeps the same scenario they started.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'starting a mission against a named scenario persists across a reload',
    () async {
      final missionId = WorkplaceSimulationController.missionId;
      final container = ProviderContainer(
        overrides: [
          candidateSessionRepositoryProvider.overrideWithValue(
            InMemoryCandidateSessionRepository(
              session: const CandidateSession(
                candidateId: 'scenario-catalog-candidate',
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

      expect(
        await controller.startMission(
          scenarioSeed: 48127,
          scenarioId: 'perfect-delivery',
        ),
        isNull,
      );

      final afterStart = container
          .read(workplaceSimulationControllerProvider(missionId))
          .requireValue;
      expect(afterStart.attempt!.scenarioId, 'perfect-delivery');
      expect(
        afterStart.scenario!.resources.expand((item) => item.issues),
        isEmpty,
      );

      // Simulate the app reopening mid-shift: rebuild the controller from
      // the same persisted attempt repository, with no scenarioId passed
      // explicitly this time -- it must come back from the saved attempt.
      container.invalidate(workplaceSimulationControllerProvider(missionId));
      final reloaded = await container.read(
        workplaceSimulationControllerProvider(missionId).future,
      );

      expect(reloaded.attempt!.scenarioId, 'perfect-delivery');
      expect(
        reloaded.scenario!.resources.expand((item) => item.issues),
        isEmpty,
      );
    },
  );

  test(
    'starting a mission with no scenarioId keeps using the mission default',
    () async {
      final missionId = WorkplaceSimulationController.missionId;
      final container = ProviderContainer(
        overrides: [
          candidateSessionRepositoryProvider.overrideWithValue(
            InMemoryCandidateSessionRepository(
              session: const CandidateSession(
                candidateId: 'scenario-default-candidate',
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

      expect(await controller.startMission(scenarioSeed: 48127), isNull);

      final state = container
          .read(workplaceSimulationControllerProvider(missionId))
          .requireValue;
      expect(state.attempt!.scenarioId, isNull);
      expect(
        state.scenario!.resources.expand((item) => item.issues),
        isNotEmpty,
      );
    },
  );
}
