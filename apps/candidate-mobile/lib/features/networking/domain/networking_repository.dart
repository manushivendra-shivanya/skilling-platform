import '../../../core/errors/result.dart';

/// The published snapshot of a candidate's Professional Persona -- see
/// `ProfessionalPersonaCard` in features/persona/. Publishing is the one
/// deliberate exception to that card's own data staying entirely
/// on-device; only what the candidate can already see on their own card
/// leaves the device, and only once they explicitly turn discoverability
/// on.
class NetworkingProfile {
  const NetworkingProfile({
    required this.discoverable,
    required this.fullName,
    required this.headline,
    required this.city,
    required this.state,
    required this.preferredRoles,
  });

  final bool discoverable;
  final String fullName;
  final String headline;
  final String city;
  final String state;
  final List<String> preferredRoles;
}

class DiscoveredCandidate {
  const DiscoveredCandidate({
    required this.candidateId,
    required this.fullName,
    required this.headline,
    required this.city,
    required this.state,
    required this.sharedRoles,
  });

  final String candidateId;
  final String fullName;
  final String headline;
  final String city;
  final String state;

  /// The preferred roles this candidate and the caller have in common --
  /// the reason they were surfaced at all (see
  /// `NetworkingService.discover`'s role-overlap matching).
  final List<String> sharedRoles;
}

enum ConnectionStatus { pending, accepted }

enum ConnectionDirection { incoming, outgoing }

class OtherCandidateSummary {
  const OtherCandidateSummary({
    required this.fullName,
    required this.headline,
    required this.city,
    required this.state,
  });

  final String fullName;
  final String headline;
  final String city;
  final String state;
}

class ConnectionSummary {
  const ConnectionSummary({
    required this.id,
    required this.status,
    required this.direction,
    required this.otherCandidateId,
    required this.otherCandidate,
    required this.createdAt,
  });

  final String id;
  final ConnectionStatus status;
  final ConnectionDirection direction;
  final String otherCandidateId;
  final OtherCandidateSummary? otherCandidate;
  final DateTime createdAt;
}

class ConnectionsOverview {
  const ConnectionsOverview({
    required this.accepted,
    required this.incomingPending,
    required this.outgoingPending,
  });

  const ConnectionsOverview.empty()
    : accepted = const [],
      incomingPending = const [],
      outgoingPending = const [];

  final List<ConnectionSummary> accepted;
  final List<ConnectionSummary> incomingPending;
  final List<ConnectionSummary> outgoingPending;
}

/// Candidate-to-candidate discovery and connections -- view-only for v1,
/// no in-app messaging (see `apps/api/src/networking/networking.service
/// .ts`'s doc comment for why that's a deliberate boundary, not an
/// oversight). Implemented by `ApiNetworkingRepository` (real backend)
/// and `UnavailableNetworkingRepository` (config-gated fallback), same
/// posture as `ResumeParsingRepository`.
abstract interface class NetworkingRepository {
  /// The candidate's own currently-persisted networking profile, including
  /// [NetworkingProfile.discoverable] -- the real read path
  /// `NetworkingSection` needs so its switch reflects the candidate's
  /// actual setting on first build instead of a hardcoded guess. Backed by
  /// `GET /v1/networking/profile`; see `NetworkingService.getMyProfile`'s
  /// doc comment for what a candidate who has never published gets back.
  Future<Result<NetworkingProfile>> getMyProfile();

  Future<Result<NetworkingProfile>> publishProfile({
    required String fullName,
    required String headline,
    required String city,
    required String state,
    required List<String> preferredRoles,
    required bool discoverable,
  });

  Future<Result<List<DiscoveredCandidate>>> discover();

  Future<Result<void>> sendConnectionRequest(String recipientCandidateId);

  Future<Result<ConnectionsOverview>> listConnections();

  Future<Result<void>> respondToConnection(String connectionId, bool accept);

  Future<Result<void>> withdrawConnection(String connectionId);

  Future<Result<void>> blockCandidate(String candidateId);

  Future<Result<void>> unblockCandidate(String candidateId);
}
