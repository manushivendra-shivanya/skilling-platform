import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/app/theme/app_theme.dart';
import 'package:candidate_mobile/core/errors/app_failure.dart';
import 'package:candidate_mobile/core/errors/result.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/features/career_passport/domain/career_passport_repository.dart';
import 'package:candidate_mobile/features/career_passport/presentation/role_readiness_section.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_enums.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_runtime.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Proves `RoleReadinessSection` renders one row per `ReadinessCategory`
/// with the level derived from `deriveRoleReadiness`, end to end against the
/// same `careerPassportControllerProvider` `CareerPassportSection` reads --
/// the mapping/aggregation rules themselves are covered by
/// `role_readiness_test.dart` in isolation.
void main() {
  testWidgets('renders a row per category, chip label reflects level, unmapped '
      'category shows Unknown', (tester) async {
    final container = _buildContainer(
      _FakeCareerPassportRepository(
        evidence: [
          _evidence(
            // Ready: WMS receiving competency, high score.
            id: 'evidence-receiving',
            competencyId: 'document-verification',
            score: 90,
          ),
          _evidence(
            // Needs practice: WMS processing competency, low score.
            id: 'evidence-processing',
            competencyId: 'hygiene-discipline',
            score: 30,
          ),
          _evidence(
            // Developing: WMS dispatch competency, mid score.
            id: 'evidence-dispatch',
            competencyId: 'scan-discipline',
            score: 55,
          ),
          // No mapped evidence for supervisor at all.
        ],
      ),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    expect(find.text('Role Readiness'), findsOneWidget);
    expect(
      find.text(
        'Flora provides evidence and readiness signals, not certification.',
      ),
      findsOneWidget,
    );

    expect(find.text('Receiving'), findsOneWidget);
    expect(find.text('Processing'), findsOneWidget);
    expect(find.text('Dispatch'), findsOneWidget);
    expect(find.text('Supervisor'), findsOneWidget);

    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Needs practice'), findsOneWidget);
    expect(find.text('Developing'), findsOneWidget);
    expect(find.text('Unknown'), findsOneWidget);
  });

  testWidgets('all categories show Unknown when there is no evidence', (
    tester,
  ) async {
    final container = _buildContainer(
      _FakeCareerPassportRepository(evidence: const []),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    expect(find.text('Unknown'), findsNWidgets(4));
  });
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
    home: const Scaffold(body: RoleReadinessSection()),
  ),
);

EvidenceRecord _evidence({
  required String id,
  required String competencyId,
  required int score,
}) => EvidenceRecord(
  id: id,
  candidateId: 'candidate-1',
  attemptId: 'attempt-1',
  missionId: 'mission-1',
  missionVersion: '1.0.0',
  scenarioSeed: 1,
  competencyId: competencyId,
  score: score,
  evidenceType: EvidenceType.simulationObservation,
  title: 'Observed evidence',
  description: 'Generated from the append-only action trail.',
  issuedAt: DateTime.utc(2026, 7, 20, 9, 30),
  verificationStatus: EvidenceVerificationStatus.systemObserved,
);

class _FakeCareerPassportRepository implements CareerPassportRepository {
  _FakeCareerPassportRepository({required List<EvidenceRecord> evidence})
    : _evidence = evidence;

  final List<EvidenceRecord> _evidence;

  @override
  Future<Result<List<EvidenceRecord>>> loadEvidence(String candidateId) async =>
      Success(_evidence);

  @override
  final bool canManageShareLink = false;

  @override
  Future<Result<ShareLink?>> loadShareLink(String candidateId) async =>
      const Success(null);

  @override
  Future<Result<ShareLink>> createShareLink(String candidateId) async =>
      ResultFailure(
        const StorageFailure('Share links require an account connection.'),
      );

  @override
  Future<Result<void>> revokeShareLink(String candidateId) async =>
      const Success(null);

  @override
  final bool canManageEmployerAccess = false;

  @override
  Future<Result<List<EmployerAccessEntry>>> loadEmployerAccess(
    String candidateId,
  ) async => const Success([]);

  @override
  Future<Result<void>> grantEmployerAccess(
    String candidateId,
    String employerId,
  ) async => const Success(null);

  @override
  Future<Result<void>> revokeEmployerAccess(
    String candidateId,
    String employerId,
  ) async => const Success(null);
}
