import 'career_passport.dart';

/// The four operational areas readiness is reported against. Distinct from
/// [MicroLessonModule]/[MicroLessonDomain] and from WMS `departmentId` --
/// this is a coarser, evidence-facing grouping that all three evidence
/// sources (WMS simulation, micro-lesson assessment, certification exam)
/// map into via [competencyReadinessCategories].
enum ReadinessCategory { receiving, processing, dispatch, supervisor }

/// Ready/Developing/Needs practice mirror the `competencies.json`
/// proficiency ladder's Competent(70)/Developing(50)/Aware(0) thresholds --
/// see [deriveRoleReadiness]. Unknown means no mapped evidence exists yet
/// for the category at all, not a score of zero.
enum ReadinessLevel { ready, developing, needsPractice, unknown }

/// Generated from the WMS mission JSON + micro-lesson clip catalogue's
/// department/domain grouping -- see docs/generated/current-state.md's
/// "Phase G" entry for the exact rule and the handful of explicit
/// overrides for tags that span more than one domain (`food_safety_compliance`,
/// `inventory_location_control`, `order_quantity_control`). Competency ids
/// not present here are safely ignored by [deriveRoleReadiness] rather than
/// thrown -- forward-compatible with future content whose id hasn't been
/// added here yet, matching how `competencies.json` itself is a
/// hand-maintained catalogue.
const Map<String, ReadinessCategory> competencyReadinessCategories = {
  // WMS simulation competency ids (kebab-case)
  'document-verification': ReadinessCategory.receiving,
  'goods-inspection': ReadinessCategory.receiving,
  'inventory-accuracy': ReadinessCategory.receiving,
  'putaway-decisions': ReadinessCategory.receiving,
  'receiving-decisions': ReadinessCategory.receiving,
  'safe-material-handling': ReadinessCategory.receiving,
  'storage-location-accuracy': ReadinessCategory.receiving,
  'warehouse-compliance': ReadinessCategory.receiving,
  'batch-traceability': ReadinessCategory.processing,
  'hygiene-discipline': ReadinessCategory.processing,
  'pack-weight-control': ReadinessCategory.processing,
  'quality-exception-handling': ReadinessCategory.processing,
  'exception-escalation': ReadinessCategory.dispatch,
  'loading-sequence-control': ReadinessCategory.dispatch,
  'route-settlement-control': ReadinessCategory.dispatch,
  'route-verification': ReadinessCategory.dispatch,
  'scan-discipline': ReadinessCategory.dispatch,

  // Micro-lesson / certification exam competency tags (snake_case) --
  // the exam's 12 competency ids are all already covered here, since they
  // reuse micro-lesson tag strings verbatim.
  'ambient_storage_discipline': ReadinessCategory.receiving,
  'bakery_handling': ReadinessCategory.receiving,
  'carton_handling': ReadinessCategory.receiving,
  'chilled_dairy_handling': ReadinessCategory.receiving,
  'cold_chain_door_discipline': ReadinessCategory.receiving,
  'cold_chain_receiving_check': ReadinessCategory.receiving,
  'dairy_putaway_accuracy': ReadinessCategory.receiving,
  'egg_damage_check': ReadinessCategory.receiving,
  'fnv_quality_inspection': ReadinessCategory.receiving,
  'fnv_receiving_count': ReadinessCategory.receiving,
  'fnv_receiving_scan': ReadinessCategory.receiving,
  // Spans inspection/processing/receiving/supervisor domains -- resolved to
  // the majority position (receiving), since food safety starts at the dock.
  'food_safety_compliance': ReadinessCategory.receiving,
  // Spans picking/putAway -- resolved to receiving (established at
  // put-away, relied on by picking).
  'inventory_location_control': ReadinessCategory.receiving,
  'putaway_scan_accuracy': ReadinessCategory.receiving,
  'putaway_zone_control': ReadinessCategory.receiving,
  'quality_hold_decision': ReadinessCategory.receiving,
  'quality_segregation': ReadinessCategory.receiving,
  'receiving_damage_check': ReadinessCategory.receiving,
  'receiving_discipline': ReadinessCategory.receiving,
  'receiving_exception_control': ReadinessCategory.receiving,
  'receiving_scan_discipline': ReadinessCategory.receiving,
  'shipment_identity_verification': ReadinessCategory.receiving,
  'shipment_quantity_verification': ReadinessCategory.receiving,
  'supervisor_escalation': ReadinessCategory.receiving,
  'temperature_zone_receiving': ReadinessCategory.receiving,
  'aisle_lane_discipline': ReadinessCategory.processing,
  'fnv_packing_accuracy': ReadinessCategory.processing,
  'hygiene_entry_discipline': ReadinessCategory.processing,
  'load_sequencing': ReadinessCategory.processing,
  'moq_preparation_accuracy': ReadinessCategory.processing,
  // Spans picking/processing -- resolved to processing (first appears on
  // the MOQ-preparation task).
  'order_quantity_control': ReadinessCategory.processing,
  'pack_weight_control': ReadinessCategory.processing,
  'pallet_build_stability': ReadinessCategory.processing,
  'ppe_compliance': ReadinessCategory.processing,
  'processing_discipline': ReadinessCategory.processing,
  'produce_bagging': ReadinessCategory.processing,
  'sack_sealing_accuracy': ReadinessCategory.processing,
  'vegetable_staging': ReadinessCategory.processing,
  'weight_accuracy': ReadinessCategory.processing,
  'weight_verification_discipline': ReadinessCategory.processing,
  'ambient_picking_accuracy': ReadinessCategory.dispatch,
  'ambient_vehicle_loading': ReadinessCategory.dispatch,
  'cold_chain_dock_discipline': ReadinessCategory.dispatch,
  'cold_chain_picking': ReadinessCategory.dispatch,
  'customer_order_accuracy': ReadinessCategory.dispatch,
  'delivery_dispute_resolution': ReadinessCategory.dispatch,
  'delivery_handover_control': ReadinessCategory.dispatch,
  'delivery_handover_discipline': ReadinessCategory.dispatch,
  'dispatch_departure_discipline': ReadinessCategory.dispatch,
  'dispatch_order_merge': ReadinessCategory.dispatch,
  'dispatch_route_verification': ReadinessCategory.dispatch,
  'dispatch_security_seal_verification': ReadinessCategory.dispatch,
  'dispatch_staging_completion': ReadinessCategory.dispatch,
  'forklift_pedestrian_safety': ReadinessCategory.dispatch,
  'fragile_item_handling': ReadinessCategory.dispatch,
  'frozen_picking_accuracy': ReadinessCategory.dispatch,
  'last_mile_cold_chain_verification': ReadinessCategory.dispatch,
  'load_verification': ReadinessCategory.dispatch,
  'loading_sequence_control': ReadinessCategory.dispatch,
  'missing_item_escalation': ReadinessCategory.dispatch,
  'perishable_loading': ReadinessCategory.dispatch,
  'picking_aisle_awareness': ReadinessCategory.dispatch,
  'picking_load_sequencing': ReadinessCategory.dispatch,
  'pre_loading_temperature_check': ReadinessCategory.dispatch,
  'proof_of_delivery': ReadinessCategory.dispatch,
  'shortage_verification': ReadinessCategory.dispatch,
  'sortation_accuracy': ReadinessCategory.dispatch,
  'spr_location_scan': ReadinessCategory.dispatch,
  'tamper_evident_loading': ReadinessCategory.dispatch,
  'temperature_zone_dispatch': ReadinessCategory.dispatch,
  'cash_submission_control': ReadinessCategory.supervisor,
  // domain: supervisor despite the name -- a supervisor briefs drivers on
  // their route assignment, it isn't the driver's own dispatch competency.
  'dispatch_route_assignment': ReadinessCategory.supervisor,
  'pre_departure_briefing': ReadinessCategory.supervisor,
  'produce_packing_verification': ReadinessCategory.supervisor,
  'returnable_asset_reconciliation': ReadinessCategory.supervisor,
  'returns_quarantine_control': ReadinessCategory.supervisor,
  'returns_reconciliation': ReadinessCategory.supervisor,
  'route_closure_accuracy': ReadinessCategory.supervisor,
  'route_closure_discipline': ReadinessCategory.supervisor,
  'route_settlement_control': ReadinessCategory.supervisor,
  'settlement_exception_handling': ReadinessCategory.supervisor,
  'supervisor_disposition': ReadinessCategory.supervisor,
  'supervisor_quality_oversight': ReadinessCategory.supervisor,
};

