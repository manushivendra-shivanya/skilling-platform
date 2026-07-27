import '../../../core/errors/result.dart';
import '../../../core/repositories/candidate_session_repository.dart';

class OtpChallenge {
  const OtpChallenge({
    required this.id,
    required this.phoneNumber,
    required this.expiresAt,
    required this.resendAvailableAt,
  });

  final String id;
  final String phoneNumber;
  final DateTime expiresAt;
  final DateTime resendAvailableAt;
}

abstract interface class DevelopmentAuthRepository {
  Future<Result<OtpChallenge>> requestOtp(String phoneNumber);

  Future<Result<CandidateSession>> verifyOtp({
    required OtpChallenge challenge,
    required String otp,
  });
}
