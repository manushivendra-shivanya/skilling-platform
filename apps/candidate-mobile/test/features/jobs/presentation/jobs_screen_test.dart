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

      expect(find.text('View & apply on Adzuna'), findsOneWidget);
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
      expect(find.textContaining('View & apply on'), findsNothing);
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
