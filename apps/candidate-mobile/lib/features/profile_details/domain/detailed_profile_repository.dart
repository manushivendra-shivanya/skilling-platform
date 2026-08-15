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

  /// Saves the identity/about fields that live as plain columns on
  /// `candidate_profiles`, the same row [saveContactAndSkills] writes to
  /// -- kept as its own call rather than folded into that one so a
  /// caller that only has one or the other (e.g. resume import writing
  /// contact info and headline/summary from two different extraction
  /// steps) never has to resend fields it doesn't have a value for.
  Future<Result<void>> saveProfileBasics(
    String candidateId, {
    required String headline,
    required String summary,
    required String totalExperience,
  });

  /// Saves every career-preference field as one call -- see
  /// [CareerPreferences]'s own doc comment for why this is one aggregate
  /// rather than per-field upserts.
  Future<Result<void>> saveCareerPreferences(
    String candidateId,
    CareerPreferences preferences,
  );

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

  Future<Result<void>> upsertLanguage(String candidateId, LanguageEntry entry);
  Future<Result<void>> deleteLanguage(String candidateId, String id);
}
