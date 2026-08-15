import 'dart:typed_data';

import '../../../core/errors/result.dart';
import '../../profile_details/domain/detailed_candidate_profile.dart';

class ResumeParseRequest {
  const ResumeParseRequest({
    required this.candidateId,
    required this.resumeText,
    required this.consentVersion,
  });

  final String candidateId;

  /// Pasted resume text. A resume that exists as a PDF or Word file goes
  /// through [ResumeDocumentParseRequest] instead -- the file itself is
  /// sent, and nothing on this side tries to turn it into text first.
  final String resumeText;

  /// A per-action consent value, not a versioned platform consent
  /// (`OnboardingConsentVersions` covers terms/privacy only) -- see
  /// `ResumeUploadStep`'s doc comment for why.
  final String consentVersion;
}

/// A resume the candidate picked as a file instead of pasting.
///
/// The bytes are sent as-is to Flora's own API, which decides the format
/// from the file's own magic number and routes a PDF straight to the
/// model while extracting a .docx to text first (see
/// `apps/api/src/resume/resume.service.ts`). Nothing is uploaded to
/// storage and nothing is kept: the file makes one round trip inside the
/// parse request and is never persisted on either side.
///
/// Deliberately no client-side text extraction. A PDF resume is usually
/// two columns or a table, and every plain-text extractor interleaves
/// those into unreadable order -- sending the original file is what lets
/// the model see the page as laid out.
class ResumeDocumentParseRequest {
  const ResumeDocumentParseRequest({
    required this.candidateId,
    required this.fileName,
    required this.bytes,
    required this.consentVersion,
  });

  final String candidateId;

  /// What the picker called the file. Carried only so the server can word
  /// an error naturally -- the format is never inferred from it.
  final String fileName;

  final Uint8List bytes;

  /// Same per-action consent as [ResumeParseRequest.consentVersion].
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

  /// Parses an uploaded PDF or Word file. Returns the identical
  /// [ResumeParseResult] the pasted-text route does, so the review screen
  /// never branches on how the resume arrived.
  Future<Result<ResumeParseResult>> parseDocument(
    ResumeDocumentParseRequest request,
  );
}
