import '../../../core/errors/result.dart';
import 'detailed_candidate_profile.dart';

/// Reads/writes everything on the LinkedIn-style detailed profile page.
///
/// Contact info and skills are saved as one call (they live on the same
/// `candidate_profiles` row as the rest of onboarding). Each of the four
/// list sections gets its own upsert/delete pair rather than a single
/// "save the whole profile" call: a candidate adding one work-experience
/// entry shouldn't have to resend their entire education/projects/
/// certifications history to do it, and a bulk-replace would need to
/// diff against the server's current rows to know what to delete anyway.
abstract interface class DetailedProfileRepository {
  Future<Result<DetailedCandidateProfile>> load(String candidateId);

  Future<Result<void>> saveContactAndSkills(
    String candidateId, {
    required String phone,
    required String email,
    required List<String> skills,
  });

  /// Inserts when [entry.id] is empty, updates otherwise.
  Future<Result<void>> upsertWorkExperience(
    String candidateId,
    WorkExperienceEntry entry,
  );
  Future<Result<void>> deleteWorkExperience(String candidateId, String id);

  Future<Result<void>> upsertEducation(
    String candidateId,
    EducationEntry entry,
  );
  Future<Result<void>> deleteEducation(String candidateId, String id);

  Future<Result<void>> upsertCertification(
    String candidateId,
    ExternalCertificationEntry entry,
  );
  Future<Result<void>> deleteCertification(String candidateId, String id);

  Future<Result<void>> upsertProject(String candidateId, ProjectEntry entry);
  Future<Result<void>> deleteProject(String candidateId, String id);
}
