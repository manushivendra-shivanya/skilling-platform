import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../profile_details/domain/detailed_candidate_profile.dart';
import '../domain/resume_parsing_repository.dart';

/// Calls the real NestJS BFF (`POST /v1/resume/parse`, see
/// `apps/api/src/resume`). Same shape as `ApiCoachRepository`: the AI
/// provider call always happens server-side, this repository only ever
/// talks to Flora's own API, never to Gemini directly.
///
/// Parses the response defensively (wrong-typed field -> empty/dropped,
/// not a thrown exception) -- the same posture
/// `gemini-resume-parser.ts`'s own coercion helpers take server-side, kept
/// here too since Dio's `response.data` is `dynamic` and nothing on this
/// side re-validates what the server already validated.
class ApiResumeParsingRepository implements ResumeParsingRepository {
  ApiResumeParsingRepository({
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
  Future<Result<ResumeParseResult>> parse(ResumeParseRequest request) {
    return _post('resume/parse', {
      'resumeText': request.resumeText,
      'consentVersion': request.consentVersion,
    });
  }

  /// The file goes up base64-encoded inside the ordinary JSON body rather
  /// than as multipart form data -- one request shape, one auth header,
  /// and the same error envelope every other endpoint returns. A resume
  /// is bounded to a few megabytes server-side, so base64's one-third
  /// size overhead costs less than a second transport to maintain.
  @override
  Future<Result<ResumeParseResult>> parseDocument(
    ResumeDocumentParseRequest request,
  ) {
    return _post('resume/parse-document', {
      'contentBase64': base64Encode(request.bytes),
      'fileName': request.fileName,
      'consentVersion': request.consentVersion,
    });
  }

  Future<Result<ResumeParseResult>> _post(
    String path,
    Map<String, Object?> data,
  ) async {
    final accessToken = _supabaseClient.auth.currentSession?.accessToken;
    if (accessToken == null) {
      return const ResultFailure(
        AuthenticationFailure('Sign in again to parse your resume.'),
      );
    }
    try {
      final response = await _dio.post<Object?>(
        '$_apiBaseUrl/$path',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        data: data,
      );
      final body = response.data;
      if (body is! Map) {
        throw const FormatException('Unexpected resume-parse response shape');
      }
      final requiresCandidateReview = body['requiresCandidateReview'];
      final provider = body['provider'];
      if (requiresCandidateReview is! bool || provider is! String) {
        throw const FormatException('Unexpected resume-parse response shape');
      }
      return Success(
        ResumeParseResult(
          adapter: provider,
          fullName: _str(body['fullName']),
          phone: _str(body['phone']),
          email: _str(body['email']),
          city: _str(body['city']),
          headline: _str(body['headline']),
          yearsOfExperience: _str(body['yearsOfExperience']),
          skills: _strList(body['skills']),
          education: _educationList(body['education']),
          workExperience: _workExperienceList(body['workExperience']),
          certifications: _certificationList(body['certifications']),
          projects: _projectList(body['projects']),
          requiresCandidateReview: requiresCandidateReview,
        ),
      );
    } on DioException catch (error, stackTrace) {
      return ResultFailure(_mapError(error, stackTrace));
    } catch (error, stackTrace) {
      return ResultFailure(
        UnexpectedFailure(
          'Your resume could not be parsed. Try again in a moment.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  String _str(Object? value) => value is String ? value.trim() : '';

  int? _nullableInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  bool _bool(Object? value) => value == true;

  List<String> _strList(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }

  List<EducationEntry> _educationList(Object? value) {
    if (value is! List) return const [];
    final entries = <EducationEntry>[];
    for (final raw in value) {
      if (raw is! Map) continue;
      final institution = _str(raw['institution']);
      final degree = _str(raw['degree']);
      if (institution.isEmpty && degree.isEmpty) continue;
      entries.add(
        EducationEntry(
          id: '',
          institution: institution,
          degree: degree,
          fieldOfStudy: _str(raw['fieldOfStudy']),
          startYear: _nullableInt(raw['startYear']),
          endYear: _nullableInt(raw['endYear']),
          grade: _str(raw['grade']),
        ),
      );
    }
    return entries;
  }

  List<WorkExperienceEntry> _workExperienceList(Object? value) {
    if (value is! List) return const [];
    final entries = <WorkExperienceEntry>[];
    for (final raw in value) {
      if (raw is! Map) continue;
      final title = _str(raw['title']);
      final company = _str(raw['company']);
      if (title.isEmpty && company.isEmpty) continue;
      entries.add(
        WorkExperienceEntry(
          id: '',
          title: title,
          company: company,
          location: _str(raw['location']),
          startMonth: _nullableInt(raw['startMonth']),
          startYear: _nullableInt(raw['startYear']),
          endMonth: _nullableInt(raw['endMonth']),
          endYear: _nullableInt(raw['endYear']),
          isCurrent: _bool(raw['isCurrent']),
          description: _str(raw['description']),
        ),
      );
    }
    return entries;
  }

  List<ExternalCertificationEntry> _certificationList(Object? value) {
    if (value is! List) return const [];
    final entries = <ExternalCertificationEntry>[];
    for (final raw in value) {
      if (raw is! Map) continue;
      final name = _str(raw['name']);
      if (name.isEmpty) continue;
      entries.add(
        ExternalCertificationEntry(
          id: '',
          name: name,
          issuingOrganization: _str(raw['issuingOrganization']),
          issueMonth: _nullableInt(raw['issueMonth']),
          issueYear: _nullableInt(raw['issueYear']),
          expiryMonth: _nullableInt(raw['expiryMonth']),
          expiryYear: _nullableInt(raw['expiryYear']),
        ),
      );
    }
    return entries;
  }

  List<ProjectEntry> _projectList(Object? value) {
    if (value is! List) return const [];
    final entries = <ProjectEntry>[];
    for (final raw in value) {
      if (raw is! Map) continue;
      final title = _str(raw['title']);
      if (title.isEmpty) continue;
      entries.add(
        ProjectEntry(
          id: '',
          title: title,
          role: _str(raw['role']),
          description: _str(raw['description']),
          startMonth: _nullableInt(raw['startMonth']),
          startYear: _nullableInt(raw['startYear']),
          endMonth: _nullableInt(raw['endMonth']),
          endYear: _nullableInt(raw['endYear']),
          isOngoing: _bool(raw['isOngoing']),
          url: _str(raw['url']),
        ),
      );
    }
    return entries;
  }

  AppFailure _mapError(DioException error, StackTrace stackTrace) {
    final status = error.response?.statusCode;
    final body = error.response?.data;
    final serverError = body is Map ? body['error'] : null;
    final serverMessage = serverError is Map ? serverError['message'] : null;
    final message = serverMessage is String
        ? serverMessage
        : 'Your resume could not be parsed. Try again in a moment.';

    if (status == 401) {
      return AuthenticationFailure(
        message,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    // 403 covers both the required-consent case and rate-limiting -- same
    // posture as ApiCoachRepository.
    if (status == 403 || status == 429) {
      return PermissionFailure(message, cause: error, stackTrace: stackTrace);
    }
    // 400 only -- deliberately no longer bundled with 404. A 400 from
    // this API is always a deliberate `AppError.validation`-style
    // rejection whose message is written for the candidate ("that file
    // is not a resume this app can read", "save it as a PDF or .docx",
    // "that resume is too long to read in one go"), and
    // `ResumeImportScreen` shows it verbatim. A 404 is a routing
    // mistake, whose message is framework text like
    // "Cannot POST /v1/resume/parse-document" -- never something to put
    // in front of a candidate, so it keeps the generic fallback below.
    if (status == 400) {
      return ValidationFailure(message, cause: error, stackTrace: stackTrace);
    }
    if (status == 404) {
      return ValidationFailure(
        'Your resume could not be parsed. Try again in a moment.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    const networkErrorTypes = {
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.connectionError,
    };
    if (networkErrorTypes.contains(error.type)) {
      return NetworkFailure(
        'Could not reach the server. Check your connection and try again.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    // `ResumeService.parseResume` turns *every* provider failure -- a
    // Gemini outage, a malformed extraction, or simply an unset
    // GEMINI_API_KEY -- into a 503. Without this branch that landed on
    // UnexpectedFailure, which renders as "Something unexpected went
    // wrong": no hint that waiting helps, and indistinguishable from a
    // bug in the app itself.
    if (status != null && status >= 500 && status < 600) {
      return ServiceUnavailableFailure(
        message,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    return UnexpectedFailure(message, cause: error, stackTrace: stackTrace);
  }
}
