import '../../../core/errors/result.dart';

enum ShiftGrievanceCategory {
  attendanceMismatch,
  payoutMismatch,
  unsafeWork,
  supervisorIssue,
  unpaidOvertime,
  cancellationIssue,
  harassmentSafety,
  other;

  String get wireValue => switch (this) {
    attendanceMismatch => 'attendance_mismatch',
    payoutMismatch => 'payout_mismatch',
    unsafeWork => 'unsafe_work',
    supervisorIssue => 'supervisor_issue',
    unpaidOvertime => 'unpaid_overtime',
    cancellationIssue => 'cancellation_issue',
    harassmentSafety => 'harassment_safety',
    other => 'other',
  };

  static ShiftGrievanceCategory fromWireValue(String value) => switch (value) {
    'attendance_mismatch' => attendanceMismatch,
    'payout_mismatch' => payoutMismatch,
    'unsafe_work' => unsafeWork,
    'supervisor_issue' => supervisorIssue,
    'unpaid_overtime' => unpaidOvertime,
    'cancellation_issue' => cancellationIssue,
    'harassment_safety' => harassmentSafety,
    _ => other,
  };

  // No `displayLabel` here -- this is domain-layer, English-only by
  // convention, and has no `BuildContext` to localize with. The
  // presentation-layer `_categoryLabel` in shift_grievance_screen.dart maps
  // this enum to a localized string instead.
}

enum ShiftGrievanceStatus {
  open,
  inReview,
  resolved,
  closed;

  static ShiftGrievanceStatus fromWireValue(String value) => switch (value) {
    'open' => open,
    'in_review' => inReview,
    'resolved' => resolved,
    'closed' => closed,
    _ => open,
  };
}

class ShiftGrievance {
  const ShiftGrievance({
    required this.id,
    required this.category,
    required this.description,
    required this.status,
    required this.resolutionNotes,
    required this.createdAt,
  });

  final String id;
  final ShiftGrievanceCategory category;
  final String description;
  final ShiftGrievanceStatus status;
  final String? resolutionNotes;
  final DateTime createdAt;

  /// The ticket reference shown to the candidate -- just the row id,
  /// truncated and uppercased, not a separately-issued number.
  String get ticketReference =>
      id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
}

/// Direct-to-Supabase, no BFF -- there's no idempotency/race-condition
/// concern in filing a support ticket, unlike accepting a limited-headcount
/// shift, so this skips the BFF the same way availability does.
abstract interface class ShiftGrievanceRepository {
  Future<Result<List<ShiftGrievance>>> loadGrievances(String candidateId);

  Future<Result<void>> submitGrievance(
    String candidateId, {
    required ShiftGrievanceCategory category,
    required String description,
    String? shiftApplicationId,
  });
}
