import '../../../core/errors/result.dart';
import '../domain/home_dashboard_repository.dart';

/// Stands in for `GET /home/dashboard` until that endpoint exists.
///
/// The values are a plausible mid-pathway Warehouse Operations Associate
/// rather than round numbers, so the screen is judged against realistic text
/// lengths — Devanagari titles wrap differently from English placeholders.
class MockHomeDashboardRepository implements HomeDashboardRepository {
  MockHomeDashboardRepository({Result<HomeDashboard?>? response})
    : _response = response ?? Success(sampleDashboard());

  Result<HomeDashboard?> _response;

  /// Built by a function, not a const: [UpcomingInterview] carries a
  /// [DateTime], and the interview has to stay in the near future however
  /// long after this was written the app is opened.
  static HomeDashboard sampleDashboard() {
    return HomeDashboard(
      candidateFirstName: 'Rahul',
      goalRoleName: 'Warehouse Operations Associate',
      readinessProgress: 0.62,
      evidence: const EvidenceSummary(count: 7, windowDays: 30),
      learningProgress: 0.33,
      pendingSyncCount: 2,
      certificationStatus: CertificationJourneyStatus.notStarted,
      applicationsSentThisMonth: 2,
      todayMission: const TodayMission(
        unitId: 'lu-receiving-mismatch-report',
        title: 'Inventory mismatch report karna seekhein',
        summary: 'Galat count milne par supervisor ko kaise bataayein.',
        durationMinutes: 6,
        stepNumber: 3,
        totalSteps: 8,
      ),
      pathway: const PathwayProgress(
        title: 'Receiving & Put-away',
        completedUnits: 4,
        totalUnits: 12,
      ),
      nextInterview: UpcomingInterview(
        employerName: 'Delhivery Hub',
        location: 'Ghaziabad',
        scheduledAt: DateTime.now().add(const Duration(days: 2, hours: 3)),
      ),
    );
  }

  void setResponse(Result<HomeDashboard?> response) {
    _response = response;
  }

  @override
  Future<Result<HomeDashboard?>> loadDashboard() async => _response;
}
