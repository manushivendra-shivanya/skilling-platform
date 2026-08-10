import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/repositories/candidate_session_repository.dart';
import '../domain/development_auth_repository.dart';

class MockDevelopmentAuthRepository implements DevelopmentAuthRepository {
  MockDevelopmentAuthRepository(this._enabled, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const developmentOtp = '123456';

  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  final bool _enabled;
  final DateTime Function() _clock;
  int _challengeSequence = 0;

  @override
  Future<Result<OtpChallenge>> requestOtp(String email) async {
    if (!_enabled) {
      return const ResultFailure(
        AuthenticationFailure(
          'Development email sign-in is unavailable in production builds.',
        ),
      );
    }

    final normalized = email.trim().toLowerCase();
    if (!_emailPattern.hasMatch(normalized)) {
      return const ResultFailure(
        ValidationFailure('Enter a valid email address.'),
      );
    }

    final now = _clock();
    _challengeSequence += 1;
    return Success(
      OtpChallenge(
        id: 'dev-otp-$_challengeSequence',
        contact: normalized,
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
          'Development email sign-in is unavailable in production builds.',
        ),
      );
    }
    if (!_clock().isBefore(challenge.expiresAt)) {
      return const ResultFailure(
        TimeoutFailure('This code has expired. Request a new one.'),
      );
    }
    if (otp != developmentOtp) {
      return const ResultFailure(
        AuthenticationFailure('That code is incorrect. Try 123456.'),
      );
    }

    return Success(
      CandidateSession(
        candidateId: 'dev-candidate-${challenge.contact.split('@').first}',
        isAuthenticated: true,
      ),
    );
  }
}
