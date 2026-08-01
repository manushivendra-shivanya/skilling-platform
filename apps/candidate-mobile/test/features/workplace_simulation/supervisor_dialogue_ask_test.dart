import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/app/theme/app_theme.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/application/workplace_interaction_contracts.dart';
import 'package:candidate_mobile/features/workplace_simulation/application/workplace_simulation_controller.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/asset_simulation_content_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/data/local_simulation_attempt_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/workplace_task_drafts.dart';
import 'package:candidate_mobile/features/workplace_simulation/presentation/inspection_zone_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Proves the NPC supervisor's `learner_asks` topics (near-expiry policy,
/// skip-inspection) shipped in the content-deepening pass are reachable from
/// Inspection Zone's "Ask the supervisor" affordance.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Inspection Zone lets the candidate ask the supervisor guidance-only '
    'questions',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = await _activeContainer();
      addTearDown(container.dispose);
      await _completeDocumentAndCountStages(container);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: InspectionZoneScreen(
              missionId: WorkplaceSimulationController.missionId,
              onBack: () {},
              onOpenBarcodeStation: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Ask the supervisor'));
      await tester.pumpAndSettle();
      expect(find.text('What if a carton is near expiry?'), findsOneWidget);
      expect(
        find.text('Can I skip inspecting a carton that looks fine?'),
        findsOneWidget,
      );

      await tester.tap(find.text('What if a carton is near expiry?'));
      await tester.pumpAndSettle();
      expect(find.textContaining("don't decide that yourself"), findsOneWidget);
    },
  );
}

Future<ProviderContainer> _activeContainer() async {
  final container = ProviderContainer(
    overrides: [
      candidateSessionRepositoryProvider.overrideWithValue(
        InMemoryCandidateSessionRepository(
          session: const CandidateSession(
            candidateId: 'supervisor-ask-candidate',
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

/// Drives document review and receiving count to completion, unlocking
/// Inspection Zone. Mirrors the sequence proven in
/// workplace_simulation_controller_test.dart.
Future<void> _completeDocumentAndCountStages(
  ProviderContainer container,
) async {
  final controller = container.read(
    workplaceSimulationControllerProvider(
      WorkplaceSimulationController.missionId,
    ).notifier,
  );
  await controller.addDocumentFinding(
    const AddDocumentFindingCommand(
      sourceDocument: DocumentSource.both,
      itemReference: 'SKU-1001',
      findingType: DocumentFindingType.other,
    ),
  );
  await controller.submitDocumentReview(const SubmitDocumentReviewCommand());
  await controller.confirmShipmentIdentity(
    const ConfirmShipmentIdentityCommand(confirmed: true),
  );
  final state = container
      .read(
        workplaceSimulationControllerProvider(
          WorkplaceSimulationController.missionId,
        ),
      )
      .requireValue;
  for (final cartonId
      in state.mission.task('confirm-received-counts').targetResourceIds) {
    await controller.recordCartonCount(
      RecordCartonCountCommand(
        cartonId: cartonId,
        enteredQuantity: 0,
        countMethod: CountMethod.individual,
      ),
    );
  }
  await controller.submitReceivingCount(const SubmitReceivingCountCommand());
}
