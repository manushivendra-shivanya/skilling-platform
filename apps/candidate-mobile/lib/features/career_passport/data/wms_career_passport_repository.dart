import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../workplace_simulation/application/workplace_simulation_controller.dart';
import '../../workplace_simulation/domain/simulation_repositories.dart';
import '../../workplace_simulation/domain/simulation_runtime.dart';
import '../domain/career_passport.dart';
import '../domain/career_passport_repository.dart';

/// Evidence history across every attempt on each known WMS mission, not
/// just the current one -- retakes accumulate, they never replace an
/// earlier record. When Supabase is configured this reads the candidate's
/// full `wms_competency_evidence` history directly (RLS-scoped, mirroring
/// the existing direct-read pattern used for consent grants); otherwise it
/// falls back to this device's local attempt history via
/// [SimulationAttemptRepository.listResults].
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
  Future<Result<List<EvidenceRecord>>> loadEvidence(String candidateId) {
    final client = _supabaseClient;
    return client == null
        ? _loadFromLocalHistory(candidateId)
        : _loadFromSupabase(client, candidateId);
  }

  Future<Result<List<EvidenceRecord>>> _loadFromLocalHistory(
    String candidateId,
  ) async {
    try {
      final evidence = <EvidenceRecord>[];
      for (final missionId in _knownMissionIds) {
        final results = await _attemptRepository.listResults(
          candidateId,
          missionId,
        );
        for (final result in results) {
          evidence.addAll(result.evidence);
        }
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

  Future<Result<List<EvidenceRecord>>> _loadFromSupabase(
    SupabaseClient client,
    String candidateId,
  ) async {
    try {
      final rows = await client
          .from('wms_competency_evidence')
          .select('evidence')
          .eq('candidate_id', candidateId)
          .order('issued_at', ascending: false);
      final evidence = [
        for (final row in (rows as List).cast<Map<String, Object?>>())
          EvidenceRecord.fromJson(
            (row['evidence'] as Map).cast<String, Object?>(),
          ),
      ];
      return Success(evidence);
    } on PostgrestException catch (error, stackTrace) {
      return ResultFailure(
        NetworkFailure(
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
