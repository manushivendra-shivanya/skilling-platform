import 'dart:convert';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../workplace_simulation/application/workplace_simulation_controller.dart';
import '../../workplace_simulation/domain/simulation_repositories.dart';
import '../../workplace_simulation/domain/simulation_runtime.dart';
import '../domain/career_passport.dart';
import '../domain/career_passport_repository.dart';

const _shareLinkPurpose = 'public_link';
const _shareLinkValidity = Duration(days: 30);

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
    String? apiBaseUrl,
  }) : _attemptRepository = attemptRepository,
       _supabaseClient = supabaseClient,
       _apiBaseUrl = apiBaseUrl;

  final SimulationAttemptRepository _attemptRepository;
  final SupabaseClient? _supabaseClient;
  final String? _apiBaseUrl;

  @override
  bool get canManageSharing => _supabaseClient != null;

  @override
  bool get canManageShareLink =>
      _supabaseClient != null && _apiBaseUrl != null && _apiBaseUrl.isNotEmpty;

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

  @override
  Future<Result<ShareLink?>> loadShareLink(String candidateId) async {
    final client = _supabaseClient;
    final apiBaseUrl = _apiBaseUrl;
    if (client == null || apiBaseUrl == null || apiBaseUrl.isEmpty) {
      return const Success(null);
    }
    try {
      final rows = await client
          .from('career_passport_grants')
          .select('token, expires_at')
          .eq('candidate_id', candidateId)
          .eq('purpose', _shareLinkPurpose)
          .filter('revoked_at', 'is', null)
          .order('granted_at', ascending: false)
          .limit(1);
      final row = (rows as List).cast<Map<String, Object?>>().firstOrNull;
      if (row == null) return const Success(null);
      final expiresAt = DateTime.parse(row['expires_at']! as String);
      if (expiresAt.isBefore(DateTime.now())) return const Success(null);
      return Success(
        _shareLink(apiBaseUrl, row['token']! as String, expiresAt),
      );
    } on PostgrestException catch (error, stackTrace) {
      return ResultFailure(
        NetworkFailure(
          'Your share link could not be loaded.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<ShareLink>> createShareLink(String candidateId) async {
    final client = _supabaseClient;
    final apiBaseUrl = _apiBaseUrl;
    if (client == null || apiBaseUrl == null || apiBaseUrl.isEmpty) {
      return const ResultFailure(
        StorageFailure('Share links require an account connection.'),
      );
    }
    final existing = await loadShareLink(candidateId);
    final existingLink = existing.when(
      success: (value) => value,
      failure: (_) => null,
    );
    if (existingLink != null) return Success(existingLink);

    final token = _generateToken();
    final expiresAt = DateTime.now().toUtc().add(_shareLinkValidity);
    try {
      await client.from('career_passport_grants').insert({
        'candidate_id': candidateId,
        'purpose': _shareLinkPurpose,
        'token': token,
        'granted_at': DateTime.now().toUtc().toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
      });
      return Success(_shareLink(apiBaseUrl, token, expiresAt));
    } on PostgrestException catch (error, stackTrace) {
      return ResultFailure(
        NetworkFailure(
          'Your share link could not be created.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void>> revokeShareLink(String candidateId) async {
    final client = _supabaseClient;
    if (client == null) {
      return const ResultFailure(
        StorageFailure('Share links require an account connection.'),
      );
    }
    try {
      await client
          .from('career_passport_grants')
          .update({'revoked_at': DateTime.now().toUtc().toIso8601String()})
          .eq('candidate_id', candidateId)
          .eq('purpose', _shareLinkPurpose)
          .filter('revoked_at', 'is', null);
      return const Success(null);
    } on PostgrestException catch (error, stackTrace) {
      return ResultFailure(
        NetworkFailure(
          'Your share link could not be revoked.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  ShareLink _shareLink(String apiBaseUrl, String token, DateTime expiresAt) =>
      ShareLink(
        token: token,
        url: '$apiBaseUrl/career-passport/share/$token',
        expiresAt: expiresAt,
      );

  String _generateToken() {
    final bytes = List<int>.generate(32, (_) => _secureRandom.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static final _secureRandom = Random.secure();
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
