import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/resume_parsing_repository.dart';

/// Config-gated fallback when no live backend is configured. Unlike
/// `LocalDemoCoachRepository`, there's no honest canned substitute for
/// "parse arbitrary resume text" the way there is for a canned coaching
/// reply -- a fake extraction would misrepresent itself as read from the
/// candidate's own resume when it wasn't. This says so plainly instead.
class UnavailableResumeParsingRepository implements ResumeParsingRepository {
  const UnavailableResumeParsingRepository();

  @override
  Future<Result<ResumeParseResult>> parse(ResumeParseRequest request) async {
    return const ResultFailure(
      UnexpectedFailure(
        'Resume parsing needs a configured backend and is not available '
        'in this build.',
      ),
    );
  }
}
