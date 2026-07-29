import '../../../core/errors/result.dart';
import 'candidate_intelligence.dart';

abstract interface class CandidateIntelligenceRepository {
  Future<Result<CandidateIntelligenceState>> load(String candidateId);

  Future<Result<CandidateIntelligenceState>> save(
    String candidateId,
    CandidateIntelligenceState state,
  );
}
