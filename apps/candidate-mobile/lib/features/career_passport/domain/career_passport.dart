import '../../workplace_simulation/domain/simulation_runtime.dart';

/// Freshness state of a piece of evidence, derived (never stored) from how
/// it compares to other evidence for the same competency. Distinct from
/// [EvidenceVerificationStatus], which is provenance, not recency.
enum EvidenceFreshnessState {
  /// The newest evidence Flora holds for this competency, within the
  /// staleness window of being issued.
  active,

  /// Superseded by newer evidence for the same competency. Still true and
  /// still shown -- superseding never deletes evidence -- but not the
  /// candidate's current standing.
  superseded,

  /// The newest evidence Flora holds for this competency, but old enough
  /// that it should be re-demonstrated before being relied on.
  stale,
}

class CareerPassportEntry {
  const CareerPassportEntry({required this.evidence, required this.freshness});

  final EvidenceRecord evidence;
  final EvidenceFreshnessState freshness;
}

/// Groups [evidence] by competency, marks the newest record per competency
/// as [EvidenceFreshnessState.active] (or [EvidenceFreshnessState.stale] if
/// older than [staleAfter]), and marks every older record as
/// [EvidenceFreshnessState.superseded]. Pure and deterministic so the
/// governance rule is testable without any storage or network dependency.
List<CareerPassportEntry> deriveCareerPassportEntries(
  List<EvidenceRecord> evidence, {
  required DateTime now,
  Duration staleAfter = const Duration(days: 180),
}) {
  final byCompetency = <String, List<EvidenceRecord>>{};
  for (final record in evidence) {
    byCompetency.putIfAbsent(record.competencyId, () => []).add(record);
  }
  final entries = <CareerPassportEntry>[];
  for (final records in byCompetency.values) {
    final newestFirst = [...records]
      ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
    for (var index = 0; index < newestFirst.length; index++) {
      final record = newestFirst[index];
      final freshness = index > 0
          ? EvidenceFreshnessState.superseded
          : now.difference(record.issuedAt) > staleAfter
          ? EvidenceFreshnessState.stale
          : EvidenceFreshnessState.active;
      entries.add(CareerPassportEntry(evidence: record, freshness: freshness));
    }
  }
  entries.sort((a, b) => b.evidence.issuedAt.compareTo(a.evidence.issuedAt));
  return entries;
}

String competencyDisplayName(String competencyId) => competencyId
    .split('-')
    .map(
      (word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}',
    )
    .join(' ');
