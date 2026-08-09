import 'package:candidate_mobile/features/career_passport/domain/career_passport.dart';
import 'package:candidate_mobile/features/shifts/domain/shift_match.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_enums.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 1);

  test('a shift requiring no competencies is 100% match, vacuously', () {
    final match = deriveShiftMatch(const [], const []);

    expect(match.matchPercent, 100);
    expect(match.missingCompetencyIds, isEmpty);
    expect(match.isEligible, isTrue);
  });

  test('no evidence at all against a shift with requirements is 0% match', () {
    final match = deriveShiftMatch(const [], ['document-verification']);

    expect(match.matchPercent, 0);
    expect(match.missingCompetencyIds, ['document-verification']);
    expect(match.isEligible, isFalse);
  });

  test('having demonstrated every required competency is a 100% match', () {
    final entries = _activeEntries([
      _evidence('document-verification', score: 10, issuedAt: now),
    ], now);

    final match = deriveShiftMatch(entries, ['document-verification']);

    expect(match.matchPercent, 100);
    expect(match.missingCompetencyIds, isEmpty);
    expect(match.isEligible, isTrue);
  });

  test('eligibility depends on having any evidence, not a score threshold', () {
    // Unlike deriveRoleReadiness, a low score still counts as "demonstrated"
    // for shift eligibility -- it's readiness's job to grade proficiency.
    final entries = _activeEntries([
      _evidence('document-verification', score: 5, issuedAt: now),
    ], now);

    final match = deriveShiftMatch(entries, ['document-verification']);

    expect(match.isEligible, isTrue);
  });

  test('partial coverage rounds the match percentage', () {
    final entries = _activeEntries([
      _evidence('document-verification', score: 80, issuedAt: now),
    ], now);

    final match = deriveShiftMatch(entries, [
      'document-verification',
      'hygiene-discipline',
      'scan-discipline',
    ]);

    expect(match.matchPercent, 33);
    expect(match.missingCompetencyIds, [
      'hygiene-discipline',
      'scan-discipline',
    ]);
    expect(match.isEligible, isFalse);
  });

  test('superseded evidence does not count toward the match', () {
    final entries = deriveCareerPassportEntries([
      _evidence(
        'document-verification',
        id: 'older',
        score: 80,
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

    final match = deriveShiftMatch(entries, ['document-verification']);

    expect(match.isEligible, isTrue);
    expect(match.missingCompetencyIds, isEmpty);
  });

  test('stale evidence still counts as demonstrated', () {
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

    final match = deriveShiftMatch(entries, ['document-verification']);

    expect(match.isEligible, isTrue);
  });
}

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
