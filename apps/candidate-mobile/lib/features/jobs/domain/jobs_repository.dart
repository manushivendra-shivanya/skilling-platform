import '../../../core/errors/result.dart';

class JobOpportunity {
  const JobOpportunity({
    required this.id,
    required this.title,
    required this.employer,
    required this.location,
    required this.isSupervisorRole,
    required this.description,
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

abstract interface class JobsRepository {
  Future<Result<List<JobOpportunity>>> loadJobs();

  Future<Result<Set<String>>> readAppliedJobIds(String candidateId);

  Future<Result<void>> saveApplication(String candidateId, String jobId);

  /// False for a local-only/demo repository; true once jobs are sourced
  /// from the real employer catalogue. Drives whether the UI describes
  /// this as demo content.
  bool get isLiveData;
}
