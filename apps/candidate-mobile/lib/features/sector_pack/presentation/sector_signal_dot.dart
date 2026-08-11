import 'package:flutter/material.dart';

import '../domain/sector_pack.dart';

/// The three states a [SectorSignalDot] can render -- deliberately just the
/// three colours [SectorSignalPalette] defines, no generic fourth "info"
/// state. See `SectorPack.signalSource` for what these map to in a given
/// sector's own world (a dock light, a traffic light, ...).
enum SectorSignalState { locked, active, cleared }

/// Structural widget 1 of 4 (docs/adr/0020-sector-pack-abstraction.md): the
/// status-signal indicator -- the "lamp dot" in the published Shift Floor
/// mock. Sector-blind: every colour comes from [pack], nothing is
/// hardcoded here.
class SectorSignalDot extends StatelessWidget {
  const SectorSignalDot({
    required this.pack,
    required this.state,
    this.size = 9,
    this.semanticLabel,
    super.key,
  });

  final SectorPack pack;
  final SectorSignalState state;
  final double size;

  /// Optional a11y label. Leave null when this dot sits immediately next
  /// to text that already says the same thing (the common case in the
  /// other three structural widgets) -- duplicating it would make a
  /// screen reader repeat itself.
  final String? semanticLabel;

  Color get _color => switch (state) {
    SectorSignalState.locked => pack.signalPalette.locked,
    SectorSignalState.active => pack.signalPalette.active,
    SectorSignalState.cleared => pack.signalPalette.cleared,
  };

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
    );
    if (semanticLabel == null) {
      return ExcludeSemantics(child: dot);
    }
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(child: dot),
    );
  }
}
