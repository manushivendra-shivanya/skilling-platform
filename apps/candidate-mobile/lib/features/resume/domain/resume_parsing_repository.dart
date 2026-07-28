import '../../../core/errors/result.dart';

class ResumeParseRequest {
  const ResumeParseRequest({
    required this.candidateId,
    required this.documentReference,
    required this.consentVersion,
  });

  final String candidateId;
  final String documentReference;
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