/// Aggregate readiness signal for one [ReadinessCategory], derived from
/// every [CareerPassportEntry] whose competency maps into it.
class RoleReadinessSummary {
  const RoleReadinessSummary({
    required this.category,
    required this.level,
    required this.averageScore,
    required this.evidenceCount,
  });

  final ReadinessCategory category;
  final ReadinessLevel level;

  /// 0-100, or null when [evidenceCount] is 0 (nothing to average).
  final int? averageScore;
  final int evidenceCount;
}

/// Buckets [entries] by [competencyReadinessCategories], averages the score
/// of every entry whose freshness is active or stale (superseded entries
/// are excluded -- they are not the candidate's current standing, matching
/// how Career Passport itself treats them), and maps the average onto the
/// same proficiency ladder `competencies.json` already defines
/// (Competent=70 -> ready, Developing=50 -> developing, below -> needs
/// practice). Always returns exactly one summary per [ReadinessCategory],
/// in enum declaration order, even when a category has no evidence at all
/// (-> [ReadinessLevel.unknown]). Pure and deterministic, same shape as
/// [deriveCareerPassportEntries].
List<RoleReadinessSummary> deriveRoleReadiness(
  List<CareerPassportEntry> entries,
) {
  final scoresByCategory = <ReadinessCategory, List<int>>{
    for (final category in ReadinessCategory.values) category: [],
  };
  for (final entry in entries) {
    if (entry.freshness == EvidenceFreshnessState.superseded) continue;
    final category = competencyReadinessCategories[entry.evidence.competencyId];
    if (category == null) continue;
    scoresByCategory[category]!.add(entry.evidence.score);
  }
  return [
    for (final category in ReadinessCategory.values)
      _summaryFor(category, scoresByCategory[category]!),
  ];
}

RoleReadinessSummary _summaryFor(ReadinessCategory category, List<int> scores) {
  if (scores.isEmpty) {
    return RoleReadinessSummary(
      category: category,
      level: ReadinessLevel.unknown,
      averageScore: null,
      evidenceCount: 0,
    );
  }
  final average = (scores.reduce((a, b) => a + b) / scores.length).round();
  final level = average >= 70
      ? ReadinessLevel.ready
      : average >= 50
      ? ReadinessLevel.developing
      : ReadinessLevel.needsPractice;
  return RoleReadinessSummary(
    category: category,
    level: level,
    averageScore: average,
    evidenceCount: scores.length,
  );
}

String readinessCategoryLabel(ReadinessCategory category) => switch (category) {
  ReadinessCategory.receiving => 'Receiving',
  ReadinessCategory.processing => 'Processing',
  ReadinessCategory.dispatch => 'Dispatch',
  ReadinessCategory.supervisor => 'Supervisor',
};

String readinessLevelLabel(ReadinessLevel level) => switch (level) {
  ReadinessLevel.ready => 'Ready',
  ReadinessLevel.developing => 'Developing',
  ReadinessLevel.needsPractice => 'Needs practice',
  ReadinessLevel.unknown => 'Unknown',
};
