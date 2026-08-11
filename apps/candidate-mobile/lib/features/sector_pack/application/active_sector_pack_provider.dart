import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/sector_pack.dart';

/// The [SectorPack] the Lessons/Practise/Certification screens resolve
/// today. Hardcoded to [SectorPacks.warehouseLogistics] -- per
/// `docs/26-sector-pack-rollout.md`, no entry point (role -> pack lookup)
/// exists yet, and only the warehouse pack is live in the pilot. See that
/// doc's "Entry point" section for the plan once a second pack is wired.
///
/// Deliberately a `Provider`, not a constant import, even though it's a
/// fixed value today: every screen that needs a pack reads it from here,
/// so swapping this one line for a real role-based resolver later is a
/// provider-body change, not a hunt through every call site.
final activeSectorPackProvider = Provider<SectorPack>(
  (ref) => SectorPacks.warehouseLogistics,
);
