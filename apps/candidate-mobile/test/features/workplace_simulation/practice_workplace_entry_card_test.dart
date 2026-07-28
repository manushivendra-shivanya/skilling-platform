import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/app/theme/app_theme.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/features/intelligence/data/secure_candidate_intelligence_repository.dart';
import 'package:candidate_mobile/features/practice/presentation/practice_screen.dart';
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
    var opened = false;
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
          home: PracticeScreen(onOpenWorkplaceSimulation: () => opened = true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Workplace Simulation'), findsOneWidget);
    expect(find.textContaining('Receive an Incoming Shipment'), findsOneWidget);
    await tester.ensureVisible(find.text('Start Simulation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Simulation'));
    expect(opened, isTrue);
  });
}
