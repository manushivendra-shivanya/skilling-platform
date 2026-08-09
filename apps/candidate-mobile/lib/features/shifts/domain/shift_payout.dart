import '../../../core/errors/result.dart';

/// Status-only ledger -- never a wallet. See the Phase OD-1 migration
/// header: real payout money movement needs a payment partner and
/// compliance/tax review that is explicitly out of scope. This enum only
/// ever reflects a status a human (site/ops) set, same as
/// `job_applications.status`.
enum ShiftPayoutStatus {
  pendingApproval,
  approved,
  processing,
  paid,
  failed,
  disputed;

  static ShiftPayoutStatus fromWireValue(String value) => switch (value) {
    'pending_approval' => pendingApproval,
    'approved' => approved,
    'processing' => processing,
    'paid' => paid,
    'failed' => failed,
    'disputed' => disputed,
    _ => pendingApproval,
  };
}

class ShiftPayout {
  const ShiftPayout({
    required this.shiftApplicationId,
    required this.basePay,
    required this.bonus,
    required this.deductions,
    required this.total,
    required this.status,
    required this.expectedPayoutDate,
  });

  final String shiftApplicationId;
  final double basePay;
  final double bonus;
  final double deductions;
  final double total;
  final ShiftPayoutStatus status;
  final DateTime? expectedPayoutDate;
}

/// Direct-to-Supabase read, no BFF -- payout status changes are an
/// ops/employer approval action, never candidate-initiated, so there is no
/// candidate-facing write here at all.
abstract interface class ShiftPayoutRepository {
  Future<Result<List<ShiftPayout>>> loadPayouts(String candidateId);
}
