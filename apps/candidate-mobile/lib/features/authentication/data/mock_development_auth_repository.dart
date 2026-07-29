import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/repositories/candidate_session_repository.dart';
import '../domain/development_auth_repository.dart';

class MockDevelopmentAuthRepository implements DevelopmentAuthRepository {
  MockDevelopmentAuthRepository(this._enabled, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const developmentOtp = '123456';

  final bool _enabled;
  final DateTime Function() _clock;
  int _challengeSequence = 0;

  @override
  Future<Result<OtpChallenge>> requestOtp(String phoneNumber) async {
    if (!_enabled) {
      return const ResultFailure(
        AuthenticationFailure(
          'Development phone sign-in is unavailable in production builds.',
        ),
      );
    }

    final normalizedPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(normalizedPhone)) {
      return const ResultFailure(
        ValidationFailure('Enter a valid 10-digit Indian mobile number.'),
      );
    }

    final now = _clock();
    _challengeSequence += 1;
    return Success(
      OtpChallenge(
        id: 'dev-otp-$_challengeSequence',
        phoneNumber: normalizedPhone,
        expiresAt: now.add(const Duration(minutes: 2)),
        resendAvailableAt: now.add(const Duration(seconds: 30)),
      ),
    );
  }

  @override
  Future<Result<CandidateSession>> verifyOtp({
    required OtpChallenge challenge,
    required String otp,
  }) async {
    if (!_enabled) {
      return const ResultFailure(
        AuthenticationFailure(
          'Development phone sign-in is unavailable in production builds.',
        ),
      );
    }
    if (!_clock().isBefore(challenge.expiresAt)) {
      return const ResultFailure(
        TimeoutFailure('This OTP has expired. Request a new code.'),
      );
    }
    if (otp != developmentOtp) {
      return const ResultFailure(
        AuthenticationFailure('That OTP is incorrect. Try 123456.'),
      );
    }

    final lastFourDigits = challenge.phoneNumber.substring(6);
    return Success(
      CandidateSession(
        candidateId: 'dev-candidate-$lastFourDigits',
        isAuthenticated: true,
      ),
    );
  }
}
