import '../../../core/errors/result.dart';

class JobOpportunity {
  const JobOpportunity({
    required this.id,
    required this.title,
    required this.employer,
    required this.location,
    required this.isSupervisorRole,
    required this.description,
    required this.source,
    this.applyUrl,
    this.publishedAt,
  });

  final String id;
  final String title;
  final String employer;
  final String location;

  /// Derived from the job title (contains "supervisor"/"lead"/"manager")
  /// when sourced from the real catalogue -- there is no role-level field
  /// for this in the `jobs`/`role_profiles` schema today.
  final bool isSupervisorRole;
  final String description;

  /// `'flora'` for direct employer postings and the local demo catalogue;
  /// `'adzuna'`/`'jooble'`/`'careerjet'`/`'greenhouse'`/`'lever'` for
  /// aggregator-sourced listings synced by the API's `JobSyncService`.
  final String source;

  /// Null for Flora-native jobs (the internal one-click apply flow
  /// applies). Set for every aggregator-sourced job -- there is no real
  /// Flora employer behind those listings to receive an internal
  /// application, so the candidate is sent to the real listing instead.
  final String? applyUrl;

  /// Null for the local demo catalogue and for any real row that somehow
  /// has no `published_at` (treated as "unknown recency", never as "just
  /// posted") -- see [jobPostedLabel] and the "Date posted" filter.
  final DateTime? publishedAt;
}

/// Coarse, keyword-derived grouping used for the "Role type" filter and for
/// [deriveJobMatch]'s fit-against-evidence signal. Mirrors
/// [jobTitleLooksLikeSupervisorRole]'s own reasoning: there is no role-level
/// field in the `jobs` schema today, so this reads the title the same way a
/// human scanning the list would, rather than claiming a precise taxonomy.
enum JobRoleBucket { warehouse, dispatch, inventory, other }

const _roleBucketKeywords = {
  JobRoleBucket.dispatch: ['dispatch', 'delivery', 'logistics', 'route'],
  JobRoleBucket.inventory: ['inventory', 'stock'],
  JobRoleBucket.warehouse: ['warehouse', 'receiving', 'put-away', 'putaway'],
};

/// Checked in the order dispatch -> inventory -> warehouse so a title
/// mentioning both ("Warehouse & Logistics In-Charge") lands on the more
/// specific operational area (dispatch/logistics) rather than the generic
/// "warehouse" catch-all.
JobRoleBucket jobRoleBucket(String title) {
  final normalized = title.toLowerCase();
  for (final bucket in [
    JobRoleBucket.dispatch,
    JobRoleBucket.inventory,
    JobRoleBucket.warehouse,
  ]) {
    if (_roleBucketKeywords[bucket]!.any(normalized.contains)) return bucket;
  }
  return JobRoleBucket.other;
}

/// "12d ago" / "5w ago" / "3mo ago" style label, matching the density a
/// scannable job list needs (not a full date). Null [publishedAt] reads as
/// "Recently listed" rather than a blank -- this app never fabricates a
/// posting date it doesn't have.
String jobPostedLabel(DateTime? publishedAt, {DateTime? now}) {
  if (publishedAt == null) return 'Recently listed';
  final reference = now ?? DateTime.now();
  final days = reference.difference(publishedAt).inDays;
  if (days <= 0) return 'Today';
  if (days == 1) return '1d ago';
  if (days < 7) return '${days}d ago';
  if (days < 30) return '${(days / 7).floor()}w ago';
  if (days < 365) return '${(days / 30).floor()}mo ago';
  return '${(days / 365).floor()}y ago';
}

/// Consent purposes/versions the Jobs feature grants directly against
/// Supabase, mirroring `OnboardingConsentVersions`' upsert pattern.
abstract final class JobsConsentVersions {
  static const employerSharingPurpose = 'employer_sharing';
  static const employerSharingVersion = '2026-07-v1';
}

const _supervisorTitleKeywords = ['supervisor', 'lead', 'manager'];

/// True if [title] reads as a supervisor-level role. There is no role-level
/// field for this in the `jobs`/`role_profiles` schema today, so this is a
/// deliberately simple, visible categorisation rule rather than a claim
/// about the role's actual seniority or reporting structure.
bool jobTitleLooksLikeSupervisorRole(String title) {
  final normalized = title.toLowerCase();
  return _supervisorTitleKeywords.any(normalized.contains);
}

const _sourceDisplayNames = {
  'adzuna': 'Adzuna',
  'jooble': 'Jooble',
  'careerjet': 'Careerjet',
  'greenhouse': 'Employer careers page',
  'lever': 'Employer careers page',
};

/// The human-readable name for an aggregator [source] (`'Adzuna'`,
/// `'Jooble'`, ...), or null for `'flora'`/an unrecognised value. Used both
/// by [jobSourceCaption] and directly by the external-apply button label
/// ("View & apply on Adzuna").
String? jobSourceDisplayName(String source) => _sourceDisplayNames[source];

/// Null for `'flora'` (Flora's own listings -- direct employer postings,
/// or the local demo catalogue) -- no caption needed for the default,
/// unmarked case. Non-null for anything sourced from an external
/// aggregator, so a candidate always knows when a listing didn't come
/// directly from a verified Flora employer.
String? jobSourceCaption(String source) {
  final name = jobSourceDisplayName(source);
  return name == null ? null : 'via $name';
}

abstract interface class JobsRepository {
  Future<Result<List<JobOpportunity>>> loadJobs();

  Future<Result<Set<String>>> readAppliedJobIds(String candidateId);

  Future<Result<void>> saveApplication(String candidateId, String jobId);

  /// False for a local-only/demo repository; true once jobs are sourced
  /// from the real employer catalogue. Drives whether the UI describes
  /// this as demo content.
  bool get isLiveData;
}
