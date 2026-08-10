import 'package:candidate_mobile/core/errors/app_failure.dart';
import 'package:candidate_mobile/core/errors/result.dart';
import 'package:candidate_mobile/features/career_passport/domain/career_passport_repository.dart';
import 'package:candidate_mobile/features/workplace_simulation/domain/simulation_runtime.dart';

/// Reports no evidence and no manageable share link/employer access --
/// enough for `CareerPassportController.build()` to resolve without
/// touching anything Supabase- or secure-storage-backed, since it skips
/// `loadShareLink`/`loadEmployerAccess` entirely when both `canManage*`
/// flags are false. Used by any test harness that reaches
/// `careerPassportControllerProvider` (directly, or transitively via
/// `JobsController`'s match-scoring) without going through
/// `pumpCandidateApp`, which already overrides this by default.
class NoEvidenceCareerPassportRepository implements CareerPassportRepository {
  const NoEvidenceCareerPassportRepository();

  @override
  Future<Result<List<EvidenceRecord>>> loadEvidence(String candidateId) async =>
      const Success([]);

  @override
  bool get canManageShareLink => false;

  @override
  Future<Result<ShareLink?>> loadShareLink(String candidateId) async =>
      const Success(null);

  @override
  Future<Result<ShareLink>> createShareLink(String candidateId) async =>
      const ResultFailure(StorageFailure('Not available in this test.'));

  @override
  Future<Result<void>> revokeShareLink(String candidateId) async =>
      const Success(null);

  @override
  bool get canManageEmployerAccess => false;

  @override
  Future<Result<List<EmployerAccessEntry>>> loadEmployerAccess(
    String candidateId,
  ) async => const Success([]);

  @override
  Future<Result<void>> grantEmployerAccess(
    String candidateId,
    String employerId,
  ) async => const Success(null);

  @override
  Future<Result<void>> revokeEmployerAccess(
    String candidateId,
    String employerId,
  ) async => const Success(null);
}
