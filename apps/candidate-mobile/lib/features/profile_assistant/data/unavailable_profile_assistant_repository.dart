import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/profile_assistant_repository.dart';

/// Config-gated fallback when no live backend is configured. Same
/// reasoning as `UnavailableResumeParsingRepository`: a canned
/// conversation would misrepresent itself as a real assistant reading
/// this candidate's own profile. The gap list on the completion screen
/// still works without a backend -- it's a pure local computation -- so
/// only the conversation degrades, not the whole feature.
class UnavailableProfileAssistantRepository
    implements ProfileAssistantRepository {
  const UnavailableProfileAssistantRepository();

  @override
  Future<Result<AssistantReply>> continueConversation(
    AssistantTurnRequest request,
  ) async {
    return const ResultFailure(
      UnexpectedFailure(
        'The profile assistant needs a configured backend and is not '
        'available in this build.',
      ),
    );
  }
}
