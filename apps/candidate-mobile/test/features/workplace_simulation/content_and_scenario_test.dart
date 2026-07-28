import 'dart:convert';

import 'package:candidate_mobile/features/workplace_simulation/data/asset_simulation_content_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/services/mission_state_service.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/services/scenario_generator.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_enums.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final repository = AssetSimulationContentRepository();

  test('loads and cross-validates the logistics content pack', () async {
    final pack = await repository.getPack('logistics-foundation');
    final workplace = await repository.getWorkplace(
      'central-distribution-centre',
    );
    final mission = await repository.getMission('receive-incoming-shipment-01');
    final competencies = await repository.getCompetencies(
      mission.role.requiredCompetencies,
    );
    final remediation = await repository.getRemediation();

    expect(pack.version, '1.0.0');
    expect(workplace.workstations, hasLength(6));
    expect(mission.versionedId, 'receive-incoming-shipment-01@1.0.0');
    expect(mission.stages, hasLength(6));
    expect(mission.tasks, hasLength(11));
    expect(competencies, hasLength(5));
    expect(remediation.single.id, 'micro-lesson-expiry-policy');
  });

  test('same mission version and seed generate identical scenarios', () async {
    final mission = await repository.getMission('receive-incoming-shipment-01');
    const generator = ScenarioGenerator();

    final first = generator.generate(mission, 48127);
    final second = generator.generate(mission, 48127);

    expect(jsonEncode(first.toJson()), jsonEncode(second.toJson()));
    for (final issue in const [
      'packaging_damage',
      'unreadable_barcode',
      'quantity_shortage',
      'incorrect_sku',
      'near_expiry',
    ]) {
      expect(
        first.resources
            .expand((item) => item.issues)
            .where((item) => item.issueType == issue),
        hasLength(1),
      );
    }
    expect(
      first.resources
          .where((item) => item.resourceType == ResourceType.carton)
          .where((item) => item.issues.isEmpty),
      hasLength(1),
    );
  });

  test(
    'different seeds vary placement or ordering deterministically',
    () async {
      final mission = await repository.getMission(
        'receive-incoming-shipment-01',
      );
      const generator = ScenarioGenerator();

      final first = generator.generate(mission, 48127);
      final second = generator.generate(mission, 90210);

      expect(jsonEncode(first.toJson()), isNot(jsonEncode(second.toJson())));
    },
  );

  test('mission state service accepts only declared transitions', () {
    const service = MissionStateService();
    final initial = _attempt(MissionState.notStarted);

    final briefing = service.transition(initial, MissionState.briefing);
    final active = service.transition(briefing, MissionState.inProgress);
    final paused = service.transition(active, MissionState.paused);
    final resumed = service.transition(paused, MissionState.inProgress);
    final submitted = service.transition(resumed, MissionState.submitted);
    final evaluated = service.transition(submitted, MissionState.evaluated);
    final completed = service.transition(evaluated, MissionState.completed);

    expect(completed.state, MissionState.completed);
    expect(
      () => service.transition(initial, MissionState.completed),
      throwsStateError,
    );
    expect(
      () => service.transition(completed, MissionState.inProgress),
      throwsStateError,
    );
  });
}

SimulationAttempt _attempt(MissionState state) => SimulationAttempt(
  id: 'attempt-1',
  candidateId: 'candidate-1',
  missionId: 'receive-incoming-shipment-01',
  missionVersion: '1.0.0',
  attemptNumber: 1,
  scenarioSeed: 48127,
  state: state,
  startedAt: DateTime.utc(2026, 7, 28),
  elapsedSeconds: 0,
  currentStageId: null,
  completedTaskIds: const {},
  actions: const [],
);
