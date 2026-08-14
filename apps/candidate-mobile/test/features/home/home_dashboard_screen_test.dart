import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/core/errors/result.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/core/storage/secure_key_value_store.dart';
import 'package:candidate_mobile/core/widgets/app_card.dart';
import 'package:candidate_mobile/features/home/data/mock_home_dashboard_repository.dart';
import 'package:candidate_mobile/features/home/domain/home_dashboard_repository.dart';
import 'package:candidate_mobile/features/home/presentation/home_dashboard_screen.dart';
import 'package:candidate_mobile/features/home/presentation/home_header.dart';
import 'package:candidate_mobile/features/home/presentation/job_match_teaser_card.dart';
import 'package:candidate_mobile/features/home/presentation/journey_timeline_card.dart';
import 'package:candidate_mobile/features/home/presentation/today_mission_card.dart';
import 'package:candidate_mobile/features/jobs/data/secure_saved_jobs_repository.dart';
import 'package:candidate_mobile/features/jobs/domain/jobs_repository.dart';
import 'package:candidate_mobile/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_career_passport_repository.dart';

void main() {
  Widget wrap(HomeDashboard? dashboard) {
    return ProviderScope(
      overrides: [
        homeDashboardRepositoryProvider.overrideWithValue(
          MockHomeDashboardRepository(response: Success(dashboard)),
        ),
        // JobMatchTeaserCard pulls in jobsControllerProvider, which reads
        // this first, before touching anything else. Left unoverridden it
        // falls through to the real secure-storage-backed provider, which
        // hangs on the platform channel in the widget test sandbox (see
        // pump_app.dart's own note on this) instead of failing fast.
        // Unauthenticated (no session set, matching pumpCandidateApp's own
        // default) makes JobsController.build() throw AuthenticationFailure
        // immediately -- an AsyncError the teaser card already renders
        // nothing for -- without ever reaching jobsRepositoryProvider or
        // careerPassportControllerProvider's own hang-prone dependencies.
        candidateSessionRepositoryProvider.overrideWithValue(
          InMemoryCandidateSessionRepository(),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: HomeDashboardScreen(
            onOpenDiagnostic: () {},
            onOpenVoiceInterview: () {},
            onOpenPathway: () {},
            onOpenJobs: () {},
            onOpenNotifications: () {},
          ),
        ),
      ),
    );
  }

  // A second wrapper, only for the one test that needs the job-match
  // teaser's data path: an authenticated session plus a loaded jobs
  // catalogue, so jobsControllerProvider actually resolves to data instead
  // of the AuthenticationFailure every other test in this file relies on
  // to keep the teaser silent.
  Widget wrapWithJobs(HomeDashboard? dashboard, List<JobOpportunity> jobs) {
    return ProviderScope(
      overrides: [
        homeDashboardRepositoryProvider.overrideWithValue(
          MockHomeDashboardRepository(response: Success(dashboard)),
        ),
        candidateSessionRepositoryProvider.overrideWithValue(
          InMemoryCandidateSessionRepository(
            session: const CandidateSession(
              candidateId: 'candidate-1',
              isAuthenticated: true,
            ),
          ),
        ),
        jobsRepositoryProvider.overrideWithValue(_FakeJobsRepository(jobs)),
        savedJobsRepositoryProvider.overrideWithValue(
          SecureSavedJobsRepository(InMemorySecureKeyValueStore()),
        ),
        careerPassportRepositoryProvider.overrideWithValue(
          const NoEvidenceCareerPassportRepository(),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: HomeDashboardScreen(
            onOpenDiagnostic: () {},
            onOpenVoiceInterview: () {},
            onOpenPathway: () {},
            onOpenJobs: () {},
            onOpenNotifications: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('shows the candidate, their goal and evidence-backed readiness', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(MockHomeDashboardRepository.sampleDashboard()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rahul'), findsOneWidget);
    expect(find.text('Warehouse Operations Associate'), findsOneWidget);
    expect(find.text('62%'), findsOneWidget);
    expect(find.text('Building'), findsOneWidget);
    // The spec requires the readiness summary to carry an evidence count,
    // and the count to carry its recency window.
    expect(find.textContaining('7 proof items'), findsOneWidget);
    expect(find.textContaining('last 30 days'), findsOneWidget);
  });

  testWidgets('offers exactly one filled primary action', (tester) async {
    await tester.pumpWidget(
      wrap(MockHomeDashboardRepository.sampleDashboard()),
    );
    await tester.pumpAndSettle();

    // The spec asks for a today card with one primary CTA. Any second
    // FilledButton means the hierarchy has regressed.
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('every control on Home is enabled', (tester) async {
    await tester.pumpWidget(
      wrap(MockHomeDashboardRepository.sampleDashboard()),
    );
    await tester.pumpAndSettle();

    // Guards the regression this redesign removed: a disabled "Mission
    // arrives in Learning" button, and rail tiles wired to no callback.
    final buttons = tester.widgetList<ButtonStyleButton>(
      find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );
    expect(buttons, isNotEmpty);
    for (final button in buttons) {
      expect(button.onPressed, isNotNull, reason: 'found a dead control');
    }
  });

  testWidgets('renders without the interview the backend cannot yet supply', (
    tester,
  ) async {
    final sample = MockHomeDashboardRepository.sampleDashboard();
    await tester.pumpWidget(
      wrap(
        HomeDashboard(
          candidateFirstName: sample.candidateFirstName,
          goalRoleName: sample.goalRoleName,
          readinessProgress: sample.readinessProgress,
          evidence: sample.evidence,
          learningProgress: sample.learningProgress,
          pendingSyncCount: 0,
          certificationStatus: sample.certificationStatus,
          applicationsSentThisMonth: sample.applicationsSentThisMonth,
          evidenceThisWeek: sample.evidenceThisWeek,
          applicationsThisWeek: sample.applicationsThisWeek,
          todayMission: sample.todayMission,
          pathway: sample.pathway,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Interview ·'), findsNothing);
    expect(find.text('Rahul'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explains itself when there is no mission to start', (
    tester,
  ) async {
    final sample = MockHomeDashboardRepository.sampleDashboard();
    await tester.pumpWidget(
      wrap(
        HomeDashboard(
          candidateFirstName: sample.candidateFirstName,
          goalRoleName: sample.goalRoleName,
          readinessProgress: sample.readinessProgress,
          evidence: sample.evidence,
          learningProgress: sample.learningProgress,
          pendingSyncCount: 0,
          certificationStatus: sample.certificationStatus,
          applicationsSentThisMonth: sample.applicationsSentThisMonth,
          evidenceThisWeek: sample.evidenceThisWeek,
          applicationsThisWeek: sample.applicationsThisWeek,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No mission today'), findsOneWidget);
    // No mission means no primary button at all, rather than a disabled one.
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('keeps Home to two rows and never repeats a nav tab', (
    tester,
  ) async {
    // Sample dashboard has no upcoming interview here, so the interview
    // practice shortcut is the row under test -- see the next two tests for
    // what happens to it once an interview *is* present.
    final sample = MockHomeDashboardRepository.sampleDashboard();
    await tester.pumpWidget(
      wrap(
        HomeDashboard(
          candidateFirstName: sample.candidateFirstName,
          goalRoleName: sample.goalRoleName,
          readinessProgress: sample.readinessProgress,
          evidence: sample.evidence,
          learningProgress: sample.learningProgress,
          pendingSyncCount: sample.pendingSyncCount,
          certificationStatus: sample.certificationStatus,
          applicationsSentThisMonth: sample.applicationsSentThisMonth,
          evidenceThisWeek: sample.evidenceThisWeek,
          applicationsThisWeek: sample.applicationsThisWeek,
          todayMission: sample.todayMission,
          pathway: sample.pathway,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Home is a next step, not a menu. Jobs, the Coach, the Career Passport
    // and the diagnostic are all reachable from the shell; a row here would
    // just duplicate a destination already on screen.
    expect(find.text('Verified naukriyan'), findsNothing);
    expect(find.text('Career Coach se poochein'), findsNothing);
    expect(find.text('Aapke proof'), findsNothing);
    expect(find.text('Career diagnostic'), findsNothing);
    expect(find.text('Interview practice'), findsOneWidget);
  });

  testWidgets(
    'hides the interview-practice shortcut when the interview card already '
    'offers the same CTA',
    (tester) async {
      // sampleDashboard carries a nextInterview, so UpcomingInterviewCard's
      // own "Prepare" button is already on screen -- the shortcut row below
      // would just be a second way to say the same thing.
      await tester.pumpWidget(
        wrap(MockHomeDashboardRepository.sampleDashboard()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Interview practice'), findsNothing);
      expect(find.text('Prepare'), findsOneWidget);
    },
  );

  testWidgets(
    'shows the interview-practice shortcut again once there is no interview '
    'card to duplicate',
    (tester) async {
      final sample = MockHomeDashboardRepository.sampleDashboard();
      await tester.pumpWidget(
        wrap(
          HomeDashboard(
            candidateFirstName: sample.candidateFirstName,
            goalRoleName: sample.goalRoleName,
            readinessProgress: sample.readinessProgress,
            evidence: sample.evidence,
            learningProgress: sample.learningProgress,
            pendingSyncCount: sample.pendingSyncCount,
            certificationStatus: sample.certificationStatus,
            applicationsSentThisMonth: sample.applicationsSentThisMonth,
            evidenceThisWeek: sample.evidenceThisWeek,
            applicationsThisWeek: sample.applicationsThisWeek,
            todayMission: sample.todayMission,
            pathway: sample.pathway,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Interview practice'), findsOneWidget);
      expect(find.text('Prepare'), findsNothing);
    },
  );

  testWidgets('lifts the mission card into the header gradient', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(MockHomeDashboardRepository.sampleDashboard()),
    );
    await tester.pumpAndSettle();

    // The overlap is the point: the card has to start above where the
    // gradient block ends, or it reads as one more item in a list.
    final headerBottom = tester.getRect(find.byType(HomeHeader)).bottom;
    final cardTop = tester.getRect(find.byType(TodayMissionCard)).top;
    expect(cardTop, lessThan(headerBottom));
  });

  testWidgets('surfaces queued work waiting for a network', (tester) async {
    await tester.pumpWidget(
      wrap(MockHomeDashboardRepository.sampleDashboard()),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('2 items waiting to sync'), findsOneWidget);
  });

  testWidgets("shows the Journey card's four checkpoints for the sample "
      'dashboard', (tester) async {
    await tester.pumpWidget(
      wrap(MockHomeDashboardRepository.sampleDashboard()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Training'), findsOneWidget);
    expect(find.text('Certification'), findsOneWidget);
    expect(find.text('Applications'), findsOneWidget);
    expect(find.text('Interview'), findsOneWidget);

    // All four checkpoints sit inside one JourneyTimelineCard's AppCard,
    // not four separate cards -- the whole card is a single tap target.
    expect(find.byType(JourneyTimelineCard), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(JourneyTimelineCard),
        matching: find.byType(AppCard),
      ),
      findsOneWidget,
    );
  });

  testWidgets("surfaces each Journey checkpoint's plain-language status, "
      'not a bare number or enum name', (tester) async {
    await tester.pumpWidget(
      wrap(MockHomeDashboardRepository.sampleDashboard()),
    );
    await tester.pumpAndSettle();

    // sampleDashboard: pathway 4/12 lessons, certificationStatus.notStarted,
    // 2 applications sent this month, and a scheduled interview with
    // Delhivery Hub in Ghaziabad.
    expect(find.text('4 / 12 lessons'), findsOneWidget);
    expect(find.text('Not started yet'), findsOneWidget);
    expect(find.text('2 applications sent this month'), findsOneWidget);

    // Scoped to the Journey card, not a bare findsOneWidget: sampleDashboard
    // also has an UpcomingInterviewCard above it that repeats the same
    // location text, so the unscoped text legitimately appears twice.
    expect(
      find.descendant(
        of: find.byType(JourneyTimelineCard),
        matching: find.textContaining('Ghaziabad'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('omits the readiness-band note once already job ready -- nothing '
      'further to point toward', (tester) async {
    final sample = MockHomeDashboardRepository.sampleDashboard();
    await tester.pumpWidget(
      wrap(
        HomeDashboard(
          candidateFirstName: sample.candidateFirstName,
          goalRoleName: sample.goalRoleName,
          readinessProgress: 0.9,
          evidence: sample.evidence,
          learningProgress: sample.learningProgress,
          pendingSyncCount: sample.pendingSyncCount,
          certificationStatus: sample.certificationStatus,
          applicationsSentThisMonth: sample.applicationsSentThisMonth,
          evidenceThisWeek: sample.evidenceThisWeek,
          applicationsThisWeek: sample.applicationsThisWeek,
          todayMission: sample.todayMission,
          pathway: sample.pathway,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Job ready'), findsOneWidget);
    expect(find.textContaining('% to'), findsNothing);
  });

  testWidgets("surfaces this week's proof and application counts", (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(MockHomeDashboardRepository.sampleDashboard()),
    );
    await tester.pumpAndSettle();

    // sampleDashboard: evidenceThisWeek 3, applicationsThisWeek 1 -- a
    // distinct window from the header's 30-day evidence figure and the
    // Journey card's calendar-month application count.
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('3 proof items'), findsOneWidget);
    expect(find.text('1 application sent'), findsOneWidget);
  });

  testWidgets(
    'hides the job-match teaser when Jobs cannot be reached (no session)',
    (tester) async {
      await tester.pumpWidget(
        wrap(MockHomeDashboardRepository.sampleDashboard()),
      );
      await tester.pumpAndSettle();

      // wrap()'s unauthenticated session makes jobsControllerProvider an
      // AsyncError -- the teaser renders nothing rather than an error card,
      // since Jobs enrichment is below-the-fold, not a primary flow.
      expect(find.byType(JobMatchTeaserCard), findsOneWidget);
      expect(find.text('Best match for you'), findsNothing);
    },
  );

  testWidgets('shows the best-matching job once Jobs data is available', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithJobs(MockHomeDashboardRepository.sampleDashboard(), const [
        // A title distinct from sampleDashboard.goalRoleName ("Warehouse
        // Operations Associate", already on screen in HomeHeader's goal
        // chip) -- reusing it here would make find.text ambiguous between
        // the two widgets.
        JobOpportunity(
          id: 'job-1',
          title: 'Inventory Executive',
          employer: 'Meridian Logistics',
          location: 'Gurugram, Haryana',
          isSupervisorRole: false,
          description: 'Cycle counts and stock reconciliation.',
          source: 'flora',
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Best match for you'), findsOneWidget);
    expect(find.text('Inventory Executive'), findsOneWidget);
    expect(find.text('Meridian Logistics'), findsOneWidget);
    expect(find.textContaining('% match'), findsOneWidget);
  });
}

class _FakeJobsRepository implements JobsRepository {
  _FakeJobsRepository(this._jobs);

  final List<JobOpportunity> _jobs;

  @override
  Future<Result<List<JobOpportunity>>> loadJobs() async => Success(_jobs);

  @override
  Future<Result<Set<String>>> readAppliedJobIds(String candidateId) async =>
      const Success({});

  @override
  Future<Result<void>> saveApplication(
    String candidateId,
    String jobId,
  ) async => const Success(null);

  @override
  bool get isLiveData => true;
}
