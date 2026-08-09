import '../../../core/errors/result.dart';

class Shift {
  const Shift({
    required this.id,
    required this.roleTitle,
    required this.siteName,
    required this.siteAddress,
    required this.city,
    required this.startsAt,
    required this.endsAt,
    required this.reportingTime,
    required this.headcount,
    required this.payAmount,
    required this.payCurrency,
    required this.requiredCompetencyIds,
    required this.description,
    required this.supervisorName,
    required this.supervisorContact,
    required this.cancellationPolicy,
  });

  final String id;
  final String roleTitle;
  final String siteName;
  final String siteAddress;
  final String city;
  final DateTime startsAt;
  final DateTime endsAt;
  final DateTime? reportingTime;
  final int headcount;
  final double payAmount;
  final String payCurrency;
  final List<String> requiredCompetencyIds;
  final String? description;
  final String? supervisorName;
  final String? supervisorContact;
  final String? cancellationPolicy;
}

/// Mirrors `job_applications.status`'s vocabulary and posture -- see the
/// Phase OD-1 migration. `waitlisted` is not reachable yet (no waitlist in
/// this phase, a full shift is a clean rejection instead) but stays in the
/// enum since the database column allows it for a later phase.
enum ShiftApplicationStatus {
  accepted,
  confirmed,
  checkedIn,
  completed,
  noShow,
  cancelled,
  disputed;

  static ShiftApplicationStatus fromWireValue(String value) => switch (value) {
    'accepted' => accepted,
    'confirmed' => confirmed,
    'checked_in' => checkedIn,
    'completed' => completed,
    'no_show' => noShow,
    'cancelled' => cancelled,
    'disputed' => disputed,
    _ => accepted,
  };
}

class ShiftApplication {
  const ShiftApplication({
    required this.id,
    required this.shiftId,
    required this.status,
    required this.checkedInAt,
    required this.checkedOutAt,
    required this.createdAt,
  });

  final String id;
  final String shiftId;
  final ShiftApplicationStatus status;
  final DateTime? checkedInAt;
  final DateTime? checkedOutAt;
  final DateTime createdAt;
}

abstract interface class ShiftsRepository {
  Future<Result<List<Shift>>> loadPublishedShifts();

  Future<Result<Shift>> loadShiftDetail(String shiftId);

  Future<Result<List<ShiftApplication>>> loadMyApplications(String candidateId);

  Future<Result<ShiftApplication>> acceptShift(
    String candidateId,
    String shiftId,
  );

  Future<Result<ShiftApplication>> checkIn(String applicationId, String code);

  Future<Result<ShiftApplication>> checkOut(String applicationId);

  /// False for a local-only/demo repository, matching
  /// `JobsRepository.isLiveData`.
  bool get isLiveData;
}
