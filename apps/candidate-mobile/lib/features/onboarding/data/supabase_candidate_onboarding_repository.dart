import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/candidate_onboarding_draft.dart';
import '../domain/candidate_onboarding_repository.dart';

class SupabaseCandidateOnboardingRepository
    implements CandidateOnboardingRepository {
  SupabaseCandidateOnboardingRepository(
    this._client, {
    Duration callTimeout = const Duration(seconds: 12),
  }) : _callTimeout = callTimeout;

  final SupabaseClient _client;
  final Duration _callTimeout;

  // This repository sits directly in the post-sign-in redirect path (see
  // `_redirectForCandidateState` in app_router.dart), which runs on every
  // navigation once a candidate is authenticated. Unlike the secure-storage
  // path, a Postgrest call has no built-in timeout of its own -- a slow or
  // momentarily-dropped connection right after the OAuth round-trip (a
  // plausible moment for exactly that) would otherwise hang the redirect
  // forever with no error shown and no way back. Bounding it turns that into
  // a normal, recoverable `NetworkFailure` the redirect already handles.
  @override
  Future<Result<CandidateOnboardingDraft>> readDraft(String candidateId) async {
    try {
      final profile = await _client
          .from('candidate_profiles')
          .select()
          .eq('candidate_id', candidateId)
          .maybeSingle()
          .timeout(_callTimeout);
      if (profile == null) {
        return const Success(CandidateOnboardingDraft());
      }
      final consentRows = await _client
          .from('consent_grants')
          .select()
          .eq('candidate_id', candidateId)
          .isFilter('revoked_at', null)
          .timeout(_callTimeout);
      final consents = <String, ConsentAcceptance>{};
      for (final row in consentRows) {
        final purpose = row['purpose'];
        final version = row['policy_version'];
        final acceptedAt = row['granted_at'];
        if (purpose is String && version is String && acceptedAt is String) {
          consents[purpose] = ConsentAcceptance(
            purpose: purpose,
            version: version,
            acceptedAt: DateTime.parse(acceptedAt),
          );
        }
      }
      return Success(
        CandidateOnboardingDraft(
          currentStep: profile['current_step'] as int? ?? 0,
          goal: CandidateGoal.fromId(profile['goal']),
          fullName: profile['display_name'] as String? ?? '',
          city: profile['city'] as String? ?? '',
          state: profile['state'] as String? ?? '',
          pinCode: profile['pin_code'] as String? ?? '',
          education: EducationLevel.fromId(profile['education_level']),
          experience: ExperienceLevel.fromId(profile['experience_level']),
          preferredRoles:
              (profile['preferred_role_codes'] as List<Object?>? ?? const [])
                  .map(LogisticsRole.fromId)
                  .whereType<LogisticsRole>()
                  .toSet(),
          consents: consents,
          isCompleted: profile['onboarding_completed'] as bool? ?? false,
        ),
      );
    } on PostgrestException catch (error, stackTrace) {
      return ResultFailure(
        NetworkFailure(
          'Your profile could not be loaded. Check your connection and retry.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } on TimeoutException catch (error, stackTrace) {
      return ResultFailure(
        NetworkFailure(
          'Your profile could not be loaded. Check your connection and retry.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void>> saveDraft(
    String candidateId,
    CandidateOnboardingDraft draft,
  ) async {
    try {
      await _client
          .from('candidate_profiles')
          .upsert({
            'candidate_id': candidateId,
            'display_name': draft.fullName,
            'city': draft.city,
            'state': draft.state,
            'pin_code': draft.pinCode,
            'goal': draft.goal?.id,
            'education_level': draft.education?.id,
            'experience_level': draft.experience?.id,
            'preferred_role_codes': draft.preferredRoles
                .map((role) => role.id)
                .toList(),
            'current_step': draft.currentStep,
            'onboarding_completed': draft.isCompleted,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }, onConflict: 'candidate_id')
          .timeout(_callTimeout);
      for (final consent in draft.consents.values) {
        await _client
            .from('consent_grants')
            .upsert({
              'candidate_id': candidateId,
              'purpose': consent.purpose,
              'policy_version': consent.version,
              'granted_at': consent.acceptedAt.toUtc().toIso8601String(),
              'revoked_at': null,
            }, onConflict: 'candidate_id,purpose,policy_version')
            .timeout(_callTimeout);
      }
      return const Success(null);
    } on PostgrestException catch (error, stackTrace) {
      return ResultFailure(
        NetworkFailure(
          'Your profile could not be synced. Your details remain on this screen.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } on TimeoutException catch (error, stackTrace) {
      return ResultFailure(
        NetworkFailure(
          'Your profile could not be synced. Your details remain on this screen.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}
