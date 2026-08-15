import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/resume_parsing_repository.dart';

/// Config-gated fallback when no live backend is configured. Unlike
/// `LocalDemoCoachRepository`, there's no honest canned substitute for
/// "parse arbitrary resume text" the way there is for a canned coaching
/// reply -- a fake extraction would misrepresent itself as read from the
/// candidate's own resume when it wasn't. This says so plainly instead.
///
/// [ServiceUnavailableFailure], not [UnexpectedFailure]: the message
/// below is developer-facing only (see `AppFailureLocalization`), so the
/// only thing the candidate ever sees is the *type's* localized copy.
/// "Temporarily unavailable" is at least true and non-alarming for a
/// build that simply has no backend wired up; "something unexpected went
/// wrong" reads as a crash.
class UnavailableResumeParsingRepository implements ResumeParsingRepository {
  const UnavailableResumeParsingRepository();

  @override
  Future<Result<ResumeParseResult>> parse(ResumeParseRequest request) async =>
      _unavailable;

  @override
  Future<Result<ResumeParseResult>> parseDocument(
    ResumeDocumentParseRequest request,
  ) async => _unavailable;

  static const _unavailable = ResultFailure<ResumeParseResult>(
    ServiceUnavailableFailure(
      'Resume parsing needs a configured backend and is not available '
      'in this build.',
    ),
  );
}
