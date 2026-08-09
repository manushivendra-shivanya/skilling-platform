import '../../../core/errors/result.dart';

class ShiftAvailability {
  const ShiftAvailability({
    this.availableToday = false,
    this.availableFrom,
    this.availableUntil,
    this.preferredCity,
    this.maxTravelKm,
    this.minPay,
  });

  final bool availableToday;

  /// Stored as `HH:mm` (24-hour), matching Postgres `time` -- no date
  /// component, this is a daily recurring window, not a one-off slot.
  final String? availableFrom;
  final String? availableUntil;
  final String? preferredCity;
  final int? maxTravelKm;
  final double? minPay;

  ShiftAvailability copyWith({
    bool? availableToday,
    String? availableFrom,
    String? availableUntil,
    String? preferredCity,
    int? maxTravelKm,
    double? minPay,
  }) => ShiftAvailability(
    availableToday: availableToday ?? this.availableToday,
    availableFrom: availableFrom ?? this.availableFrom,
    availableUntil: availableUntil ?? this.availableUntil,
    preferredCity: preferredCity ?? this.preferredCity,
    maxTravelKm: maxTravelKm ?? this.maxTravelKm,
    minPay: minPay ?? this.minPay,
  );
}

/// Direct-to-Supabase, no BFF -- same posture as
/// `SupabaseCandidateOnboardingRepository`: simple, single-candidate-owned
/// profile data with no cross-candidate business logic.
abstract interface class ShiftAvailabilityRepository {
  Future<Result<ShiftAvailability>> readAvailability(String candidateId);

  Future<Result<void>> saveAvailability(
    String candidateId,
    ShiftAvailability availability,
  );
}
