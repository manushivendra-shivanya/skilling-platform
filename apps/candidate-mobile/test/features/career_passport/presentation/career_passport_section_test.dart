import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/app/theme/app_theme.dart';
import 'package:candidate_mobile/core/errors/result.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/features/career_passport/domain/career_passport_repository.dart';
import 'package:candidate_mobile/features/career_passport/presentation/career_passport_section.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_enums.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_runtime.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Proves the evidence-detail drill-down works end to end: tapping an
/// entry tile in the Career Passport list opens a detail sheet showing
/// the fields the summary tile has no room for (mission, attempt,
/// evidence type, issued date) -- not just that the data model can
/// derive freshness correctly, which `career_passport_test.dart` already
/// covers.
void main() {
  testWidgets('tapping an evidence entry opens its detail sheet', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        candidateSessionRepositoryProvider.overrideWithValue(
          InMemoryCandidateSessionRepository(
            session: const CandidateSession(
              candidateId: 'candidate-1',
              isAuthenticated: true,
            ),
          ),
        ),
        careerPassportRepositoryProvider.overrideWithValue(
          _FakeCareerPassportRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: CareerPassportSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('View Career Passport'));
    await tester.pumpAndSettle();
    expect(find.text('Receiving Accuracy'), findsOneWidget);

    await tester.tap(find.text('Receiving Accuracy'));
    await tester.pumpAndSettle();

    expect(find.text('receive-incoming-shipment-01'), findsOneWidget);
    expect(find.text('attempt-1'), findsOneWidget);
    expect(find.text('Simulation observation'), findsOneWidget);
  });
}

class _FakeCareerPassportRepository implements CareerPassportRepository {
  @override
  bool get canManageSharing => true;

  @override
  Future<Result<List<EvidenceRecord>>> loadEvidence(String candidateId) async =>
      Success([
        EvidenceRecord(
          id: 'evidence-1',
          candidateId: candidateId,
          attemptId: 'attempt-1',
          missionId: 'receive-incoming-shipment-01',
          missionVersion: '1.0.0',
          scenarioSeed: 48127,
          competencyId: 'receiving-accuracy',
          score: 92,
          evidenceType: EvidenceType.simulationObservation,
          title: 'Receiving accuracy demonstrated',
          description: 'Generated from a completed workplace simulation.',
          issuedAt: DateTime.utc(2026, 7, 20, 9, 30),
          verificationStatus: EvidenceVerificationStatus.systemObserved,
        ),
      ]);

  @override
  Future<Result<bool>> isShareable(String candidateId) async =>
      const Success(false);

  @override
  Future<Result<void>> setShareable(String candidateId, bool shareable) async =>
      const Success(null);
}
