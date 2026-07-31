import 'package:candidate_mobile/features/career_passport/domain/career_passport.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_enums.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 1);

  test('marks the newest record per competency as active', () {
    final entries = deriveCareerPassportEntries([
      _evidence(
        'receiving-accuracy',
        issuedAt: now.subtract(const Duration(days: 10)),
      ),
    ], now: now);

    expect(entries.single.freshness, EvidenceFreshnessState.active);
  });

  test('marks older records for the same competency as superseded', () {
    final older = _evidence(
      'receiving-accuracy',
      id: 'evidence-older',
      issuedAt: now.subtract(const Duration(days: 40)),
    );
    final newer = _evidence(
      'receiving-accuracy',
      id: 'evidence-newer',
      issuedAt: now.subtract(const Duration(days: 5)),
    );

    final entries = deriveCareerPassportEntries([older, newer], now: now);

    expect(entries.first.evidence.id, 'evidence-newer');
    expect(entries.first.freshness, EvidenceFreshnessState.active);
    expect(entries.last.evidence.id, 'evidence-older');
    expect(entries.last.freshness, EvidenceFreshnessState.superseded);
  });

  test('marks the newest record as stale once past the staleness window', () {
    final entries = deriveCareerPassportEntries(
      [
        _evidence(
          'receiving-accuracy',
          issuedAt: now.subtract(const Duration(days: 200)),
        ),
      ],
      now: now,
      staleAfter: const Duration(days: 180),
    );

    expect(entries.single.freshness, EvidenceFreshnessState.stale);
  });

  test('tracks each competency independently', () {
    final entries = deriveCareerPassportEntries([
      _evidence('receiving-accuracy', id: 'a', issuedAt: now),
      _evidence('put-away-accuracy', id: 'b', issuedAt: now),
    ], now: now);

    expect(entries, hasLength(2));
    expect(
      entries.every((e) => e.freshness == EvidenceFreshnessState.active),
      isTrue,
    );
  });

  test('competencyDisplayName title-cases dash-separated ids', () {
    expect(competencyDisplayName('receiving-accuracy'), 'Receiving Accuracy');
  });
}

EvidenceRecord _evidence(
  String competencyId, {
  String id = 'evidence-1',
  required DateTime issuedAt,
}) => EvidenceRecord(
  id: id,
  candidateId: 'candidate-1',
  attemptId: 'attempt-1',
  missionId: 'mission-1',
  missionVersion: '1.0.0',
  scenarioSeed: 1,
  competencyId: competencyId,
  score: 80,
  evidenceType: EvidenceType.simulationObservation,
  title: 'Observed evidence',
  description: 'Generated from the append-only action trail.',
  issuedAt: issuedAt,
  verificationStatus: EvidenceVerificationStatus.systemObserved,
);
