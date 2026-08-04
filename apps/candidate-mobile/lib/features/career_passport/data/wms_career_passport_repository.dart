import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../certification_exam/domain/certification_exam_evidence_generation_service.dart';
import '../../certification_exam/domain/certification_exam_repository.dart';
import '../../micro_lessons/domain/micro_lesson_assessment_repository.dart';
import '../../micro_lessons/domain/micro_lesson_evidence_generation_service.dart';
import '../../workplace_simulation/application/workplace_simulation_controller.dart';
import '../../workplace_simulation/domain/simulation_repositories.dart';
import '../../workplace_simulation/domain/simulation_runtime.dart';
import '../domain/career_passport_repository.dart';

const _shareLinkPurpose = 'public_link';
const _shareLinkValidity = Duration(days: 30);
const _employerReviewPurpose = 'employer_review';

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
    MicroLessonAssessmentRepository? microLessonAssessmentRepository,
    CertificationExamRepository? certificationExamRepository,
    CertificationExamAttemptRepository? certificationExamAttemptRepository,
    SupabaseClient? supabaseClient,
    String? apiBaseUrl,
    Dio? dio,
  }) : _attemptRepository = attemptRepository,
       _microLessonAssessmentRepository = microLessonAssessmentRepository,
       _certificationExamRepository = certificationExamRepository,
       _certificationExamAttemptRepository = certificationExamAttemptRepository,
       _supabaseClient = supabaseClient,
       _apiBaseUrl = apiBaseUrl,
       _dio = dio ?? Dio();

  final SimulationAttemptRepository _attemptRepository;
  final MicroLessonAssessmentRepository? _microLessonAssessmentRepository;
  final CertificationExamRepository? _certificationExamRepository;
  final CertificationExamAttemptRepository? _certificationExamAttemptRepository;
  final SupabaseClient? _supabaseClient;
  final String? _apiBaseUrl;
  final Dio _dio;
  static const _microLessonEvidenceService =
      MicroLessonEvidenceGenerationService();
  static const _certificationExamEvidenceService =
      CertificationExamEvidenceGenerationService();

  @override
  bool get canManageShareLink =>
      _supabaseClient != null && _apiBaseUrl != null && _apiBaseUrl.isNotEmpty;

  @override
  bool get canManageEmployerAccess => canManageShareLink;

  @override
  Future<Result<List<EvidenceRecord>>> loadEvidence(String candidateId) async {
    final client = _supabaseClient;
    final wmsResult = client == null
        ? await _loadFromLocalHistory(candidateId)
        : await _loadFromSupabase(client, candidateId);
    return switch (wmsResult) {
      ResultFailure<List<EvidenceRecord>> failure => failure,
      Success<List<EvidenceRecord>>(value: final wmsEvidence) => Success([
        ...wmsEvidence,
        ...await _loadMicroLessonEvidence(candidateId),
        ...await _loadCertificationExamEvidence(candidateId),
      ]),
    };
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

  /// Micro-lesson assessment evidence is device-local only today (no
  /// remote sync yet), so it's merged in here unconditionally rather than
  /// being tucked inside [_loadFromLocalHistory] -- otherwise it would
  /// silently disappear from the Career Passport whenever Supabase is
  /// configured and [_loadFromSupabase] is the active WMS evidence path.
  /// Failing quietly (empty list) rather than failing the whole Career
  /// Passport load: this source is supplementary, not load-bearing.
  Future<List<EvidenceRecord>> _loadMicroLessonEvidence(
    String candidateId,
  ) async {
    final repository = _microLessonAssessmentRepository;
    if (repository == null) return const [];
    final result = await repository.listAttempts(candidateId);
    return result.when(
      success: (attempts) => [
        for (final attempt in attempts)
          ..._microLessonEvidenceService.generate(attempt),
      ],
      failure: (_) => const [],
    );
  }

  /// Certification exam evidence is device-local only today, same as
  /// micro-lesson assessments -- merged in unconditionally and failing
  /// quietly for the same reasons (see [_loadMicroLessonEvidence]).
  Future<List<EvidenceRecord>> _loadCertificationExamEvidence(
    String candidateId,
  ) async {
    final examRepository = _certificationExamRepository;
    final attemptRepository = _certificationExamAttemptRepository;
    if (examRepository == null || attemptRepository == null) return const [];
    final examResult = await examRepository.loadExam();
    return examResult.when(
      success: (exam) async {
        final attemptsResult = await attemptRepository.listAttempts(
          candidateId,
          exam.id,
        );
        return attemptsResult.when(
          success: (attempts) => [
            for (final attempt in attempts)
              ..._certificationExamEvidenceService.generate(attempt, exam),
          ],
          failure: (_) => const <EvidenceRecord>[],
        );
      },
      failure: (_) async => const <EvidenceRecord>[],
    );
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

  @override
  Future<Result<List<EmployerAccessEntry>>> loadEmployerAccess(
    String candidateId,
  ) async {
    final client = _supabaseClient;
    final apiBaseUrl = _apiBaseUrl;
    if (client == null || apiBaseUrl == null || apiBaseUrl.isEmpty) {
      return const Success([]);
    }
    final accessToken = client.auth.currentSession?.accessToken;
    if (accessToken == null) {
      return const ResultFailure(
        AuthenticationFailure('Sign in again to manage employer access.'),
      );
    }
    try {
      final response = await _dio.get<Object?>(
        '$apiBaseUrl/career-passport/applied-employers',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final body = response.data;
      final employers = body is Map ? body['employers'] : null;
      if (employers is! List) {
        throw const FormatException('Unexpected applied-employers response');
      }
      final grantedIds = await _activeEmployerGrantIds(client, candidateId);
      return Success([
        for (final entry in employers.cast<Map<String, Object?>>())
          EmployerAccessEntry(
            employerId: entry['id']! as String,
            employerName: entry['name']! as String,
            granted: grantedIds.contains(entry['id']),
          ),
      ]);
    } on DioException catch (error, stackTrace) {
      return ResultFailure(
        NetworkFailure(
          'Employer access could not be loaded.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } on PostgrestException catch (error, stackTrace) {
      return ResultFailure(
        NetworkFailure(
          'Employer access could not be loaded.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<Set<String>> _activeEmployerGrantIds(
    SupabaseClient client,
    String candidateId,
  ) async {
    final rows = await client
        .from('career_passport_grants')
        .select('employer_id, expires_at')
        .eq('candidate_id', candidateId)
        .eq('purpose', _employerReviewPurpose)
        .filter('revoked_at', 'is', null);
    final now = DateTime.now();
    return {
      for (final row in (rows as List).cast<Map<String, Object?>>())
        if (row['expires_at'] == null ||
            DateTime.parse(row['expires_at']! as String).isAfter(now))
          row['employer_id']! as String,
    };
  }

  @override
  Future<Result<void>> grantEmployerAccess(
    String candidateId,
    String employerId,
  ) async {
    final client = _supabaseClient;
    if (client == null) {
      return const ResultFailure(
        StorageFailure('Employer access requires an account connection.'),
      );
    }
    try {
      final existing = await client
          .from('career_passport_grants')
          .select('id')
          .eq('candidate_id', candidateId)
          .eq('employer_id', employerId)
          .eq('purpose', _employerReviewPurpose)
          .filter('revoked_at', 'is', null)
          .limit(1);
      if ((existing as List).isNotEmpty) return const Success(null);
      await client.from('career_passport_grants').insert({
        'candidate_id': candidateId,
        'employer_id': employerId,
        'purpose': _employerReviewPurpose,
        'granted_at': DateTime.now().toUtc().toIso8601String(),
      });
      return const Success(null);
    } on PostgrestException catch (error, stackTrace) {
      return ResultFailure(
        NetworkFailure(
          'Employer access could not be granted.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void>> revokeEmployerAccess(
    String candidateId,
    String employerId,
  ) async {
    final client = _supabaseClient;
    if (client == null) {
      return const ResultFailure(
        StorageFailure('Employer access requires an account connection.'),
      );
    }
    try {
      await client
          .from('career_passport_grants')
          .update({'revoked_at': DateTime.now().toUtc().toIso8601String()})
          .eq('candidate_id', candidateId)
          .eq('employer_id', employerId)
          .eq('purpose', _employerReviewPurpose)
          .filter('revoked_at', 'is', null);
      return const Success(null);
    } on PostgrestException catch (error, stackTrace) {
      return ResultFailure(
        NetworkFailure(
          'Employer access could not be revoked.',
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
