import 'package:candidate_mobile/features/intelligence/domain/candidate_intelligence.dart';
import 'package:candidate_mobile/features/intelligence/domain/simulation_scoring_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scores ordered safe actions deterministically', () {
    final time = DateTime.utc(2026, 7, 28);
    final score = SimulationScoringEngine.scoreInventoryDiscrepancy(
      attemptId: 'attempt-1',
      completedAt: time,
      events: [
        SimulationEvent(
          sequence: 1,
          type: 'decision_selected',
          payload: const {'decision': 'recount'},
          clientTime: time,
        ),
        SimulationEvent(
          sequence: 2,
          type: 'records_preserved',
          payload: const {},
          clientTime: time,
        ),
        SimulationEvent(
          sequence: 3,
          type: 'exception_escalated',
          payload: const {},
          clientTime: time,
        ),
      ],
    );

    expect(score.totalScore, 100);
    expect(score.dimensionScores['safe_escalation'], 100);
    expect(score.explanation, contains('audit trail'));
  });

  test('technical failures never reduce the deterministic score', () {
    final time = DateTime.utc(2026, 7, 28);
    List<SimulationEvent> events(bool includeFailure) => [
      SimulationEvent(
        sequence: 1,
        type: 'decision_selected',
        payload: const {'decision': 'recount'},
        clientTime: time,
      ),
      if (includeFailure)
        SimulationEvent(
          sequence: 2,
          type: 'network_interrupted',
          payload: const {},
          clientTime: time,
          isTechnical: true,
        ),
      SimulationEvent(
        sequence: includeFailure ? 3 : 2,
        type: 'records_preserved',
        payload: const {},
        clientTime: time,
      ),
      SimulationEvent(
        sequence: includeFailure ? 4 : 3,
        type: 'exception_escalated',
        payload: const {},
        clientTime: time,
      ),
    ];

    final normal = SimulationScoringEngine.scoreInventoryDiscrepancy(
      attemptId: 'normal',
      events: events(false),
    );
    final interrupted = SimulationScoringEngine.scoreInventoryDiscrepancy(
      attemptId: 'interrupted',
      events: events(true),
    );

    expect(interrupted.totalScore, normal.totalScore);
  });

  test('rejects missing or duplicate event sequence numbers', () {
    expect(
      () => SimulationScoringEngine.scoreInventoryDiscrepancy(
        attemptId: 'invalid',
        events: [
          SimulationEvent(
            sequence: 2,
            type: 'decision_selected',
            payload: const {'decision': 'recount'},
            clientTime: DateTime.utc(2026, 7, 28),
          ),
        ],
      ),
      throwsFormatException,
    );
  });
}
