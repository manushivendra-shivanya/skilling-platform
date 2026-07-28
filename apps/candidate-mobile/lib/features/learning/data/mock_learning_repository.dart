import '../../../core/errors/result.dart';
import '../domain/learning_repository.dart';

class MockLearningRepository implements LearningRepository {
  @override
  Future<Result<List<LearningUnit>>> loadPathway() async {
    return const Success([
      LearningUnit(
        id: 'inventory-basics',
        title: 'Inventory accuracy basics',
        durationMinutes: 8,
        isDailyMission: true,
        version: '1.0.0',
        content:
            'Count the physical stock twice. Compare it with the system record. Preserve both values before making any correction.',
      ),
      LearningUnit(
        id: 'safe-escalation',
        title: 'When and how to escalate',
        durationMinutes: 6,
        isDailyMission: false,
        version: '1.0.0',
        content:
            'Isolate the exception, record the facts, and notify the approved owner. Never hide damage or overwrite the audit trail.',
      ),
      LearningUnit(
        id: 'dispatch-priority',
        title: 'Understanding dispatch priority',
        durationMinutes: 10,
        isDailyMission: false,
        version: '1.0.0',
        content:
            'Compare SLA deadlines, operational risk, and approved priority rules. Safety controls remain mandatory under time pressure.',
      ),
    ]);
  }
}
