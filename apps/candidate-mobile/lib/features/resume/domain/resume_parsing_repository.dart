import '../../../core/errors/result.dart';
import '../../profile_details/domain/detailed_candidate_profile.dart';

class ResumeParseRequest {
  const ResumeParseRequest({
    required this.candidateId,
    required this.resumeText,
    required this.consentVersion,
  });

  final String candidateId;

  /// Pasted/extracted resume text -- v1 works on plain text, not a
  /// stored file. A prior version of this contract had a
  /// `documentReference` field implying an already-uploaded file this
  /// repository would fetch and parse; that direction (pick a file,
  /// upload it to storage, parse the stored bytes) needs real
  /// infrastructure this app doesn't have yet (a storage bucket, upload
  /// UI, and either client- or server-side PDF/DOCX text extraction --
  /// see `apps/api/src/resume/gemini-resume-parser.ts`'s doc comment).
  /// Renamed rather than kept alongside a new field: this interface had
  /// no implementation and no call sites before this, so there was
  /// nothing to stay compatible with.
  final String resumeText;

  /// A per-action consent value, not a versioned platform consent
  /// (`OnboardingConsentVersions` covers terms/privacy only) -- see
  /// `ResumeUploadStep`'s doc comment for why.
  final String consentVersion;
}

/// A structured, interpreted extraction -- not a flat set of strings.
/// [education]/[workExperience]/[certifications]/[projects] reuse the
/// exact same entry types `DetailedProfileRepository` upserts, each with
/// `id: ''` (a fresh, not-yet-saved entry -- see those classes' own doc
/// comments on empty id meaning "insert"), so an extraction can be applied
/// directly via a loop of upsert calls with no conversion step in between.
///
/// [education]'s `degree`/`fieldOfStudy` split is where the backend's
/// interpretation shows up on this side: an abbreviation like "BTech CS"
/// on the resume arrives here already normalized into
/// `degree: "Bachelor of Technology"` / `fieldOfStudy: "Computer Science"`,
/// not the verbatim abbreviation -- see
/// `apps/api/src/resume/gemini-resume-parser.ts`'s prompt for exactly what
/// interpretation is (and isn't) asked of the model.
class ResumeParseResult {
  const ResumeParseResult({
    required this.adapter,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.city,
    required this.headline,
    required this.yearsOfExperience,
    required this.skills,
    required this.education,
    required this.workExperience,
    required this.certifications,
    required this.projects,
    required this.requiresCandidateReview,
  });

  final String adapter;
  final String fullName;
  final String phone;
  final String email;
  final String city;
  final String headline;
  final String yearsOfExperience;
  final List<String> skills;
  final List<EducationEntry> education;
  final List<WorkExperienceEntry> workExperience;
  final List<ExternalCertificationEntry> certifications;
  final List<ProjectEntry> projects;
  final bool requiresCandidateReview;

  /// True when the extraction found essentially nothing usable -- every
  /// scalar field empty and every list empty. Distinct from
  /// [requiresCandidateReview] (which only checks [fullName]): a resume
  /// missing a name but listing real work history is still worth
  /// reviewing entry-by-entry, not treated as a total miss.
  bool get isEffectivelyEmpty =>
      fullName.isEmpty &&
      phone.isEmpty &&
      email.isEmpty &&
      city.isEmpty &&
      headline.isEmpty &&
      skills.isEmpty &&
      education.isEmpty &&
      workExperience.isEmpty &&
      certifications.isEmpty &&
      projects.isEmpty;
}

abstract interface class ResumeParsingRepository {
  Future<Result<ResumeParseResult>> parse(ResumeParseRequest request);
}
