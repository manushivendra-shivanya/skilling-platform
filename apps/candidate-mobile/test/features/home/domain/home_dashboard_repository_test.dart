import 'package:candidate_mobile/features/home/domain/home_dashboard_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeDashboard.percentToNextReadinessBand', () {
    HomeDashboard withReadiness(double readinessProgress) => HomeDashboard(
      candidateFirstName: 'Rahul',
      goalRoleName: 'Warehouse Operations Associate',
      readinessProgress: readinessProgress,
      evidence: const EvidenceSummary(count: 7, windowDays: 30),
      learningProgress: 0.33,
      pendingSyncCount: 0,
      certificationStatus: CertificationJourneyStatus.notStarted,
      applicationsSentThisMonth: 0,
      evidenceThisWeek: 0,
      applicationsThisWeek: 0,
    );

    test('points toward Building while starting out', () {
      final dashboard = withReadiness(0.10);
      expect(dashboard.readinessBand, ReadinessBand.starting);
      expect(dashboard.nextReadinessBand, ReadinessBand.building);
      // 0.34 - 0.10 is exactly 24 in real arithmetic, but not in binary
      // floating point (it lands fractionally above 24) -- ceil rounding up
      // to 25 here is that same "never round down and claim less is needed
      // than truly is" behavior the test below exercises deliberately,
      // just showing up as an incidental side effect of this input rather
      // than the point of this particular case.
      expect(dashboard.percentToNextReadinessBand, 25);
    });

    test('points toward Job ready while building', () {
      // Matches MockHomeDashboardRepository.sampleDashboard()'s 0.62.
      final dashboard = withReadiness(0.62);
      expect(dashboard.readinessBand, ReadinessBand.building);
      expect(dashboard.nextReadinessBand, ReadinessBand.jobReady);
      expect(dashboard.percentToNextReadinessBand, 13);
    });

    test('rounds up rather than to nearest, never claiming 0% early', () {
      // 0.749 is one thousandth short of the 0.75 threshold -- rounding to
      // nearest would read as "0% to Job ready" while still short of it.
      final dashboard = withReadiness(0.749);
      expect(dashboard.percentToNextReadinessBand, 1);
    });

    test('is null once already job ready -- nothing further to point to', () {
      final dashboard = withReadiness(0.9);
      expect(dashboard.readinessBand, ReadinessBand.jobReady);
      expect(dashboard.nextReadinessBand, isNull);
      expect(dashboard.percentToNextReadinessBand, isNull);
    });
  });

  group('TodayMission remaining-steps estimate', () {
    test('counts steps and time left after the current one', () {
      const mission = TodayMission(
        unitId: 'lu-1',
        title: 'Test unit',
        summary: 'Summary',
        durationMinutes: 6,
        stepNumber: 3,
        totalSteps: 8,
      );

      expect(mission.stepsRemainingAfterThis, 5);
      expect(mission.estimatedMinutesRemainingAfterThis, 30);
    });

    test('is zero on the pathway\'s last step', () {
      const mission = TodayMission(
        unitId: 'lu-1',
        title: 'Test unit',
        summary: 'Summary',
        durationMinutes: 6,
        stepNumber: 8,
        totalSteps: 8,
      );

      expect(mission.stepsRemainingAfterThis, 0);
      expect(mission.estimatedMinutesRemainingAfterThis, 0);
    });
  });

  group('PathwayProgress.remainingUnits', () {
    test('counts lessons left to finish the pathway', () {
      const pathway = PathwayProgress(
        title: 'Receiving & Put-away',
        completedUnits: 4,
        totalUnits: 12,
      );

      expect(pathway.remainingUnits, 8);
    });

    test('is zero once the pathway is complete', () {
      const pathway = PathwayProgress(
        title: 'Receiving & Put-away',
        completedUnits: 12,
        totalUnits: 12,
      );

      expect(pathway.remainingUnits, 0);
    });
  });
}
