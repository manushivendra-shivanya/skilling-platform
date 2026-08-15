import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/detailed_candidate_profile.dart';
import '../domain/detailed_profile_repository.dart';

/// Real, Supabase-backed implementation -- direct Postgrest reads/writes
/// under RLS, the same convention `SupabaseCandidateOnboardingRepository`
/// and Career Passport's evidence reads already use for simple owned-row
/// access (see `home_dashboard_repository.dart`'s eventual real
/// implementation for the alternative apps/api-BFF convention, used where
/// a read needs a cross-candidate join instead).
class SupabaseDetailedProfileRepository implements DetailedProfileRepository {
  SupabaseDetailedProfileRepository(
    this._client, {
    Duration callTimeout = const Duration(seconds: 12),
  }) : _callTimeout = callTimeout;

  final SupabaseClient _client;
  final Duration _callTimeout;

  @override
  Future<Result<DetailedCandidateProfile>> load(String candidateId) async {
    try {
      final results = await Future.wait([
        _client
            .from('candidate_profiles')
            .select(
              'phone, email, skills, headline, summary, total_experience, '
              'current_ctc_amount, current_ctc_undisclosed, '
              'expected_ctc_amount, expected_ctc_negotiable, notice_period, '
              'employment_types, preferred_locations, willing_to_relocate, '
              'industry, functional_area',
            )
            .eq('candidate_id', candidateId)
            .maybeSingle()
            .timeout(_callTimeout),
        _client
            .from('candidate_work_experience')
            .select()
            .eq('candidate_id', candidateId)
            .order('sequence')
            .timeout(_callTimeout),
        _client
            .from('candidate_education')
            .select()
            .eq('candidate_id', candidateId)
            .order('sequence')
            .timeout(_callTimeout),
        _client
            .from('candidate_external_certifications')
            .select()
            .eq('candidate_id', candidateId)
            .order('sequence')
            .timeout(_callTimeout),
        _client
            .from('candidate_projects')
            .select()
            .eq('candidate_id', candidateId)
            .order('sequence')
            .timeout(_callTimeout),
        _client
            .from('candidate_languages')
            .select()
            .eq('candidate_id', candidateId)
            .order('sequence')
            .timeout(_callTimeout),
      ]);

      final profile = results[0] as Map<String, dynamic>?;
      final experienceRows = results[1] as List<dynamic>;
      final educationRows = results[2] as List<dynamic>;
      final certificationRows = results[3] as List<dynamic>;
      final projectRows = results[4] as List<dynamic>;
      final languageRows = results[5] as List<dynamic>;

      return Success(
        DetailedCandidateProfile(
          phone: profile?['phone'] as String? ?? '',
          email: profile?['email'] as String? ?? '',
          skills: _stringList(profile?['skills']),
          workExperience: experienceRows
              .cast<Map<String, dynamic>>()
              .map(_workExperienceFromRow)
              .toList(growable: false),
          education: educationRows
              .cast<Map<String, dynamic>>()
              .map(_educationFromRow)
              .toList(growable: false),
          certifications: certificationRows
              .cast<Map<String, dynamic>>()
              .map(_certificationFromRow)
              .toList(growable: false),
          projects: projectRows
              .cast<Map<String, dynamic>>()
              .map(_projectFromRow)
              .toList(growable: false),
          headline: profile?['headline'] as String? ?? '',
          summary: profile?['summary'] as String? ?? '',
          totalExperience: profile?['total_experience'] as String? ?? '',
          languages: languageRows
              .cast<Map<String, dynamic>>()
              .map(_languageFromRow)
              .toList(growable: false),
          careerPreferences: _careerPreferencesFromRow(profile),
        ),
      );
    } on PostgrestException catch (error, stackTrace) {
      return ResultFailure(_loadFailure(error, stackTrace));
    } on TimeoutException catch (error, stackTrace) {
      return ResultFailure(_loadFailure(error, stackTrace));
    }
  }

  AppFailure _loadFailure(Object error, StackTrace stackTrace) =>
      NetworkFailure(
        'Your profile could not be loaded. Check your connection and retry.',
        cause: error,
        stackTrace: stackTrace,
      );

