import '../../../core/errors/result.dart';

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

class ResumeParseResult {
  const ResumeParseResult({
    required this.adapter,
    required this.fields,
    required this.requiresCandidateReview,
  });

  final String adapter;
  final Map<String, String> fields;
  final bool requiresCandidateReview;
}

abstract interface class ResumeParsingRepository {
  Future<Result<ResumeParseResult>> parse(ResumeParseRequest request);
}
