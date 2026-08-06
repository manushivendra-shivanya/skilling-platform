import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/jobs_repository.dart';

/// Job listing, applied-job tracking and applications all go through the
/// real NestJS BFF (`apps/api`) and Supabase. The config-gated fallback
/// (see `isLiveData`) is a separate [JobsRepository] implementation,
/// `LocalMockJobsRepository`, not something this class delegates to.
class ApiJobsRepository implements JobsRepository {
  ApiJobsRepository({
    required Dio dio,
    required SupabaseClient supabaseClient,
    required String apiBaseUrl,
  }) : _dio = dio,
       _supabaseClient = supabaseClient,
       _apiBaseUrl = apiBaseUrl;

  final Dio _dio;
  final SupabaseClient _supabaseClient;
  final String _apiBaseUrl;

  @override
  bool get isLiveData => true;

  @override
  Future<Result<List<JobOpportunity>>> loadJobs() async {
    final accessToken = _supabaseClient.auth.currentSession?.accessToken;
    if (accessToken == null) {
      return const ResultFailure(
        AuthenticationFailure('Sign in again to view jobs.'),
      );
    }
    try {
      final response = await _dio.get<Object?>(
        '$_apiBaseUrl/jobs',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final body = response.data;
      final jobs = body is Map ? body['jobs'] : null;
      if (jobs is! List) {
        throw const FormatException('Unexpected jobs response shape');
      }
      return Success([
        for (final entry in jobs.cast<Map<String, Object?>>()) _fromJson(entry),
      ]);
    } on DioException catch (error, stackTrace) {
      return ResultFailure(_mapError(error, stackTrace));
    } catch (error, stackTrace) {
      return ResultFailure(
        UnexpectedFailure(
          'Jobs could not be loaded.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<Set<String>>> readAppliedJobIds(String candidateId) async {
    final accessToken = _supabaseClient.auth.currentSession?.accessToken;
    if (accessToken == null) {
      return const ResultFailure(
        AuthenticationFailure('Sign in again to view your applications.'),
      );
    }
    try {
      final response = await _dio.get<Object?>(
        '$_apiBaseUrl/jobs/applications',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final body = response.data;
      final jobIds = body is Map ? body['jobIds'] : null;
      if (jobIds is! List) {
        throw const FormatException('Unexpected applications response shape');
      }
      return Success(jobIds.whereType<String>().toSet());
    } on DioException catch (error, stackTrace) {
      return ResultFailure(_mapError(error, stackTrace));
    } catch (error, stackTrace) {
      return ResultFailure(
        UnexpectedFailure(
          'Your applications could not be loaded.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void>> saveApplication(String candidateId, String jobId) async {
    final accessToken = _supabaseClient.auth.currentSession?.accessToken;
    if (accessToken == null) {
      return const ResultFailure(
        AuthenticationFailure('Sign in again to apply for this job.'),
      );
    }
    // The apply screen only enables its button once the candidate has
    // confirmed sharing their profile with the employer -- granting the
    // consent here, immediately before the apply call it gates, keeps that
    // confirmation meaningful without threading UI state through the
    // repository layer.
    final consentGranted = await _grantEmployerSharingConsent(candidateId);
    if (consentGranted != null) return ResultFailure(consentGranted);
    try {
      await _dio.post<Object?>(
        '$_apiBaseUrl/jobs/$jobId/applications',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            // Deterministic per candidate/job so a retry of the same tap
            // reuses the same key; the server's unique (job_id, candidate_id)
            // constraint is what actually guarantees no duplicate is created.
            'Idempotency-Key': 'jobs-apply.$candidateId.$jobId',
          },
        ),
      );
    } on DioException catch (error, stackTrace) {
      return ResultFailure(_mapError(error, stackTrace));
    } catch (error, stackTrace) {
      return ResultFailure(
        UnexpectedFailure(
          'Your application could not be submitted.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
    return const Success(null);
  }

  Future<AppFailure?> _grantEmployerSharingConsent(String candidateId) async {
    try {
      await _supabaseClient.from('consent_grants').upsert({
        'candidate_id': candidateId,
        'purpose': JobsConsentVersions.employerSharingPurpose,
        'policy_version': JobsConsentVersions.employerSharingVersion,
        'granted_at': DateTime.now().toUtc().toIso8601String(),
        'revoked_at': null,
      }, onConflict: 'candidate_id,purpose,policy_version');
      return null;
    } on PostgrestException catch (error, stackTrace) {
      return NetworkFailure(
        'Your sharing consent could not be saved. Try again.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  JobOpportunity _fromJson(Map<String, Object?> json) {
    final title = json['title'] as String? ?? '';
    return JobOpportunity(
      id: json['id'] as String? ?? '',
      title: title,
      employer: json['employer_name'] as String? ?? '',
      location: json['location'] as String? ?? '',
      isSupervisorRole: jobTitleLooksLikeSupervisorRole(title),
      description: json['description'] as String? ?? '',
      source: json['source'] as String? ?? 'flora',
      applyUrl: json['apply_url'] as String?,
    );
  }

  AppFailure _mapError(DioException error, StackTrace stackTrace) {
    final status = error.response?.statusCode;
    final body = error.response?.data;
    final serverError = body is Map ? body['error'] : null;
    final serverMessage = serverError is Map ? serverError['message'] : null;
    final message = serverMessage is String
        ? serverMessage
        : 'Your application could not be submitted.';

    if (status == 401) {
      return AuthenticationFailure(
        message,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (status == 403) {
      return PermissionFailure(message, cause: error, stackTrace: stackTrace);
    }
    if (status == 400 || status == 404) {
      return ValidationFailure(message, cause: error, stackTrace: stackTrace);
    }
    const networkErrorTypes = {
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.connectionError,
    };
    if (networkErrorTypes.contains(error.type)) {
      return NetworkFailure(
        'Could not reach the jobs service. Check your connection and try again.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    return UnexpectedFailure(message, cause: error, stackTrace: stackTrace);
  }
}
