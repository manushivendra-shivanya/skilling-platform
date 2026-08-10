import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../core/analytics/analytics_event.dart';
import '../../../core/errors/app_failure.dart';
import '../../career_passport/domain/role_readiness.dart';
import '../../career_passport/presentation/career_passport_controller.dart';
import '../domain/job_match.dart';
import '../domain/jobs_repository.dart';
import 'job_filters.dart';

class JobsState {
  const JobsState({
    required this.jobs,
    required this.appliedJobIds,
    required this.savedJobIds,
    required this.isLiveData,
    required this.readiness,
    required this.preferredCity,
    this.query = '',
    this.tab = JobsTab.forYou,
    this.filters = JobFilters.empty,
  });

  final List<JobOpportunity> jobs;
  final Set<String> appliedJobIds;
  final Set<String> savedJobIds;
  final bool isLiveData;

  /// Feeds `deriveJobMatch`'s evidence-fit dimension -- empty (not an
  /// error) when Career Passport has no evidence yet, or couldn't be
  /// loaded; see `JobsController.build()`.
  final List<RoleReadinessSummary> readiness;

  /// From the candidate's Shift availability -- the one place this app
  /// already asks where someone wants to work. Null when unset or
  /// unavailable; `deriveJobMatch` treats that as no location signal, not
  /// a penalty.
  final String? preferredCity;

  final String query;
  final JobsTab tab;
  final JobFilters filters;

  /// Every city present in the currently loaded catalogue, for the
  /// Location filter's option list -- built from real data rather than a
  /// hardcoded list, so it never drifts from what's actually available.
  List<String> get availableLocations {
    final cities = jobs.map((job) => jobCity(job.location)).toSet().toList()
      ..sort();
    return cities;
  }

  List<String> get availableCompanies {
    final companies = jobs.map((job) => job.employer).toSet().toList()..sort();
    return companies;
  }

  /// Filtered (search + [filters]), then either ranked by fit (For You) or
  /// left in the backend's own newest-first order (All jobs) -- see
  /// [JobsTab]'s own doc comment for why ranking never hides a job the
  /// other tab shows.
  List<JobListItem> visibleJobs({DateTime? now}) {
    final reference = now ?? DateTime.now();
    final normalizedQuery = query.trim().toLowerCase();
    final filtered = jobs.where((job) {
      final matchesQuery =
          normalizedQuery.isEmpty ||
          job.title.toLowerCase().contains(normalizedQuery) ||
          job.employer.toLowerCase().contains(normalizedQuery) ||
          job.location.toLowerCase().contains(normalizedQuery);
      return matchesQuery && filters.matches(job, now: reference);
    });

    final items = [
      for (final job in filtered)
        JobListItem(
          job: job,
          matchScore: deriveJobMatch(
            job,
            readiness: readiness,
            preferredCity: preferredCity,
            now: reference,
          ),
        ),
    ];
    if (tab == JobsTab.forYou) {
      items.sort((a, b) => b.matchScore.compareTo(a.matchScore));
    }
    return items;
  }

  JobsState copyWith({
    Set<String>? appliedJobIds,
    Set<String>? savedJobIds,
    String? query,
    JobsTab? tab,
    JobFilters? filters,
  }) {
    return JobsState(
      jobs: jobs,
      appliedJobIds: appliedJobIds ?? this.appliedJobIds,
      savedJobIds: savedJobIds ?? this.savedJobIds,
      isLiveData: isLiveData,
      readiness: readiness,
      preferredCity: preferredCity,
      query: query ?? this.query,
      tab: tab ?? this.tab,
      filters: filters ?? this.filters,
    );
  }
}

final jobsControllerProvider = AsyncNotifierProvider<JobsController, JobsState>(
  JobsController.new,
);

class JobsController extends AsyncNotifier<JobsState> {
  String? _candidateId;

