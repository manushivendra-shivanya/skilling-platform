import '../../../core/errors/result.dart';
import 'candidate_onboarding_draft.dart';

abstract interface class CandidateOnboardingRepository {
  Future<Result<CandidateOnboardingDraft>> readDraft(String candidateId);

  Future<Result<void>> saveDraft(
    String candidateId,
    CandidateOnboardingDraft draft,
  );
}
