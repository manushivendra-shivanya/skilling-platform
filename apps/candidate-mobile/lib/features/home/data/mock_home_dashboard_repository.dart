import '../../../core/errors/result.dart';
import '../domain/home_dashboard_repository.dart';

class MockHomeDashboardRepository implements HomeDashboardRepository {
  MockHomeDashboardRepository({Result<HomeDashboard?>? response})
    : _response =
          response ??
          const Success(
            HomeDashboard(
              readinessProgress: 0.35,
              learningProgress: 0.2,
              pendingSyncCount: 1,
            ),
          );

  Result<HomeDashboard?> _response;

  void setResponse(Result<HomeDashboard?> response) {
    _response = response;
  }

  @override
  Future<Result<HomeDashboard?>> loadDashboard() async => _response;
}