  AppFailure _saveFailure(Object error, StackTrace stackTrace) =>
      NetworkFailure(
        'This could not be saved. Check your connection and try again.',
        cause: error,
        stackTrace: stackTrace,
      );

  List<String> _stringList(Object? value) =>
      (value as List<dynamic>? ?? const []).whereType<String>().toList(
        growable: false,
      );

  WorkExperienceEntry _workExperienceFromRow(Map<String, dynamic> row) =>
      WorkExperienceEntry(
        id: row['id'] as String,
        title: row['title'] as String? ?? '',
        company: row['company'] as String? ?? '',
        location: row['location'] as String? ?? '',
        startMonth: row['start_month'] as int?,
        startYear: row['start_year'] as int?,
        endMonth: row['end_month'] as int?,
        endYear: row['end_year'] as int?,
        isCurrent: row['is_current'] as bool? ?? false,
        description: row['description'] as String? ?? '',
        sequence: row['sequence'] as int? ?? 0,
      );

  EducationEntry _educationFromRow(Map<String, dynamic> row) => EducationEntry(
    id: row['id'] as String,
    institution: row['institution'] as String? ?? '',
    degree: row['degree'] as String? ?? '',
    fieldOfStudy: row['field_of_study'] as String? ?? '',
    startYear: row['start_year'] as int?,
    endYear: row['end_year'] as int?,
    grade: row['grade'] as String? ?? '',
    description: row['description'] as String? ?? '',
    sequence: row['sequence'] as int? ?? 0,
  );

  ExternalCertificationEntry _certificationFromRow(Map<String, dynamic> row) =>
      ExternalCertificationEntry(
        id: row['id'] as String,
        name: row['name'] as String? ?? '',
        issuingOrganization: row['issuing_organization'] as String? ?? '',
        issueMonth: row['issue_month'] as int?,
        issueYear: row['issue_year'] as int?,
        expiryMonth: row['expiry_month'] as int?,
        expiryYear: row['expiry_year'] as int?,
        credentialId: row['credential_id'] as String? ?? '',
        credentialUrl: row['credential_url'] as String? ?? '',
        sequence: row['sequence'] as int? ?? 0,
      );

  ProjectEntry _projectFromRow(Map<String, dynamic> row) => ProjectEntry(
    id: row['id'] as String,
    title: row['title'] as String? ?? '',
    role: row['role'] as String? ?? '',
    description: row['description'] as String? ?? '',
    startMonth: row['start_month'] as int?,
    startYear: row['start_year'] as int?,
    endMonth: row['end_month'] as int?,
    endYear: row['end_year'] as int?,
    isOngoing: row['is_ongoing'] as bool? ?? false,
    url: row['url'] as String? ?? '',
    skillsUsed: _stringList(row['skills_used']),
    sequence: row['sequence'] as int? ?? 0,
  );

  LanguageEntry _languageFromRow(Map<String, dynamic> row) => LanguageEntry(
    id: row['id'] as String,
    language: row['language'] as String? ?? '',
    proficiency:
        LanguageProficiency.fromId(row['proficiency']) ??
        LanguageProficiency.elementary,
    sequence: row['sequence'] as int? ?? 0,
  );

  CareerPreferences _careerPreferencesFromRow(Map<String, dynamic>? row) {
    if (row == null) return CareerPreferences.empty;
    return CareerPreferences(
      currentCtcAmount: (row['current_ctc_amount'] as num?)?.toDouble(),
      currentCtcUndisclosed: row['current_ctc_undisclosed'] as bool? ?? false,
      expectedCtcAmount: (row['expected_ctc_amount'] as num?)?.toDouble(),
      expectedCtcNegotiable: row['expected_ctc_negotiable'] as bool? ?? false,
      noticePeriod: NoticePeriod.fromId(row['notice_period']),
      employmentTypes: (row['employment_types'] as List<dynamic>? ?? const [])
          .map(EmploymentType.fromId)
          .whereType<EmploymentType>()
          .toSet(),
      preferredLocations: _stringList(row['preferred_locations']),
      willingToRelocate: row['willing_to_relocate'] as bool? ?? false,
      industry: row['industry'] as String? ?? '',
      functionalArea: row['functional_area'] as String? ?? '',
    );
  }

