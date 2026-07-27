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
      ),
      LearningUnit(
        id: 'safe-escalation',
        title: 'When and how to escalate',
        durationMinutes: 6,
        isDailyMission: false,
      ),
      LearningUnit(
        id: 'dispatch-priority',
        title: 'Understanding dispatch priority',
        durationMinutes: 10,
        isDailyMission: false,
      ),
    ]);
  }
}
