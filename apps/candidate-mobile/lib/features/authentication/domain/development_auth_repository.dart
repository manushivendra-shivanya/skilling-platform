import '../../../core/errors/result.dart';
import '../../../core/repositories/candidate_session_repository.dart';

class OtpChallenge {
  const OtpChallenge({
    required this.id,
    required this.contact,
    required this.expiresAt,
    required this.resendAvailableAt,
  });

  final String id;

  /// The verified email address this challenge was issued for. Named
  /// generically rather than `email` because the mock implementation reuses
  /// this same shape for its offline development flow.
  final String contact;
  final DateTime expiresAt;
  final DateTime resendAvailableAt;
}

abstract interface class DevelopmentAuthRepository {
  Future<Result<OtpChallenge>> requestOtp(String email);

  Future<Result<CandidateSession>> verifyOtp({
    required OtpChallenge challenge,
    required String otp,
  });
}