  @override
  Future<Result<void>> saveProfileBasics(
    String candidateId, {
    required String headline,
    required String summary,
    required String totalExperience,
  }) async {
    try {
      // Upsert, not update -- same rationale as saveContactAndSkills: a
      // resume-driven import or the future voice-completion flow can both
      // write before any candidate_profiles row exists.
      await _client
          .from('candidate_profiles')
          .upsert({
            'candidate_id': candidateId,
            'headline': headline,
            'summary': summary,
            'total_experience': totalExperience,
          }, onConflict: 'candidate_id')
          .timeout(_callTimeout);
      return const Success(null);
    } on PostgrestException catch (error, stackTrace) {
      return ResultFailure(_saveFailure(error, stackTrace));
    } on TimeoutException catch (error, stackTrace) {
      return ResultFailure(_saveFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<void>> saveCareerPreferences(
    String candidateId,
    CareerPreferences preferences,
  ) async {
    try {
      await _client
          .from('candidate_profiles')
          .upsert({
            'candidate_id': candidateId,
            'current_ctc_amount': preferences.currentCtcAmount,
            'current_ctc_undisclosed': preferences.currentCtcUndisclosed,
            'expected_ctc_amount': preferences.expectedCtcAmount,
            'expected_ctc_negotiable': preferences.expectedCtcNegotiable,
            'notice_period': preferences.noticePeriod?.id,
            'employment_types': preferences.employmentTypes
                .map((type) => type.id)
                .toList(),
            'preferred_locations': preferences.preferredLocations,
            'willing_to_relocate': preferences.willingToRelocate,
            'industry': preferences.industry,
            'functional_area': preferences.functionalArea,
          }, onConflict: 'candidate_id')
          .timeout(_callTimeout);
      return const Success(null);
    } on PostgrestException catch (error, stackTrace) {
      return ResultFailure(_saveFailure(error, stackTrace));
    } on TimeoutException catch (error, stackTrace) {
      return ResultFailure(_saveFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<void>> upsertLanguage(
    String candidateId,
    LanguageEntry entry,
  ) => _upsert('candidate_languages', {
    if (entry.id.isNotEmpty) 'id': entry.id,
    'candidate_id': candidateId,
    'language': entry.language,
    'proficiency': entry.proficiency.id,
    'sequence': entry.sequence,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  });

  @override
  Future<Result<void>> deleteLanguage(String candidateId, String id) =>
      _delete('candidate_languages', candidateId, id);

  @override
  Future<Result<void>> saveContactAndSkills(
    String candidateId, {
    required String phone,
    required String email,
    required List<String> skills,
  }) async {
    try {
      // Upsert, not update: a resume-driven import can now write these
      // before the candidate has ever saved anything through the
      // onboarding wizard (see the post-signup resume-import screen),
      // meaning no `candidate_profiles` row may exist yet -- an update
      // against a missing row silently affects zero rows in Postgrest
      // rather than erroring, which would have looked like a successful
      // save that actually saved nothing.
      await _client
          .from('candidate_profiles')
          .upsert({
            'candidate_id': candidateId,
            'phone': phone,
            'email': email,
            'skills': skills,
          }, onConflict: 'candidate_id')
          .timeout(_callTimeout);
      return const Success(null);
    } on PostgrestException catch (error, stackTrace) {
      return ResultFailure(_saveFailure(error, stackTrace));
    } on TimeoutException catch (error, stackTrace) {
      return ResultFailure(_saveFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<void>> upsertWorkExperience(
    String candidateId,
    WorkExperienceEntry entry,
  ) => _upsert('candidate_work_experience', {
    if (entry.id.isNotEmpty) 'id': entry.id,
    'candidate_id': candidateId,
    'title': entry.title,
    'company': entry.company,
    'location': entry.location,
    'start_month': entry.startMonth,
    'start_year': entry.startYear,
    // A current role has no end date -- see WorkExperienceEntry's own doc.
    'end_month': entry.isCurrent ? null : entry.endMonth,
    'end_year': entry.isCurrent ? null : entry.endYear,
    'is_current': entry.isCurrent,
    'description': entry.description,
    'sequence': entry.sequence,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  });

  @override
  Future<Result<void>> deleteWorkExperience(String candidateId, String id) =>
      _delete('candidate_work_experience', candidateId, id);

  @override
  Future<Result<void>> upsertEducation(
    String candidateId,
    EducationEntry entry,
  ) => _upsert('candidate_education', {
    if (entry.id.isNotEmpty) 'id': entry.id,
    'candidate_id': candidateId,
    'institution': entry.institution,
    'degree': entry.degree,
    'field_of_study': entry.fieldOfStudy,
    'start_year': entry.startYear,
    'end_year': entry.endYear,
    'grade': entry.grade,
    'description': entry.description,
    'sequence': entry.sequence,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  });

  @override
  Future<Result<void>> deleteEducation(String candidateId, String id) =>
      _delete('candidate_education', candidateId, id);

  @override
  Future<Result<void>> upsertCertification(
    String candidateId,
    ExternalCertificationEntry entry,
  ) => _upsert('candidate_external_certifications', {
    if (entry.id.isNotEmpty) 'id': entry.id,
    'candidate_id': candidateId,
    'name': entry.name,
    'issuing_organization': entry.issuingOrganization,
    'issue_month': entry.issueMonth,
    'issue_year': entry.issueYear,
    'expiry_month': entry.expiryMonth,
    'expiry_year': entry.expiryYear,
    'credential_id': entry.credentialId,
    'credential_url': entry.credentialUrl,
    'sequence': entry.sequence,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  });

  @override
  Future<Result<void>> deleteCertification(String candidateId, String id) =>
      _delete('candidate_external_certifications', candidateId, id);

  @override
  Future<Result<void>> upsertProject(String candidateId, ProjectEntry entry) =>
      _upsert('candidate_projects', {
        if (entry.id.isNotEmpty) 'id': entry.id,
        'candidate_id': candidateId,
        'title': entry.title,
        'role': entry.role,
        'description': entry.description,
        'start_month': entry.startMonth,
        'start_year': entry.startYear,
        'end_month': entry.isOngoing ? null : entry.endMonth,
        'end_year': entry.isOngoing ? null : entry.endYear,
        'is_ongoing': entry.isOngoing,
        'url': entry.url,
        'skills_used': entry.skillsUsed,
        'sequence': entry.sequence,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

  @override
  Future<Result<void>> deleteProject(String candidateId, String id) =>
      _delete('candidate_projects', candidateId, id);

  /// Shared by every section's upsert: inserts when the row carries no
  /// `id` (letting the table's own `default gen_random_uuid()` assign
  /// one), updates by id otherwise. `onConflict: 'id'` makes this a true
  /// upsert rather than a blind insert if the same id is ever resent.
  Future<Result<void>> _upsert(String table, Map<String, dynamic> row) async {
    try {
      await _client
          .from(table)
          .upsert(row, onConflict: 'id')
          .timeout(_callTimeout);
      return const Success(null);
    } on PostgrestException catch (error, stackTrace) {
      return ResultFailure(_saveFailure(error, stackTrace));
    } on TimeoutException catch (error, stackTrace) {
      return ResultFailure(_saveFailure(error, stackTrace));
    }
  }

  Future<Result<void>> _delete(
    String table,
    String candidateId,
    String id,
  ) async {
    try {
      // Both predicates, not just id: RLS already scopes this to the
      // candidate's own rows, but matching candidate_id here too means a
      // stale/tampered id from another candidate's row fails silently
      // (deletes nothing) instead of relying on RLS alone to catch it.
      await _client
          .from(table)
          .delete()
          .eq('id', id)
          .eq('candidate_id', candidateId)
          .timeout(_callTimeout);
      return const Success(null);
    } on PostgrestException catch (error, stackTrace) {
      return ResultFailure(_saveFailure(error, stackTrace));
    } on TimeoutException catch (error, stackTrace) {
      return ResultFailure(_saveFailure(error, stackTrace));
    }
  }
}
