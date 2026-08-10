import '../../career_passport/domain/role_readiness.dart';
import 'jobs_repository.dart';

/// Maps a job onto the same 4 operational areas Role Readiness already
/// reports against, so [deriveJobMatch] can reuse
/// [RoleReadinessSummary] directly instead of re-deriving evidence fit
/// from scratch. Supervisor-flagged jobs win over the title's role bucket
/// (a "Warehouse Supervisor" posting is read as a Supervisor-track role,
/// not a Receiving one). Jobs with no clear mapping (an "other"-bucket,
/// non-supervisor title) return null -- [deriveJobMatch] treats that as
/// "no evidence signal available", not as a penalty.
ReadinessCategory? readinessCategoryForJob(JobOpportunity job) {
  if (job.isSupervisorRole) return ReadinessCategory.supervisor;
  switch (jobRoleBucket(job.title)) {
    case JobRoleBucket.warehouse:
    case JobRoleBucket.inventory:
      return ReadinessCategory.receiving;
    case JobRoleBucket.dispatch:
      return ReadinessCategory.dispatch;
    case JobRoleBucket.other:
      return null;
  }
}

const _recencyWindow = Duration(days: 14);

/// A 1-99 fit score for [job], computed client-side the same way Role
/// Readiness and Shift Match are: from data the app already has loaded, no
/// extra network call. Weighted toward what actually predicts whether a
/// candidate should look at this job first:
///
/// - **Evidence fit** (up to 30): does the candidate's Career Passport show
///   real readiness for the operational area this job is in?
/// - **Location** (up to 34): does the job sit in the candidate's
///   preferred city (from Shift availability -- the one place this app
///   already asks a candidate where they want to work)?
/// - **Verified employer** (9): a Flora-native listing is faster and more
///   certain to apply to than an aggregator one.
/// - **Recency** (5): a listing posted in the last two weeks is more
///   likely to still be open.
///
/// A flat baseline (5) keeps a job with zero known signal from reading as
/// "0% -- you don't qualify" -- it means "we don't have a signal yet", not
/// a rejection. Capped to keep every band (baseline through a perfect
/// score) inside 1-99, leaving 100 unclaimed so nothing ever reads as a
/// guaranteed fit.
int deriveJobMatch(
  JobOpportunity job, {
  required List<RoleReadinessSummary> readiness,
  required String? preferredCity,
  DateTime? now,
}) {
  var score = 5;

  final category = readinessCategoryForJob(job);
  if (category != null) {
    final summary = readiness.where((r) => r.category == category).firstOrNull;
    switch (summary?.level) {
      case ReadinessLevel.ready:
        score += 30;
      case ReadinessLevel.developing:
        score += 18;
      case ReadinessLevel.needsPractice:
        score += 8;
      case ReadinessLevel.unknown:
      case null:
        break;
    }
  }

  final city = preferredCity?.trim().toLowerCase();
  if (city != null &&
      city.isNotEmpty &&
      job.location.toLowerCase().contains(city)) {
    score += 34;
  }

  if (job.source == 'flora') score += 9;

  final publishedAt = job.publishedAt;
  if (publishedAt != null) {
    final reference = now ?? DateTime.now();
    if (reference.difference(publishedAt) <= _recencyWindow) score += 5;
  }

  return score.clamp(1, 99);
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
