import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/shifts_repository.dart';

/// Shift listing, applications, check-in/check-out all go through the real
/// NestJS BFF (`apps/api`) -- exact mirror of `ApiJobsRepository`, down to
/// the idempotency-key shape and error mapping.
class ApiShiftsRepository implements ShiftsRepository {
  ApiShiftsRepository({
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
  Future<Result<List<Shift>>> loadPublishedShifts() async {
    final accessToken = _supabaseClient.auth.currentSession?.accessToken;
    if (accessToken == null) {
      return const ResultFailure(
        AuthenticationFailure('Sign in again to view shifts.'),
      );
    }
    try {
      final response = await _dio.get<Object?>(
        '$_apiBaseUrl/shifts',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final body = response.data;
      final shifts = body is Map ? body['shifts'] : null;
      if (shifts is! List) {
        throw const FormatException('Unexpected shifts response shape');
      }
      return Success([
        for (final entry in shifts.cast<Map<String, Object?>>())
          _shiftFromJson(entry),
      ]);
    } on DioException catch (error, stackTrace) {
      return ResultFailure(
        _mapError(error, stackTrace, 'Shifts could not be loaded.'),
      );
    } catch (error, stackTrace) {
      return ResultFailure(
        UnexpectedFailure(
          'Shifts could not be loaded.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<Shift>> loadShiftDetail(String shiftId) async {
    final accessToken = _supabaseClient.auth.currentSession?.accessToken;
    if (accessToken == null) {
      return const ResultFailure(
        AuthenticationFailure('Sign in again to view this shift.'),
      );
    }
    try {
      final response = await _dio.get<Object?>(
        '$_apiBaseUrl/shifts/$shiftId',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final body = response.data;
      final shift = body is Map ? body['shift'] : null;
      if (shift is! Map) {
        throw const FormatException('Unexpected shift response shape');
      }
      return Success(_shiftFromJson(shift.cast<String, Object?>()));
    } on DioException catch (error, stackTrace) {
      return ResultFailure(
        _mapError(error, stackTrace, 'This shift could not be loaded.'),
      );
    } catch (error, stackTrace) {
      return ResultFailure(
        UnexpectedFailure(
          'This shift could not be loaded.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<List<ShiftApplication>>> loadMyApplications(
    String candidateId,
  ) async {
    final accessToken = _supabaseClient.auth.currentSession?.accessToken;
    if (accessToken == null) {
      return const ResultFailure(
        AuthenticationFailure('Sign in again to view your shifts.'),
      );
    }
    try {
      final response = await _dio.get<Object?>(
        '$_apiBaseUrl/shifts/applications',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final body = response.data;
      final applications = body is Map ? body['applications'] : null;
      if (applications is! List) {
        throw const FormatException('Unexpected applications response shape');
      }
      return Success([
        for (final entry in applications.cast<Map<String, Object?>>())
          _applicationFromJson(entry),
      ]);
    } on DioException catch (error, stackTrace) {
      return ResultFailure(
        _mapError(error, stackTrace, 'Your shifts could not be loaded.'),
      );
    } catch (error, stackTrace) {
      return ResultFailure(
        UnexpectedFailure(
          'Your shifts could not be loaded.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<ShiftApplication>> acceptShift(
    String candidateId,
    String shiftId,
  ) async {
    final accessToken = _supabaseClient.auth.currentSession?.accessToken;
    if (accessToken == null) {
      return const ResultFailure(
        AuthenticationFailure('Sign in again to accept this shift.'),
      );
    }
    try {
      final response = await _dio.post<Object?>(
        '$_apiBaseUrl/shifts/$shiftId/applications',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            // Deterministic per candidate/shift, same reasoning as
            // ApiJobsRepository.saveApplication -- the server's unique
            // (shift_id, candidate_id) constraint is the real guarantee.
            'Idempotency-Key': 'shift-accept.$candidateId.$shiftId',
          },
        ),
      );
      final body = response.data;
      final application = body is Map ? body['application'] : null;
      if (application is! Map) {
        throw const FormatException('Unexpected application response shape');
      }
      return Success(_applicationFromJson(application.cast<String, Object?>()));
    } on DioException catch (error, stackTrace) {
      return ResultFailure(
        _mapError(error, stackTrace, 'This shift could not be accepted.'),
      );
    } catch (error, stackTrace) {
      return ResultFailure(
        UnexpectedFailure(
          'This shift could not be accepted.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<ShiftApplication>> checkIn(
    String applicationId,
    String code,
  ) async {
    final accessToken = _supabaseClient.auth.currentSession?.accessToken;
    if (accessToken == null) {
      return const ResultFailure(
        AuthenticationFailure('Sign in again to check in.'),
      );
    }
    try {
      final response = await _dio.post<Object?>(
        '$_apiBaseUrl/shifts/applications/$applicationId/check-in',
        data: {'code': code},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final body = response.data;
      final application = body is Map ? body['application'] : null;
      if (application is! Map) {
        throw const FormatException('Unexpected application response shape');
      }
      return Success(_applicationFromJson(application.cast<String, Object?>()));
    } on DioException catch (error, stackTrace) {
      return ResultFailure(
        _mapError(error, stackTrace, 'Check-in did not succeed.'),
      );
    } catch (error, stackTrace) {
      return ResultFailure(
        UnexpectedFailure(
          'Check-in did not succeed.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<ShiftApplication>> checkOut(String applicationId) async {
    final accessToken = _supabaseClient.auth.currentSession?.accessToken;
    if (accessToken == null) {
      return const ResultFailure(
        AuthenticationFailure('Sign in again to check out.'),
      );
    }
    try {
      final response = await _dio.post<Object?>(
        '$_apiBaseUrl/shifts/applications/$applicationId/check-out',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final body = response.data;
      final application = body is Map ? body['application'] : null;
      if (application is! Map) {
        throw const FormatException('Unexpected application response shape');
      }
      return Success(_applicationFromJson(application.cast<String, Object?>()));
    } on DioException catch (error, stackTrace) {
      return ResultFailure(
        _mapError(error, stackTrace, 'Check-out did not succeed.'),
      );
    } catch (error, stackTrace) {
      return ResultFailure(
        UnexpectedFailure(
          'Check-out did not succeed.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Shift _shiftFromJson(Map<String, Object?> json) => Shift(
    id: json['id'] as String? ?? '',
    roleTitle: json['role_title'] as String? ?? '',
    siteName: json['site_name'] as String? ?? '',
    siteAddress: json['site_address'] as String? ?? '',
    city: json['city'] as String? ?? '',
    startsAt: DateTime.parse(json['starts_at'] as String),
    endsAt: DateTime.parse(json['ends_at'] as String),
    reportingTime: (json['reporting_time'] as String?) == null
        ? null
        : DateTime.parse(json['reporting_time'] as String),
    headcount: json['headcount'] as int? ?? 0,
    payAmount: double.tryParse('${json['pay_amount']}') ?? 0,
    payCurrency: json['pay_currency'] as String? ?? 'INR',
    requiredCompetencyIds:
        (json['required_competency_ids'] as List?)?.cast<String>() ?? const [],
    description: json['description'] as String?,
    supervisorName: json['supervisor_name'] as String?,
    supervisorContact: json['supervisor_contact'] as String?,
    cancellationPolicy: json['cancellation_policy'] as String?,
  );

  ShiftApplication _applicationFromJson(Map<String, Object?> json) =>
      ShiftApplication(
        id: json['id'] as String? ?? '',
        shiftId: json['shift_id'] as String? ?? '',
        status: ShiftApplicationStatus.fromWireValue(
          json['status'] as String? ?? 'accepted',
        ),
        checkedInAt: (json['checked_in_at'] as String?) == null
            ? null
            : DateTime.parse(json['checked_in_at'] as String),
        checkedOutAt: (json['checked_out_at'] as String?) == null
            ? null
            : DateTime.parse(json['checked_out_at'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  AppFailure _mapError(
    DioException error,
    StackTrace stackTrace,
    String fallbackMessage,
  ) {
    final status = error.response?.statusCode;
    final body = error.response?.data;
    final serverError = body is Map ? body['error'] : null;
    final serverMessage = serverError is Map ? serverError['message'] : null;
    final message = serverMessage is String ? serverMessage : fallbackMessage;

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
        'Could not reach the shifts service. Check your connection and try again.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    return UnexpectedFailure(message, cause: error, stackTrace: stackTrace);
  }
}
