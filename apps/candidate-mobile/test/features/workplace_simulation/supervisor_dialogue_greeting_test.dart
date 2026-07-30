import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/app/theme/app_theme.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/application/workplace_simulation_controller.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/asset_simulation_content_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/local_simulation_attempt_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/presentation/document_desk_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Proves the NPC supervisor's mission-start greeting (added to
/// receive_shipment_mission.json in the content-deepening pass) is actually
/// surfaced to the candidate on Document Desk, not just loadable schema.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Document Desk greets the candidate with the supervisor\'s mission-start '
    'line, once',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = await _activeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: DocumentDeskScreen(
              missionId: WorkplaceSimulationController.missionId,
              onBack: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Receiving Supervisor'), findsOneWidget);
      expect(
        find.textContaining('Apex Consumer Products is on PO-2026-001'),
        findsOneWidget,
      );

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Apex Consumer Products is on PO-2026-001'),
        findsNothing,
      );
    },
  );
}

Future<ProviderContainer> _activeContainer() async {
  final container = ProviderContainer(
    overrides: [
      candidateSessionRepositoryProvider.overrideWithValue(
        InMemoryCandidateSessionRepository(
          session: const CandidateSession(
            candidateId: 'supervisor-greeting-candidate',
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
