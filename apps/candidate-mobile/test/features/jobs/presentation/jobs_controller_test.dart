import 'package:candidate_mobile/app/dependencies.dart';
import 'package:candidate_mobile/core/errors/result.dart';
import 'package:candidate_mobile/core/repositories/candidate_session_repository.dart';
import 'package:candidate_mobile/core/storage/secure_key_value_store.dart';
import 'package:candidate_mobile/features/jobs/data/secure_saved_jobs_repository.dart';
import 'package:candidate_mobile/features/jobs/domain/jobs_repository.dart';
import 'package:candidate_mobile/features/jobs/presentation/job_filters.dart';
import 'package:candidate_mobile/features/jobs/presentation/jobs_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_career_passport_repository.dart';

void main() {
  test(
    'For you ranks by match score; All jobs keeps the loaded order',
    () async {
      final container = _buildContainer(
        jobs: [
          const JobOpportunity(
            id: 'low-match',
            title: 'Cyber Defense Manager',
            employer: 'Some Corp',
            location: 'Mumbai, Maharashtra',
            isSupervisorRole: false,
            description: 'Corporate, unrelated to warehouse work.',
            source: 'adzuna',
          ),
          const JobOpportunity(
            id: 'high-match',
            title: 'Warehouse Operations Associate',
            employer: 'Apex Consumer Products',
            location: 'Bhiwandi, Maharashtra',
            isSupervisorRole: false,
            description: 'Receiving and put-away.',
            source: 'flora',
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = await container.read(jobsControllerProvider.future);
      final forYouOrder = state
          .visibleJobs()
          .map((item) => item.job.id)
          .toList();
      expect(forYouOrder.first, 'high-match');

      container.read(jobsControllerProvider.notifier).setTab(JobsTab.all);
      final allState = container.read(jobsControllerProvider).requireValue;
      final allOrder = allState
          .visibleJobs()
          .map((item) => item.job.id)
          .toList();
      expect(allOrder, ['low-match', 'high-match']);
    },
  );

  test(
    'applyFilters narrows visibleJobs; clearFilters restores everything',
    () async {
      final container = _buildContainer(
        jobs: [
          const JobOpportunity(
            id: 'warehouse-job',
            title: 'Warehouse Operations Associate',
            employer: 'Apex Consumer Products',
            location: 'Bhiwandi, Maharashtra',
            isSupervisorRole: false,
            description: 'Receiving.',
            source: 'flora',
          ),
          const JobOpportunity(
            id: 'dispatch-job',
            title: 'Dispatch Executive',
            employer: 'Northstar Freight',
            location: 'Pune, Maharashtra',
            isSupervisorRole: false,
            description: 'Dispatch.',
            source: 'flora',
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(jobsControllerProvider.future);
      final notifier = container.read(jobsControllerProvider.notifier);

      notifier.applyFilters(const JobFilters(roles: {'dispatch'}));
      final filtered = container
          .read(jobsControllerProvider)
          .requireValue
          .visibleJobs()
          .map((item) => item.job.id)
          .toList();
      expect(filtered, ['dispatch-job']);

      notifier.clearFilters();
      final restored = container
          .read(jobsControllerProvider)
          .requireValue
          .visibleJobs()
          .length;
      expect(restored, 2);
    },
  );

  test('toggleSaved adds and removes a job from savedJobIds', () async {
    final container = _buildContainer(
      jobs: [
        const JobOpportunity(
          id: 'job-1',
          title: 'Inventory Executive',
          employer: 'Meridian Logistics',
          location: 'Gurugram, Haryana',
          isSupervisorRole: false,
          description: 'Cycle counts.',
          source: 'flora',
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(jobsControllerProvider.future);
    final notifier = container.read(jobsControllerProvider.notifier);

    await notifier.toggleSaved('job-1');
    expect(container.read(jobsControllerProvider).requireValue.savedJobIds, {
      'job-1',
    });

    await notifier.toggleSaved('job-1');
    expect(
      container.read(jobsControllerProvider).requireValue.savedJobIds,
      isEmpty,
    );
  });
}

ProviderContainer _buildContainer({required List<JobOpportunity> jobs}) =>
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
        jobsRepositoryProvider.overrideWithValue(_FakeJobsRepository(jobs)),
        savedJobsRepositoryProvider.overrideWithValue(
          SecureSavedJobsRepository(InMemorySecureKeyValueStore()),
        ),
        careerPassportRepositoryProvider.overrideWithValue(
          const NoEvidenceCareerPassportRepository(),
        ),
      ],
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
