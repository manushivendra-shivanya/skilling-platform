import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencies.dart';
import '../../../core/analytics/analytics_event.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/jobs_repository.dart';

class JobsState {
  const JobsState({
    required this.jobs,
    required this.appliedJobIds,
    this.query = '',
    this.supervisorOnly = false,
  });

  final List<JobOpportunity> jobs;
  final Set<String> appliedJobIds;
  final String query;
  final bool supervisorOnly;

  List<JobOpportunity> get visibleJobs {
    final normalized = query.trim().toLowerCase();
    return jobs.where((job) {
      final matchesQuery =
          normalized.isEmpty ||
          job.title.toLowerCase().contains(normalized) ||
          job.location.toLowerCase().contains(normalized);
      return matchesQuery && (!supervisorOnly || job.isSupervisorRole);
    }).toList();
  }

  JobsState copyWith({
    Set<String>? appliedJobIds,
    String? query,
    bool? supervisorOnly,
  }) {
    return JobsState(
      jobs: jobs,
      appliedJobIds: appliedJobIds ?? this.appliedJobIds,
      query: query ?? this.query,
      supervisorOnly: supervisorOnly ?? this.supervisorOnly,
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
    final jobs = (await ref.read(jobsRepositoryProvider).loadJobs()).when(
      success: (value) => value,
      failure: (failure) => throw failure,
    );
    final applied =
        (await ref
                .read(jobsRepositoryProvider)
                .readAppliedJobIds(session.candidateId))
            .when(
              success: (value) => value,
              failure: (failure) => throw failure,
            );
    return JobsState(jobs: jobs, appliedJobIds: applied);
  }

  void search(String query) {
    final value = state.valueOrNull;
    if (value != null) state = AsyncData(value.copyWith(query: query));
  }

  void toggleSupervisorOnly() {
    final value = state.valueOrNull;
    if (value != null) {
      state = AsyncData(value.copyWith(supervisorOnly: !value.supervisorOnly));
    }
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
              .track(AnalyticsEvent.mockApplicationCreated()),
        );
        return null;
      },
      failure: (failure) => failure,
    );
  }

  void retry() => ref.invalidateSelf();
}
