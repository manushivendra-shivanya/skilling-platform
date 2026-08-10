import 'package:candidate_mobile/features/authentication/data/mock_development_auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('valid development OTP creates an authenticated session', () async {
    final repository = MockDevelopmentAuthRepository(true);
    final challengeResult = await repository.requestOtp(
      'Candidate@Example.com',
    );
    final challenge = challengeResult.when(
      success: (value) => value,
      failure: (failure) => throw failure,
    );

    final sessionResult = await repository.verifyOtp(
      challenge: challenge,
      otp: MockDevelopmentAuthRepository.developmentOtp,
    );

    expect(
      sessionResult.when(
        success: (session) => session.isAuthenticated,
        failure: (_) => false,
      ),
      isTrue,
    );
  });

  test('invalid email and incorrect OTP return clear failures', () async {
    final repository = MockDevelopmentAuthRepository(true);
    final invalidEmailResult = await repository.requestOtp('not-an-email');
    expect(
      invalidEmailResult.when(
        success: (_) => null,
        failure: (failure) => failure.message,
      ),
      contains('valid email'),
    );

    final challenge = (await repository.requestOtp(
      'candidate@example.com',
    )).when(success: (value) => value, failure: (failure) => throw failure);
    final invalidOtpResult = await repository.verifyOtp(
      challenge: challenge,
      otp: '000000',
    );
    expect(
      invalidOtpResult.when(
        success: (_) => null,
        failure: (failure) => failure.message,
      ),
      contains('incorrect'),
    );
  });

  test('expired OTP and production-disabled adapter fail safely', () async {
    var now = DateTime(2026, 7, 27, 12);
    final repository = MockDevelopmentAuthRepository(true, clock: () => now);
    final challenge = (await repository.requestOtp(
      'candidate@example.com',
    )).when(success: (value) => value, failure: (failure) => throw failure);

    now = now.add(const Duration(minutes: 3));
    final expiredResult = await repository.verifyOtp(
      challenge: challenge,
      otp: MockDevelopmentAuthRepository.developmentOtp,
    );
    expect(
      expiredResult.when(
        success: (_) => null,
        failure: (failure) => failure.message,
      ),
      contains('expired'),
    );

    final disabledResult = await MockDevelopmentAuthRepository(
      false,
    ).requestOtp('candidate@example.com');
    expect(
      disabledResult.when(
        success: (_) => null,
        failure: (failure) => failure.message,
      ),
      contains('unavailable in production'),
    );
  });
}
