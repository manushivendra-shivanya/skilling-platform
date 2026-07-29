import '../../../core/errors/result.dart';

class HomeDashboard {
  const HomeDashboard({
    required this.readinessProgress,
    required this.learningProgress,
    required this.pendingSyncCount,
  });

  final double readinessProgress;
  final double learningProgress;
  final int pendingSyncCount;
}

abstract interface class HomeDashboardRepository {
  Future<Result<HomeDashboard?>> loadDashboard();
}
