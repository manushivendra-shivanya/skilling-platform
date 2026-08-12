import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/app/theme/app_theme.dart';
import 'package:candidate_mobile/core/errors/result.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/core/storage/secure_key_value_store.dart';
import 'package:candidate_mobile/features/jobs/data/secure_saved_jobs_repository.dart';
import 'package:candidate_mobile/features/jobs/domain/jobs_repository.dart';
import 'package:candidate_mobile/features/jobs/presentation/jobs_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_career_passport_repository.dart';

/// Proves the source provenance caption and the external-apply button
/// render correctly per `JobOpportunity.source`, end to end against
/// `JobsScreen` -- the mapping/derivation rules themselves are covered by
/// `jobs_repository_test.dart` in isolation. Does not tap the external-apply
/// button (that would invoke the real `url_launcher` platform channel,
/// unavailable in a widget test) -- only asserts it renders.
void main() {
  testWidgets('shows a provenance caption only for aggregator-sourced jobs', (
    tester,
  ) async {
    final container = _buildContainer(
      _FakeJobsRepository([
        const JobOpportunity(
          id: 'job-flora',
          title: 'Warehouse Operations Associate',
          employer: 'Apex Consumer Products',
          location: 'Bhiwandi, Maharashtra',
          isSupervisorRole: false,
          description: 'Receiving and put-away.',
          source: 'flora',
        ),
        const JobOpportunity(
          id: 'job-adzuna',
          title: 'Inventory Executive',
          employer: 'Meridian Logistics',
          location: 'Gurugram, Haryana',
          isSupervisorRole: false,
          description: 'Cycle counts and stock accuracy.',
          source: 'adzuna',
          applyUrl: 'https://adzuna.example/jobs/1',
        ),
      ]),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    expect(find.text('via Adzuna'), findsOneWidget);
    expect(find.text('Meridian Logistics • Gurugram, Haryana'), findsOneWidget);
    expect(
      find.text('Apex Consumer Products • Bhiwandi, Maharashtra'),
      findsOneWidget,
    );
  });

  testWidgets(
    'an aggregator-sourced job shows an external apply button instead of the internal apply flow',
    (tester) async {
      final container = _buildContainer(
        _FakeJobsRepository([
          const JobOpportunity(
            id: 'job-adzuna',
            title: 'Inventory Executive',
            employer: 'Meridian Logistics',
            location: 'Gurugram, Haryana',
            isSupervisorRole: false,
            description: 'Cycle counts and stock accuracy.',
            source: 'adzuna',
            applyUrl: 'https://adzuna.example/jobs/1',
          ),
        ]),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_app(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Inventory Executive'));
      await tester.pumpAndSettle();

      expect(find.text('View original listing on Adzuna'), findsOneWidget);
      expect(find.text('Apply on Adzuna'), findsOneWidget);
      expect(
        find.text('Share your profile for this application'),
        findsNothing,
      );
      expect(find.text('Submit application'), findsNothing);
    },
  );

  testWidgets(
    'a Flora-native job keeps the internal share-and-submit apply flow',
    (tester) async {
      final container = _buildContainer(
        _FakeJobsRepository([
          const JobOpportunity(
            id: 'job-flora',
            title: 'Warehouse Operations Associate',
            employer: 'Apex Consumer Products',
            location: 'Bhiwandi, Maharashtra',
            isSupervisorRole: false,
            description: 'Receiving and put-away.',
            source: 'flora',
          ),
        ]),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_app(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Warehouse Operations Associate'));
      await tester.pumpAndSettle();

      expect(
        find.text('Share your profile for this application'),
        findsOneWidget,
      );
      expect(find.textContaining('View original listing on'), findsNothing);
      expect(find.textContaining('Apply on'), findsNothing);
    },
  );

  testWidgets(
    'the Location filter drills into a searchable tick-box sub-page and applies',
    (tester) async {
      final container = _buildContainer(
        _FakeJobsRepository([
          const JobOpportunity(
            id: 'job-bhiwandi',
            title: 'Warehouse Operations Associate',
            employer: 'Apex Consumer Products',
            location: 'Bhiwandi, Maharashtra',
            isSupervisorRole: false,
            description: 'Receiving.',
            source: 'flora',
          ),
          const JobOpportunity(
            id: 'job-pune',
            title: 'Dispatch Executive',
            employer: 'Northstar Freight',
            location: 'Pune, Maharashtra',
            isSupervisorRole: false,
            description: 'Dispatch.',
            source: 'flora',
          ),
        ]),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_app(container));
      await tester.pumpAndSettle();

      // Open the filter sheet.
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      // Category list, not a flat wall of chips.
      expect(find.text('Location'), findsWidgets);
      // Location + Role type + Company summaries all read "Any" until set;
      // Date posted reads "Any time" instead, a distinct string.
      expect(find.text('Any'), findsNWidgets(3));

      // Drill into Location.
      await tester.tap(find.text('Location'));
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsNWidgets(2));

      // Search narrows the tick-box list.
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('filterCategorySearchField')),
          matching: find.byType(TextFormField),
        ),
        'bhiw',
      );
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsOneWidget);
      expect(find.text('Bhiwandi'), findsOneWidget);
      expect(find.text('Pune'), findsNothing);

      // Tick it, go back, apply.
      await tester.tap(find.text('Bhiwandi'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Bhiwandi'), findsOneWidget); // now the summary line

      await tester.tap(find.text('Show 1 job'));
      await tester.pumpAndSettle();

      expect(find.text('Warehouse Operations Associate'), findsOneWidget);
      expect(find.text('Dispatch Executive'), findsNothing);
      expect(find.text('Bhiwandi'), findsOneWidget); // active filter pill
    },
  );

  testWidgets(
    'the "Top match for you" ribbon appears only on the #1 For-you card, '
    'and disappears on the All jobs tab',
    (tester) async {
      final container = _buildContainer(
        _FakeJobsRepository([
          // Flora-native + freshly posted: higher deriveJobMatch score.
          JobOpportunity(
            id: 'job-top',
            title: 'Warehouse Operations Associate',
            employer: 'Apex Consumer Products',
            location: 'Bhiwandi, Maharashtra',
            isSupervisorRole: false,
            description: 'Receiving and put-away.',
            source: 'flora',
            publishedAt: DateTime.now(),
          ),
          // Aggregator-sourced, no publishedAt: lower score, sorts second.
          const JobOpportunity(
            id: 'job-second',
            title: 'Inventory Executive',
            employer: 'Meridian Logistics',
            location: 'Gurugram, Haryana',
            isSupervisorRole: false,
            description: 'Cycle counts and stock accuracy.',
            source: 'adzuna',
            applyUrl: 'https://adzuna.example/jobs/1',
          ),
        ]),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_app(container));
      await tester.pumpAndSettle();

      // For-you is the default tab, and it's ranked by match score -- the
      // ribbon states that the #1 card is genuinely the top match.
      expect(find.text('Top match for you'), findsOneWidget);

      await tester.tap(find.text('All jobs'));
      await tester.pumpAndSettle();

      // Not sorted by match on this tab, so the ribbon's claim wouldn't
      // hold -- it must not render here.
      expect(find.text('Top match for you'), findsNothing);
    },
  );

  testWidgets('the ribbon is withheld on a For-you list with only one job', (
    tester,
  ) async {
    final container = _buildContainer(
      _FakeJobsRepository([
        const JobOpportunity(
          id: 'job-only',
          title: 'Warehouse Operations Associate',
          employer: 'Apex Consumer Products',
          location: 'Bhiwandi, Maharashtra',
          isSupervisorRole: false,
          description: 'Receiving and put-away.',
          source: 'flora',
        ),
      ]),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    // "Top match" only means something relative to other jobs.
    expect(find.text('Top match for you'), findsNothing);
  });

  testWidgets(
    'the match meter bar renders only on the For-you tab, alongside the '
    'match badge -- not on All jobs',
    (tester) async {
      final container = _buildContainer(
        _FakeJobsRepository([
          const JobOpportunity(
            id: 'job-a',
            title: 'Warehouse Operations Associate',
            employer: 'Apex Consumer Products',
            location: 'Bhiwandi, Maharashtra',
            isSupervisorRole: false,
            description: 'Receiving and put-away.',
            source: 'flora',
          ),
          const JobOpportunity(
            id: 'job-b',
            title: 'Inventory Executive',
            employer: 'Meridian Logistics',
            location: 'Gurugram, Haryana',
            isSupervisorRole: false,
            description: 'Cycle counts and stock accuracy.',
            source: 'adzuna',
            applyUrl: 'https://adzuna.example/jobs/1',
          ),
        ]),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_app(container));
      await tester.pumpAndSettle();

      // One meter bar per card on the ranked For-you tab.
      expect(find.byType(FractionallySizedBox), findsNWidgets(2));

      await tester.tap(find.text('All jobs'));
      await tester.pumpAndSettle();

      // showMatch is false here, so no match badge and no meter bar.
      expect(find.byType(FractionallySizedBox), findsNothing);
    },
  );
}

ProviderContainer _buildContainer(JobsRepository repository) =>
    ProviderContainer(
      overrides: [
        candidateSessionRepositoryProvider.overrideWithValue(
          InMemoryCandidateSessionRepository(
            session: const CandidateSession(
              candidateId: 'candidate-1',
              isAuthenticated: true,
            ),
          ),
        ),
        jobsRepositoryProvider.overrideWithValue(repository),
        // JobsController reads both of these to compute match scores --
        // always overridden here (same rationale as pump_app.dart's
        // unconditional overrides) so neither falls through to a real
        // secure-storage-backed provider that hangs on the unmocked
        // platform channel in this bare-ProviderContainer harness.
        savedJobsRepositoryProvider.overrideWithValue(
          SecureSavedJobsRepository(InMemorySecureKeyValueStore()),
        ),
        careerPassportRepositoryProvider.overrideWithValue(
          const NoEvidenceCareerPassportRepository(),
        ),
      ],
    );

Widget _app(ProviderContainer container) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    theme: buildAppTheme(),
    home: const Scaffold(body: JobsScreen()),
  ),
);

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
