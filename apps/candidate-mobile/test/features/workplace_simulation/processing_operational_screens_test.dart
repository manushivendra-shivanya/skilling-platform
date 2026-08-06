import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/app/theme/app_theme.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/application/workplace_simulation_controller.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/asset_simulation_content_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/local_simulation_attempt_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/presentation/packing_station_screen.dart';
import 'package:candidate_mobile/features/workplace_simulation/presentation/processing_entry_screen.dart';
import 'package:candidate_mobile/features/workplace_simulation/presentation/processing_office_screen.dart';
import 'package:candidate_mobile/features/workplace_simulation/presentation/quality_check_screen.dart';
import 'package:candidate_mobile/features/workplace_simulation/presentation/workplace_overview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Processing workstation screens render, lock correctly and confirm '
    'hygiene',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final missionId = WorkplaceSimulationController.processingMissionId;
      final container = await _activeProcessingContainer(missionId);
      addTearDown(container.dispose);
      var opened = false;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: WorkplaceOverviewScreen(
              missionId: missionId,
              onOpenWorkstation: (_) => opened = true,
              onReturnToPractice: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      for (final station in const [
        'Processing Entry',
        'Packing Station',
        'Quality Check',
        'Processing Office',
      ]) {
        expect(find.text(station), findsOneWidget);
      }

      await tester.tap(find.text('Processing Entry'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(opened, isTrue);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: PackingStationScreen(
              missionId: missionId,
              onBack: () {},
              onOpenQualityCheck: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Packing Station is locked'), findsOneWidget);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: QualityCheckScreen(
              missionId: missionId,
              onBack: () {},
              onOpenProcessingOffice: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Quality Check is locked'), findsOneWidget);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: ProcessingOfficeScreen(
              missionId: missionId,
              onBack: () {},
              onMissionComplete: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Processing Office is locked'), findsOneWidget);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: ProcessingEntryScreen(
              missionId: missionId,
              onBack: () {},
              onOpenPackingStation: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Confirm compliant'), findsOneWidget);
      expect(find.text('Report a gap'), findsOneWidget);

      await tester.tap(find.text('Confirm compliant'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final attempt = container
          .read(workplaceSimulationControllerProvider(missionId))
          .requireValue
          .attempt!;
      expect(
        attempt.actions.any(
          (action) => action.taskId == 'confirm-hygiene-compliance',
        ),
        isTrue,
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}

Future<ProviderContainer> _activeProcessingContainer(String missionId) async {
  final container = ProviderContainer(
    overrides: [
      candidateSessionRepositoryProvider.overrideWithValue(
        InMemoryCandidateSessionRepository(
          session: const CandidateSession(
            candidateId: 'processing-screen-candidate',
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
  await container.read(workplaceSimulationControllerProvider(missionId).future);
  final controller = container.read(
    workplaceSimulationControllerProvider(missionId).notifier,
  );
  await controller.startMission(scenarioSeed: 63910);
  await controller.setBriefingAcknowledged(true);
  final result = await controller.beginShift();
  if (result != BeginShiftResult.success) {
    container.dispose();
    throw StateError(
      'Could not prepare active Processing test attempt: $result',
    );
  }
  return container;
}
