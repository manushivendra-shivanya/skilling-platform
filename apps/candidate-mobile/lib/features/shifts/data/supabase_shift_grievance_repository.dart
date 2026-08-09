import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/shift_grievance.dart';

/// Direct-to-Supabase, both read and insert -- no idempotency/race
/// concern in filing a support ticket (unlike accepting a limited-headcount
/// shift), so this skips the BFF entirely, same posture as
/// `SupabaseCandidateOnboardingRepository`.
class SupabaseShiftGrievanceRepository implements ShiftGrievanceRepository {
  SupabaseShiftGrievanceRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<List<ShiftGrievance>>> loadGrievances(
    String candidateId,
  ) async {
    try {
      final rows = await _client
          .from('shift_grievances')
          .select()
          .eq('candidate_id', candidateId)
          .order('created_at', ascending: false);
      return Success([
        for (final row in (rows as List).cast<Map<String, Object?>>())
          _fromJson(row),
      ]);
    } on PostgrestException catch (error, stackTrace) {
      return ResultFailure(
        NetworkFailure(
          'Your grievances could not be loaded.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void>> submitGrievance(
    String candidateId, {
    required ShiftGrievanceCategory category,
    required String description,
    String? shiftApplicationId,
  }) async {
    try {
      await _client.from('shift_grievances').insert({
        'candidate_id': candidateId,
        'shift_application_id': shiftApplicationId,
        'category': category.wireValue,
        'description': description,
      });
      return const Success(null);
    } on PostgrestException catch (error, stackTrace) {
      return ResultFailure(
        NetworkFailure(
          'Your grievance could not be submitted.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  ShiftGrievance _fromJson(Map<String, Object?> json) => ShiftGrievance(
    id: json['id'] as String? ?? '',
    category: ShiftGrievanceCategory.fromWireValue(
      json['category'] as String? ?? 'other',
    ),
    description: json['description'] as String? ?? '',
    status: ShiftGrievanceStatus.fromWireValue(
      json['status'] as String? ?? 'open',
    ),
    resolutionNotes: json['resolution_notes'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
