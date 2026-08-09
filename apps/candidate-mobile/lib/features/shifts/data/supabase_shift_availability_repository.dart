import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/shift_availability.dart';

/// Direct-to-Supabase, mirrors `SupabaseCandidateOnboardingRepository`'s
/// read/upsert shape exactly -- simple, single-candidate-owned profile
/// data, no BFF involved.
class SupabaseShiftAvailabilityRepository
    implements ShiftAvailabilityRepository {
  SupabaseShiftAvailabilityRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<ShiftAvailability>> readAvailability(String candidateId) async {
    try {
      final row = await _client
          .from('candidate_shift_availability')
          .select()
          .eq('candidate_id', candidateId)
          .maybeSingle();
      if (row == null) {
        return const Success(ShiftAvailability());
      }
      return Success(
        ShiftAvailability(
          availableToday: row['available_today'] as bool? ?? false,
          availableFrom: row['available_from'] as String?,
          availableUntil: row['available_until'] as String?,
          preferredCity: row['preferred_city'] as String?,
          maxTravelKm: row['max_travel_km'] as int?,
          minPay: (row['min_pay'] as num?)?.toDouble(),
        ),
      );
    } on PostgrestException catch (error, stackTrace) {
      return ResultFailure(
        NetworkFailure(
          'Your availability could not be loaded.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void>> saveAvailability(
    String candidateId,
    ShiftAvailability availability,
  ) async {
    try {
      await _client.from('candidate_shift_availability').upsert({
        'candidate_id': candidateId,
        'available_today': availability.availableToday,
        'available_from': availability.availableFrom,
        'available_until': availability.availableUntil,
        'preferred_city': availability.preferredCity,
        'max_travel_km': availability.maxTravelKm,
        'min_pay': availability.minPay,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'candidate_id');
      return const Success(null);
    } on PostgrestException catch (error, stackTrace) {
      return ResultFailure(
        NetworkFailure(
          'Your availability could not be saved.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}
