import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/repositories/candidate_session_repository.dart';
import '../domain/development_auth_repository.dart';

class SupabasePhoneAuthRepository implements DevelopmentAuthRepository {
  SupabasePhoneAuthRepository(this._client, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final SupabaseClient _client;
  final DateTime Function() _clock;

  @override
  Future<Result<OtpChallenge>> requestOtp(String phoneNumber) async {
    final normalizedPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(normalizedPhone)) {
      return const ResultFailure(
        ValidationFailure('Enter a valid 10-digit Indian mobile number.'),
      );
    }
    try {
      await _client.auth.signInWithOtp(phone: '+91$normalizedPhone');
      final now = _clock();
      return Success(
        OtpChallenge(
          id: 'supabase-phone-otp',
          phoneNumber: normalizedPhone,
          expiresAt: now.add(const Duration(minutes: 5)),
          resendAvailableAt: now.add(const Duration(seconds: 60)),
        ),
      );
    } on AuthException catch (error, stackTrace) {
      return ResultFailure(
        AuthenticationFailure(
          'We could not send the OTP. Please wait and try again.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<CandidateSession>> verifyOtp({
    required OtpChallenge challenge,
    required String otp,
  }) async {
    if (!_clock().isBefore(challenge.expiresAt)) {
      return const ResultFailure(
        TimeoutFailure('This OTP has expired. Request a new code.'),
      );
    }
    try {
      final response = await _client.auth.verifyOTP(
        type: OtpType.sms,
        token: otp,
        phone: '+91${challenge.phoneNumber}',
      );
      final user = response.user;
      if (user == null || response.session == null) {
        return const ResultFailure(
          AuthenticationFailure('OTP verification did not create a session.'),
        );
      }
      return Success(
        CandidateSession(candidateId: user.id, isAuthenticated: true),
      );
    } on AuthException catch (error, stackTrace) {
      return ResultFailure(
        AuthenticationFailure(
          'That OTP could not be verified. Check the code and try again.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}
