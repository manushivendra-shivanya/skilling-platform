import '../domain/jobs_repository.dart';

/// `forYou` ranks the full catalogue by [JobOpportunity]-vs-candidate fit
/// (see `deriveJobMatch`); `all` shows the same catalogue in the backend's
/// own newest-first order, unranked. Neither tab hides jobs the other
/// shows -- ranking only changes order, never visibility, so a candidate
/// can always find something by switching tabs.
enum JobsTab { forYou, all }

enum DatePostedFilter { any, pastWeek, pastMonth }

/// The city segment of a free-text `location` ("Bhiwandi, Maharashtra" ->
/// "Bhiwandi"; "India" -> "India" when there's no comma to split on). Used
/// both to build the Location filter's option list and to match against it
/// -- kept here rather than as a stored column since aggregator listings
/// never have a normalised city field to filter on.
String jobCity(String location) => location.split(',').first.trim();

class JobFilters {
  const JobFilters({
    this.locations = const {},
    this.roles = const {},
    this.companies = const {},
    this.datePosted = DatePostedFilter.any,
  });

  static const empty = JobFilters();

  final Set<String> locations;

  /// `'warehouse'` / `'dispatch'` / `'inventory'` / `'supervisor'` --
  /// matched against [jobRoleBucket] plus [JobOpportunity.isSupervisorRole]
  /// in [matches] below, not a [JobRoleBucket] directly, since "supervisor"
  /// isn't itself a role bucket.
  final Set<String> roles;
  final Set<String> companies;
  final DatePostedFilter datePosted;

  int get activeCount =>
      locations.length +
      roles.length +
      companies.length +
      (datePosted == DatePostedFilter.any ? 0 : 1);

  bool get isEmpty => activeCount == 0;

  bool matches(JobOpportunity job, {required DateTime now}) {
    if (locations.isNotEmpty && !locations.contains(jobCity(job.location))) {
      return false;
    }
    if (roles.isNotEmpty) {
      final bucketMatches = roles.contains(jobRoleBucket(job.title).name);
      final supervisorMatches =
          roles.contains('supervisor') && job.isSupervisorRole;
      if (!bucketMatches && !supervisorMatches) return false;
    }
    if (companies.isNotEmpty && !companies.contains(job.employer)) {
      return false;
    }
    final publishedAt = job.publishedAt;
    if (datePosted == DatePostedFilter.pastWeek) {
      if (publishedAt == null || now.difference(publishedAt).inDays > 7) {
        return false;
      }
    }
    if (datePosted == DatePostedFilter.pastMonth) {
      if (publishedAt == null || now.difference(publishedAt).inDays > 30) {
        return false;
      }
    }
    return true;
  }

  JobFilters copyWith({
    Set<String>? locations,
    Set<String>? roles,
    Set<String>? companies,
    DatePostedFilter? datePosted,
  }) => JobFilters(
    locations: locations ?? this.locations,
    roles: roles ?? this.roles,
    companies: companies ?? this.companies,
    datePosted: datePosted ?? this.datePosted,
  );
}

/// A job paired with its computed match score, ready for the list to
/// render without recomputing or re-deriving anything -- see
/// `JobsState.visibleJobs`.
class JobListItem {
  const JobListItem({required this.job, required this.matchScore});

  final JobOpportunity job;
  final int matchScore;
}
