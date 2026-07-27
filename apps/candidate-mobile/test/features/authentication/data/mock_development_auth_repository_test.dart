import 'package:candidate_mobile/features/authentication/data/mock_development_auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('valid development OTP creates an authenticated session', () async {
    final repository = MockDevelopmentAuthRepository(true);
    final challengeResult = await repository.requestOtp('98765 43210');
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

  test('invalid phone and incorrect OTP return clear failures', () async {
    final repository = MockDevelopmentAuthRepository(true);
    final invalidPhoneResult = await repository.requestOtp('123');
    expect(
      invalidPhoneResult.when(
        success: (_) => null,
        failure: (failure) => failure.message,
      ),
      contains('valid 10-digit'),
    );

    final challenge = (await repository.requestOtp(
      '9876543210',
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
      '9876543210',
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
    ).requestOtp('9876543210');
    expect(
      disabledResult.when(
        success: (_) => null,
        failure: (failure) => failure.message,
      ),
      contains('unavailable in production'),
    );
  });
}
