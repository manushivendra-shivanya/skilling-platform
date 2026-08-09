import '../../career_passport/domain/career_passport.dart';

/// Match% and skill-gate status for one shift, derived purely from
/// already-loaded Career Passport evidence -- see
/// `career_passport/domain/role_readiness.dart`'s [deriveRoleReadiness] for
/// the identical shape. Computed client-side rather than by the BFF: the
/// backend's service-role client can only see server-synced (WMS) evidence,
/// not the device-local micro-lesson/certification-exam evidence, so a
/// server-computed match score would silently under-count a candidate's
/// real readiness. This function sees everything Career Passport itself
/// shows, because it's driven by the same entries.
class ShiftMatch {
  const ShiftMatch({
    required this.matchPercent,
    required this.missingCompetencyIds,
  });

  /// 100 when [missingCompetencyIds] is empty and the shift requires at
  /// least one competency; 100 (vacuously) when the shift requires none.
  final int matchPercent;
  final List<String> missingCompetencyIds;

  bool get isEligible => missingCompetencyIds.isEmpty;
}

/// Pure and deterministic, same shape as [deriveRoleReadiness]: a candidate
/// "has" a required competency if any non-superseded [CareerPassportEntry]
/// exists for it, regardless of score -- shift eligibility is about having
/// demonstrated the skill at all, not about a proficiency threshold (that's
/// what [deriveRoleReadiness] is for).
ShiftMatch deriveShiftMatch(
  List<CareerPassportEntry> entries,
  List<String> requiredCompetencyIds,
) {
  if (requiredCompetencyIds.isEmpty) {
    return const ShiftMatch(matchPercent: 100, missingCompetencyIds: []);
  }
  final demonstratedIds = {
    for (final entry in entries)
      if (entry.freshness != EvidenceFreshnessState.superseded)
        entry.evidence.competencyId,
  };
  final missing = [
    for (final id in requiredCompetencyIds)
      if (!demonstratedIds.contains(id)) id,
  ];
  final matchedCount = requiredCompetencyIds.length - missing.length;
  final matchPercent = ((matchedCount / requiredCompetencyIds.length) * 100)
      .round();
  return ShiftMatch(matchPercent: matchPercent, missingCompetencyIds: missing);
}
