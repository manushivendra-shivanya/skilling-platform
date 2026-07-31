import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../workplace_simulation/application/workplace_simulation_controller.dart';
import '../../workplace_simulation/domain/simulation_enums.dart';
import '../../workplace_simulation/domain/simulation_repositories.dart';
import '../../workplace_simulation/domain/simulation_runtime.dart';
import '../domain/career_passport.dart';
import '../domain/career_passport_repository.dart';

/// v0.1 evidence source: the current (most recent) attempt result per known
/// WMS mission, read through the same [SimulationAttemptRepository] the
/// missions themselves use -- local-first, and already kept in sync with
/// the BFF when Supabase is configured. There is no cross-attempt history
/// yet; a candidate who retries a mission sees only their latest result.
const _knownMissionIds = [
  WorkplaceSimulationController.missionId,
  WorkplaceSimulationController.putAwayMissionId,
];

class WmsCareerPassportRepository implements CareerPassportRepository {
  WmsCareerPassportRepository({
    required SimulationAttemptRepository attemptRepository,
    SupabaseClient? supabaseClient,
  }) : _attemptRepository = attemptRepository,
       _supabaseClient = supabaseClient;

  final SimulationAttemptRepository _attemptRepository;
  final SupabaseClient? _supabaseClient;

  @override
  bool get canManageSharing => _supabaseClient != null;

  @override
  Future<Result<List<EvidenceRecord>>> loadEvidence(String candidateId) async {
    try {
      final evidence = <EvidenceRecord>[];
      for (final missionId in _knownMissionIds) {
        final attempt = await _attemptRepository.getActiveAttempt(
          candidateId,
          missionId,
        );
        if (attempt == null ||
            (attempt.state != MissionState.completed &&
                attempt.state != MissionState.evaluated)) {
          continue;
        }
        final result = await _attemptRepository.getResult(
          candidateId,
          attempt.id,
        );
        if (result != null) evidence.addAll(result.evidence);
      }
      return Success(evidence);
    } catch (error, stackTrace) {
      return ResultFailure(
        StorageFailure(
          'Your Career Passport evidence could not be loaded.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<bool>> isShareable(String candidateId) async {
    final client = _supabaseClient;
    if (client == null) return const Success(false);
    try {
      final rows = await client
          .from('consent_grants')
          .select('id')
          .eq('candidate_id', candidateId)
          .eq('purpose', CareerPassportConsentVersions.sharingPurpose)
          .filter('revoked_at', 'is', null)
          .limit(1);
      return Success((rows as List).isNotEmpty);
    } on PostgrestException catch (error, stackTrace) {
      return ResultFailure(
        NetworkFailure(
          'Your sharing preference could not be loaded.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void>> setShareable(String candidateId, bool shareable) async {
    final client = _supabaseClient;
    if (client == null) {
      return const ResultFailure(
        StorageFailure('Sharing requires an account connection.'),
      );
    }
    try {
      if (shareable) {
        await client.from('consent_grants').upsert({
          'candidate_id': candidateId,
          'purpose': CareerPassportConsentVersions.sharingPurpose,
          'policy_version': CareerPassportConsentVersions.sharingVersion,
          'granted_at': DateTime.now().toUtc().toIso8601String(),
          'revoked_at': null,
        }, onConflict: 'candidate_id,purpose,policy_version');
      } else {
        await client
            .from('consent_grants')
            .update({'revoked_at': DateTime.now().toUtc().toIso8601String()})
            .eq('candidate_id', candidateId)
            .eq('purpose', CareerPassportConsentVersions.sharingPurpose)
            .filter('revoked_at', 'is', null);
      }
      return const Success(null);
    } on PostgrestException catch (error, stackTrace) {
      return ResultFailure(
        NetworkFailure(
          'Your sharing preference could not be saved.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}
