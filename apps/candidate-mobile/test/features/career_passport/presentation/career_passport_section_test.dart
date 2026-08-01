import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/app/theme/app_theme.dart';
import 'package:candidate_mobile/core/errors/app_failure.dart';
import 'package:candidate_mobile/core/errors/result.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/features/career_passport/domain/career_passport_repository.dart';
import 'package:candidate_mobile/features/career_passport/presentation/career_passport_section.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_enums.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_runtime.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Proves the evidence-detail drill-down and the share-link controls work
/// end to end against `CareerPassportSection`, not just that the
/// underlying data model/repository logic is correct in isolation (which
/// `career_passport_test.dart` and `wms_career_passport_repository_test.dart`
/// already cover).
void main() {
  testWidgets('tapping an evidence entry opens its detail sheet', (
    tester,
  ) async {
    final container = _buildContainer(_FakeCareerPassportRepository());
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
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

  testWidgets(
    'generating then revoking a share link updates the controls in place',
    (tester) async {
      final repository = _FakeCareerPassportRepository(
        canManageShareLink: true,
      );
      final container = _buildContainer(repository);
      addTearDown(container.dispose);

      await tester.pumpWidget(_app(container));
      await tester.pumpAndSettle();

      expect(find.text('Generate share link'), findsOneWidget);
      expect(find.text('Copy link'), findsNothing);

      await tester.tap(find.text('Generate share link'));
      await tester.pumpAndSettle();

      expect(find.textContaining('/career-passport/share/'), findsOneWidget);
      expect(find.text('Copy link'), findsOneWidget);
      expect(find.text('Revoke'), findsOneWidget);

      await tester.tap(find.text('Revoke'));
      await tester.pumpAndSettle();

      expect(find.text('Generate share link'), findsOneWidget);
      expect(find.text('Copy link'), findsNothing);
    },
  );
}

ProviderContainer _buildContainer(CareerPassportRepository repository) =>
    ProviderContainer(
      overrides: [
        candidateSessionRepositoryProvider.overrideWithValue(
          InMemoryCandidateSessionRepository(
            session: const CandidateSession(
              candidateId: 'candidate-1',
              isAuthenticated: true,
            ),
          ),
        ),
        careerPassportRepositoryProvider.overrideWithValue(repository),
      ],
    );

Widget _app(ProviderContainer container) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    theme: buildAppTheme(),
    home: const Scaffold(body: CareerPassportSection()),
  ),
);

class _FakeCareerPassportRepository implements CareerPassportRepository {
  _FakeCareerPassportRepository({this.canManageShareLink = false});

  ShareLink? _shareLink;

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
  final bool canManageShareLink;

  @override
  Future<Result<ShareLink?>> loadShareLink(String candidateId) async =>
      Success(_shareLink);

  @override
  Future<Result<ShareLink>> createShareLink(String candidateId) async {
    if (!canManageShareLink) {
      return ResultFailure(
        const StorageFailure('Share links require an account connection.'),
      );
    }
    final link = _shareLink ??= ShareLink(
      token: 'fake-token',
      url: 'https://api.example.com/v1/career-passport/share/fake-token',
      expiresAt: DateTime.utc(2026, 8, 31),
    );
    return Success(link);
  }

  @override
  Future<Result<void>> revokeShareLink(String candidateId) async {
    _shareLink = null;
    return const Success(null);
  }

  @override
  Future<Result<void>> setShareable(String candidateId, bool shareable) async =>
      const Success(null);
}
