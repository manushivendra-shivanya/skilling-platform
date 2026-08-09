import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/shift_payout.dart';

/// Direct-to-Supabase read only -- payout status changes are an ops/
/// employer action via the BFF service role, never candidate-initiated, so
/// there is no write path here at all.
class SupabaseShiftPayoutRepository implements ShiftPayoutRepository {
  SupabaseShiftPayoutRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<List<ShiftPayout>>> loadPayouts(String candidateId) async {
    try {
      final rows = await _client
          .from('shift_payouts')
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
          'Your payouts could not be loaded.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  ShiftPayout _fromJson(Map<String, Object?> json) => ShiftPayout(
    shiftApplicationId: json['shift_application_id'] as String? ?? '',
    basePay: (json['base_pay'] as num?)?.toDouble() ?? 0,
    bonus: (json['bonus'] as num?)?.toDouble() ?? 0,
    deductions: (json['deductions'] as num?)?.toDouble() ?? 0,
    total: (json['total'] as num?)?.toDouble() ?? 0,
    status: ShiftPayoutStatus.fromWireValue(
      json['status'] as String? ?? 'pending_approval',
    ),
    expectedPayoutDate: (json['expected_payout_date'] as String?) == null
        ? null
        : DateTime.parse(json['expected_payout_date'] as String),
  );
}
