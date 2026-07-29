import 'candidate_intelligence.dart';

abstract final class SimulationScoringEngine {
  static SimulationScore scoreInventoryDiscrepancy({
    required String attemptId,
    required List<SimulationEvent> events,
    DateTime? completedAt,
  }) {
    _validateOrdering(events);
    final candidateEvents = events
        .where((event) => !event.isTechnical)
        .toList();
    final recount = candidateEvents.any(
      (event) =>
          event.type == 'decision_selected' &&
          event.payload['decision'] == 'recount',
    );
    final preserved = candidateEvents.any(
      (event) => event.type == 'records_preserved',
    );
    final escalated = candidateEvents.any(
      (event) => event.type == 'exception_escalated',
    );
    final accuracy = recount && preserved
        ? 100
        : recount
        ? 60
        : 20;
    final escalation = escalated ? 100 : 30;
    final sequence = recount && preserved && escalated ? 100 : 50;
    final total = ((accuracy + escalation + sequence) / 3).round();
    return SimulationScore(
      attemptId: attemptId,
      simulationVersion: LogisticsIntelligenceCatalog.simulationVersion,
      totalScore: total,
      dimensionScores: {
        'accuracy': accuracy,
        'safe_escalation': escalation,
        'sequence_compliance': sequence,
      },
      explanation: total >= 80
          ? 'You verified the discrepancy, preserved the audit trail, and escalated safely.'
          : 'The attempt needs a clearer recount, audit trail, and escalation sequence.',
      improvement:
          'Repeat the workflow in this order: recount, preserve records, then escalate.',
      events: events,
      completedAt: completedAt ?? DateTime.now(),
    );
  }

  static void _validateOrdering(List<SimulationEvent> events) {
    for (var index = 0; index < events.length; index++) {
      if (events[index].sequence != index + 1) {
        throw const FormatException(
          'Simulation events must use continuous sequence numbers',
        );
      }
    }
  }
}
