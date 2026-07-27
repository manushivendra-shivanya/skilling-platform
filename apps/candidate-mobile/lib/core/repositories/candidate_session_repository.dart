import '../errors/result.dart';

class CandidateSession {
  const CandidateSession({
    required this.candidateId,
    required this.isAuthenticated,
  });

  final String candidateId;
  final bool isAuthenticated;
}

abstract interface class CandidateSessionRepository {
  Future<Result<CandidateSession?>> readSession();

  Future<Result<void>> clearSession();
}

/// In-memory development adapter. It is deliberately not a production auth
/// implementation and stores no credentials.
class MockCandidateSessionRepository implements CandidateSessionRepository {
  CandidateSession? _session;

  @override
  Future<Result<void>> clearSession() async {
    _session = null;
    return const Success(null);
  }

  @override
  Future<Result<CandidateSession?>> readSession() async => Success(_session);

  void setSession(CandidateSession? session) {
    _session = session;
  }
}
