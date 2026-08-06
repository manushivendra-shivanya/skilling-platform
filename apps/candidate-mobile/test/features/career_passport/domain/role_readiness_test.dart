import 'package:candidate_mobile/features/career_passport/domain/career_passport.dart';
import 'package:candidate_mobile/features/career_passport/domain/role_readiness.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_enums.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 1);

  test('a category with no mapped evidence at all is unknown', () {
    final readiness = deriveRoleReadiness(const []);

    expect(readiness, hasLength(4));
    expect(
      readiness.every((summary) => summary.level == ReadinessLevel.unknown),
      isTrue,
    );
    expect(readiness.every((summary) => summary.averageScore == null), isTrue);
    expect(readiness.every((summary) => summary.evidenceCount == 0), isTrue);
  });

  test('an average score of 70 or above is ready', () {
    final entries = _activeEntries([
      _evidence('document-verification', score: 70, issuedAt: now),
    ], now);

    final receiving = _summaryFor(
      deriveRoleReadiness(entries),
      ReadinessCategory.receiving,
    );

    expect(receiving.level, ReadinessLevel.ready);
    expect(receiving.averageScore, 70);
    expect(receiving.evidenceCount, 1);
  });

  test('an average score between 50 and 69 is developing', () {
    final entries = _activeEntries([
      _evidence('document-verification', score: 55, issuedAt: now),
    ], now);

    final receiving = _summaryFor(
      deriveRoleReadiness(entries),
      ReadinessCategory.receiving,
    );

    expect(receiving.level, ReadinessLevel.developing);
    expect(receiving.averageScore, 55);
  });

  test('an average score below 50 is needs practice', () {
    final entries = _activeEntries([
      _evidence('document-verification', score: 40, issuedAt: now),
    ], now);

    final receiving = _summaryFor(
      deriveRoleReadiness(entries),
      ReadinessCategory.receiving,
    );

    expect(receiving.level, ReadinessLevel.needsPractice);
    expect(receiving.averageScore, 40);
  });

  test('stale evidence still counts toward the average', () {
    final entries = deriveCareerPassportEntries(
      [
        _evidence(
          'document-verification',
          score: 80,
          issuedAt: now.subtract(const Duration(days: 200)),
        ),
      ],
      now: now,
      staleAfter: const Duration(days: 180),
    );
    expect(entries.single.freshness, EvidenceFreshnessState.stale);

    final receiving = _summaryFor(
      deriveRoleReadiness(entries),
      ReadinessCategory.receiving,
    );

    expect(receiving.level, ReadinessLevel.ready);
    expect(receiving.averageScore, 80);
    expect(receiving.evidenceCount, 1);
  });

  test('superseded evidence is excluded from the average', () {
    final entries = deriveCareerPassportEntries([
      _evidence(
        'document-verification',
        id: 'older',
        score: 20,
        issuedAt: now.subtract(const Duration(days: 40)),
      ),
      _evidence(
        'document-verification',
        id: 'newer',
        score: 90,
        issuedAt: now.subtract(const Duration(days: 1)),
      ),
    ], now: now);
    expect(
      entries.singleWhere((e) => e.evidence.id == 'older').freshness,
      EvidenceFreshnessState.superseded,
    );

    final receiving = _summaryFor(
      deriveRoleReadiness(entries),
      ReadinessCategory.receiving,
    );

    expect(receiving.averageScore, 90);
    expect(receiving.evidenceCount, 1);
  });

  test('an unmapped competency id is ignored rather than thrown', () {
    final entries = _activeEntries([
      _evidence('not-a-real-competency', score: 10, issuedAt: now),
    ], now);

    expect(() => deriveRoleReadiness(entries), returnsNormally);
    final readiness = deriveRoleReadiness(entries);
    expect(readiness.every((summary) => summary.evidenceCount == 0), isTrue);
  });

  test(
    'food_safety_compliance overrides to receiving despite spanning domains',
    () {
      final entries = _activeEntries([
        _evidence('food_safety_compliance', score: 90, issuedAt: now),
      ], now);

      final receiving = _summaryFor(
        deriveRoleReadiness(entries),
        ReadinessCategory.receiving,
      );

      expect(receiving.evidenceCount, 1);
    },
  );

  test(
    'order_quantity_control overrides to processing despite spanning domains',
    () {
      final entries = _activeEntries([
        _evidence('order_quantity_control', score: 90, issuedAt: now),
      ], now);

      final processing = _summaryFor(
        deriveRoleReadiness(entries),
        ReadinessCategory.processing,
      );

      expect(processing.evidenceCount, 1);
    },
  );

  test(
    'dispatch_route_assignment maps to supervisor, not dispatch, despite the name',
    () {
      final entries = _activeEntries([
        _evidence('dispatch_route_assignment', score: 90, issuedAt: now),
      ], now);

      final readiness = deriveRoleReadiness(entries);
      expect(
        _summaryFor(readiness, ReadinessCategory.supervisor).evidenceCount,
        1,
      );
      expect(
        _summaryFor(readiness, ReadinessCategory.dispatch).evidenceCount,
        0,
      );
    },
  );

  test('each category aggregates independently', () {
    final entries = _activeEntries([
      _evidence('document-verification', id: 'a', score: 90, issuedAt: now),
      _evidence('hygiene-discipline', id: 'b', score: 40, issuedAt: now),
      _evidence('scan-discipline', id: 'c', score: 60, issuedAt: now),
    ], now);

    final readiness = deriveRoleReadiness(entries);

    expect(
      _summaryFor(readiness, ReadinessCategory.receiving).level,
      ReadinessLevel.ready,
    );
    expect(
      _summaryFor(readiness, ReadinessCategory.processing).level,
      ReadinessLevel.needsPractice,
    );
    expect(
      _summaryFor(readiness, ReadinessCategory.dispatch).level,
      ReadinessLevel.developing,
    );
    expect(
      _summaryFor(readiness, ReadinessCategory.supervisor).level,
      ReadinessLevel.unknown,
    );
  });
}

RoleReadinessSummary _summaryFor(
  List<RoleReadinessSummary> readiness,
  ReadinessCategory category,
) => readiness.singleWhere((summary) => summary.category == category);

List<CareerPassportEntry> _activeEntries(
  List<EvidenceRecord> evidence,
  DateTime now,
) => deriveCareerPassportEntries(evidence, now: now);

EvidenceRecord _evidence(
  String competencyId, {
  String id = 'evidence-1',
  required int score,
  required DateTime issuedAt,
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
  issuedAt: issuedAt,
  verificationStatus: EvidenceVerificationStatus.systemObserved,
);
