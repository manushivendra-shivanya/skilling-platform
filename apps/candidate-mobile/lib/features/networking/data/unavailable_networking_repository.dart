import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/networking_repository.dart';

/// Config-gated fallback when no live backend is configured. Every
/// operation here needs a real, authoritative server (matching other
/// candidates against each other, enforcing blocks) -- there's no honest
/// local-only substitute the way `LocalDemoCoachRepository` has for a
/// single-candidate feature, so this says so plainly instead, same
/// posture as `UnavailableResumeParsingRepository`.
class UnavailableNetworkingRepository implements NetworkingRepository {
  const UnavailableNetworkingRepository();

  static const _message =
      'Candidate networking needs a configured backend and is not '
      'available in this build.';

  @override
  Future<Result<NetworkingProfile>> getMyProfile() async =>
      const ResultFailure(UnexpectedFailure(_message));

  @override
  Future<Result<NetworkingProfile>> publishProfile({
    required String fullName,
    required String headline,
    required String city,
    required String state,
    required List<String> preferredRoles,
    required bool discoverable,
  }) async => const ResultFailure(UnexpectedFailure(_message));

  @override
  Future<Result<List<DiscoveredCandidate>>> discover() async =>
      const ResultFailure(UnexpectedFailure(_message));

  @override
  Future<Result<void>> sendConnectionRequest(
    String recipientCandidateId,
  ) async => const ResultFailure(UnexpectedFailure(_message));

  @override
  Future<Result<ConnectionsOverview>> listConnections() async =>
      const ResultFailure(UnexpectedFailure(_message));

  @override
  Future<Result<void>> respondToConnection(
    String connectionId,
    bool accept,
  ) async => const ResultFailure(UnexpectedFailure(_message));

  @override
  Future<Result<void>> withdrawConnection(String connectionId) async =>
      const ResultFailure(UnexpectedFailure(_message));

  @override
  Future<Result<void>> blockCandidate(String candidateId) async =>
      const ResultFailure(UnexpectedFailure(_message));

  @override
  Future<Result<void>> unblockCandidate(String candidateId) async =>
      const ResultFailure(UnexpectedFailure(_message));
}
