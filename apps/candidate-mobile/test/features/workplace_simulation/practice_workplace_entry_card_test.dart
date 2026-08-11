import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/app/theme/app_theme.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/features/intelligence/data/secure_candidate_intelligence_repository.dart';
import 'package:candidate_mobile/features/practice/presentation/practice_screen.dart';
import 'package:candidate_mobile/features/workplace_simulation/application/workplace_simulation_controller.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/asset_simulation_content_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/local_simulation_attempt_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Practice resolves and opens the Workplace Simulation card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? openedMissionId;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          candidateSessionRepositoryProvider.overrideWithValue(
            InMemoryCandidateSessionRepository(
              session: const CandidateSession(
                candidateId: 'practice-candidate',
                isAuthenticated: true,
              ),
            ),
          ),
          candidateIntelligenceRepositoryProvider.overrideWithValue(
            InMemoryCandidateIntelligenceRepository(),
          ),
          simulationContentRepositoryProvider.overrideWithValue(
            AssetSimulationContentRepository(),
          ),
          simulationAttemptRepositoryProvider.overrideWithValue(
            InMemorySimulationAttemptRepository(),
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: PracticeScreen(
            onOpenWorkplaceSimulation: (missionId) =>
                openedMissionId = missionId,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // One SectorTaskCard per mission: Receiving, Put Away, Processing,
    // Dispatch -- each card's title is the mission name itself now
    // (no shared generic "Workplace Simulation" title / "Start
    // Simulation" button -- the whole card is the tap target, tagged
    // "Not started" with a START tear tab).
    expect(find.text('Receive an Incoming Shipment'), findsOneWidget);
    expect(find.text('Put Away Incoming Stock'), findsOneWidget);
    expect(find.text('Not started'), findsNWidgets(4));
    await tester.ensureVisible(find.text('Receive an Incoming Shipment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Receive an Incoming Shipment'));
    expect(openedMissionId, WorkplaceSimulationController.missionId);
  });
}
