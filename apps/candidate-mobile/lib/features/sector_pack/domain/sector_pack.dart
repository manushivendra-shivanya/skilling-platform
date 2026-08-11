import 'package:flutter/material.dart';

/// Identifies which real-world trade a Lessons/Practise/Certification
/// screen set is currently skinned for.
///
/// See `docs/adr/0020-sector-pack-abstraction.md` for why this exists: the
/// screen *structure* (a status-signal widget, an index-tagged list row, a
/// task-object card, a credential card) is shared, sector-blind code —
/// only the data below changes per sector. Only [warehouseLogistics] is
/// wired to the shipped app today; every other pack here is a design
/// reference, not yet implemented. See
/// `docs/26-sector-pack-rollout.md` for the QC bar a pack has to clear
/// before it can move from reference to wired.
enum SectorPackId { warehouseLogistics, lastMileDelivery }

/// The sector-specific signal colours a pack's status-bearing widgets read
/// from. `locked`/`active`/`cleared` map onto whatever real signal system
/// the sector uses — see [SectorPack.signalSource] for what that is.
///
/// Deliberately three colours, not a generic palette: the whole point of
/// a SectorPack is that these aren't picked freely, they're read off a
/// real object (a dock light, a traffic light) named in [SectorPack.signalSource].
@immutable
class SectorSignalPalette {
  const SectorSignalPalette({
    required this.locked,
    required this.active,
    required this.cleared,
  });

  final Color locked;
  final Color active;
  final Color cleared;
}

/// One sector's design data: the real-world referents that drive the
/// shared structural widgets without changing their implementation.
///
/// Every field here should trace to something named and checkable, not an
/// invented label — that's what the QC checklist in
/// `docs/26-sector-pack-rollout.md` reviews before a pack ships.
@immutable
class SectorPack {
  const SectorPack({
    required this.id,
    required this.displayName,
    required this.pilotRole,
    required this.signalSource,
    required this.signalPalette,
    required this.primaryAccent,
    required this.listItemLabel,
    required this.taskObjectLabel,
    required this.credentialLabel,
    required this.isReferenceImplementation,
  });

  final SectorPackId id;

  /// e.g. "Warehouse & Logistics".
  final String displayName;

  /// The pilot job role this pack was designed against, e.g.
  /// "Warehouse Operations Associate".
  final String pilotRole;

  /// What [signalPalette]'s colours literally represent in this sector's
  /// own world — e.g. "Loading-dock status lights", "Road traffic light".
  /// A pack whose signal source is generic ("a status colour system") has
  /// not cleared design review; see docs/26.
  final String signalSource;

  final SectorSignalPalette signalPalette;

  /// The one accent colour used for primary actions (a "GO" / "Resume"
  /// button) and brand-adjacent chrome. Distinct from [signalPalette] so a
  /// content-type tag (e.g. "Scored") never collides with a status colour
  /// — a real bug caught while building the last-mile pack (see the
  /// dogfooding log in docs/26).
  final Color primaryAccent;

  /// What a rack-bin-equivalent row is called in this sector, e.g.
  /// "Rack Bin" (warehouse) / "Route Stop" (last-mile).
  final String listItemLabel;

  /// What a job-ticket-equivalent card is called, e.g. "Job Ticket"
  /// (warehouse) / "Trip Request" (last-mile).
  final String taskObjectLabel;

  /// What the certification credential is called, e.g. "Access Badge"
  /// (warehouse) / "Rider & Vehicle ID" (last-mile).
  final String credentialLabel;

  /// True once the pack has a published design reference that cleared
  /// docs/26's QC checklist. False means spec-only / not yet designed.
  /// Neither state means the pack is wired into the live app — that is a
  /// separate, later step tracked per-pack in docs/26's entry-point notes.
  final bool isReferenceImplementation;
}

/// The packs defined so far.
///
/// Only [warehouseLogistics] is live in the shipped app — the sole pilot
/// sector per `docs/00-master-plan.md`'s phase gate. The others are design
/// references (published mocks) or specs, not implementations; see
/// `docs/26-sector-pack-rollout.md` for status per pack.
abstract final class SectorPacks {
  static const warehouseLogistics = SectorPack(
    id: SectorPackId.warehouseLogistics,
    displayName: 'Warehouse & Logistics',
    pilotRole: 'Warehouse Operations Associate',
    signalSource: 'Loading-dock status lights',
    signalPalette: SectorSignalPalette(
      // Not yet AppColors tokens — hazard amber in particular is new to
      // this design pass and needs adding to app_colors.dart before this
      // pack is wired to a real screen (see docs/26's per-pack notes).
      locked: Color(0xFF56635D),
      active: Color(0xFFF5B700),
      cleared: Color(0xFF176B3A), // == AppColors.success
    ),
    primaryAccent: Color(0xFFB85C13), // == AppColors.accent
    listItemLabel: 'Rack Bin',
    taskObjectLabel: 'Job Ticket',
    credentialLabel: 'Access Badge',
    isReferenceImplementation: true,
  );

  static const lastMileDelivery = SectorPack(
    id: SectorPackId.lastMileDelivery,
    displayName: 'Last-Mile Delivery Partner',
    pilotRole: 'Last-Mile Delivery Partner',
    signalSource: 'Road traffic light',
    signalPalette: SectorSignalPalette(
      locked: Color(0xFFD62828),
      active: Color(0xFFF2A900),
      cleared: Color(0xFF1E9142),
    ),
    // A deeper green than signalPalette.cleared, not the same token: the
    // published mock uses one green for both the primary CTA and the
    // "cleared" status, which is the exact collision class this file's
    // test guards against (just imperceptible at that value). Kept
    // distinct here since this domain model is the canonical reference
    // going forward — the mock can stay as published.
    primaryAccent: Color(0xFF0F6E30),
    listItemLabel: 'Route Stop',
    taskObjectLabel: 'Trip Request',
    credentialLabel: 'Rider & Vehicle ID',
    isReferenceImplementation: true,
  );

  static const all = <SectorPack>[warehouseLogistics, lastMileDelivery];

  static SectorPack byId(SectorPackId id) =>
      all.firstWhere((pack) => pack.id == id);
}