  @override
  Future<JobsState> build() async {
    final session =
        (await ref.read(candidateSessionRepositoryProvider).readSession()).when(
          success: (value) => value,
          failure: (failure) => throw failure,
        );
    if (session == null || !session.isAuthenticated) {
      throw const AuthenticationFailure('Sign in again to view jobs.');
    }
    _candidateId = session.candidateId;

    final repository = ref.read(jobsRepositoryProvider);
    final jobs = (await repository.loadJobs()).when(
      success: (value) => value,
      failure: (failure) => throw failure,
    );
    final applied = (await repository.readAppliedJobIds(
      session.candidateId,
    )).when(success: (value) => value, failure: (failure) => throw failure);

    final saved =
        (await ref
                .read(savedJobsRepositoryProvider)
                .readSavedJobIds(session.candidateId))
            .when(success: (value) => value, failure: (_) => const <String>{});

    // Career Passport evidence and Shift availability are both genuinely
    // optional inputs to job matching -- a candidate who hasn't done any
    // WMS simulation yet, or hasn't set shift availability, still gets a
    // usable (if less personalized) Jobs list, per this codebase's
    // "missing optional signal is a graceful no-op" convention. Neither
    // failure here should ever block Jobs from loading.
    final readiness = await _readReadiness();
    final preferredCity = await _readPreferredCity(session.candidateId);

    return JobsState(
      jobs: jobs,
      appliedJobIds: applied,
      savedJobIds: saved,
      isLiveData: repository.isLiveData,
      readiness: readiness,
      preferredCity: preferredCity,
    );
  }

  Future<List<RoleReadinessSummary>> _readReadiness() async {
    try {
      final careerPassport = await ref.watch(
        careerPassportControllerProvider.future,
      );
      return careerPassport.readiness;
    } catch (_) {
      return const [];
    }
  }

  Future<String?> _readPreferredCity(String candidateId) async {
    try {
      final result = await ref
          .read(shiftAvailabilityRepositoryProvider)
          .readAvailability(candidateId);
      return result.when(
        success: (availability) => availability.preferredCity,
        failure: (_) => null,
      );
    } catch (_) {
      return null;
    }
  }

  void search(String query) {
    final value = state.valueOrNull;
    if (value != null) state = AsyncData(value.copyWith(query: query));
  }

  void setTab(JobsTab tab) {
    final value = state.valueOrNull;
    if (value != null) state = AsyncData(value.copyWith(tab: tab));
  }

  void applyFilters(JobFilters filters) {
    final value = state.valueOrNull;
    if (value != null) state = AsyncData(value.copyWith(filters: filters));
  }

  void clearFilters() {
    final value = state.valueOrNull;
    if (value != null) {
      state = AsyncData(value.copyWith(filters: JobFilters.empty));
    }
  }

  Future<void> toggleSaved(String jobId) async {
    final value = state.valueOrNull;
    final candidateId = _candidateId;
    if (value == null || candidateId == null) return;
    final isSaved = value.savedJobIds.contains(jobId);
    final nextSaved = isSaved
        ? (value.savedJobIds.toSet()..remove(jobId))
        : {...value.savedJobIds, jobId};
    // Optimistic -- a bookmark toggle should feel instant; on-device
    // storage failing here is rare and not worth blocking the tap for.
    state = AsyncData(value.copyWith(savedJobIds: nextSaved));
    await ref
        .read(savedJobsRepositoryProvider)
        .setSaved(candidateId, jobId, saved: !isSaved);
  }

  Future<AppFailure?> apply(String jobId) async {
    final value = state.valueOrNull;
    final candidateId = _candidateId;
    if (value == null || candidateId == null) {
      return const StorageFailure('Jobs are still loading.');
    }
    final result = await ref
        .read(jobsRepositoryProvider)
        .saveApplication(candidateId, jobId);
    return result.when(
      success: (_) {
        state = AsyncData(
          value.copyWith(appliedJobIds: {...value.appliedJobIds, jobId}),
        );
        unawaited(
          ref
              .read(analyticsTrackerProvider)
              .track(
                value.isLiveData
                    ? AnalyticsEvent.jobApplicationCreated()
                    : AnalyticsEvent.mockApplicationCreated(),
              ),
        );
        return null;
      },
      failure: (failure) => failure,
    );
  }

  void retry() => ref.invalidateSelf();
}
