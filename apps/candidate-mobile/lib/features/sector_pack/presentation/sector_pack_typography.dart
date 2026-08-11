import 'package:flutter/material.dart';

/// Type styles for the four sector-pack structural widgets
/// (`sector_signal_dot.dart`, `sector_index_row.dart`, `sector_task_card.dart`,
/// `sector_credential_card.dart`) and the Learn tab's segmented state bar.
///
/// Deliberately **not** registered in `app_theme.dart`'s global `textTheme`
/// -- see `docs/adr/0020-sector-pack-abstraction.md`: per-sector visual
/// identity (including type) must stay scoped to the widgets that opted
/// into it, never leak into the shared theme. Every `Text` inside those
/// widgets should reach for a style from here directly rather than
/// `Theme.of(context).textTheme`.
///
/// Rationale for the two faces (docs/26 QC checklist requires a stated
/// rationale, not "it looked fine"): Big Shoulders is a condensed
/// industrial-signage face -- modelled on the lettering painted on real
/// warehouse racking and hazard signage, used here only for
/// headline-weight labels (a rack-bin title, a credential name). IBM Plex
/// Sans is IBM's own technical-documentation face, chosen for body copy
/// because it stays legible at the small sizes a dense operational list
/// demands. IBM Plex Mono renders the same family's monospace cut, used
/// for the tabular/coded strings a real warehouse floor actually produces
/// (work-order numbers, bin codes, timestamps) so they read as data, not
/// prose.
abstract final class SectorPackTypography {
  static const String display = 'Sector Big Shoulders';
  static const String body = 'Sector IBM Plex Sans';
  static const String mono = 'Sector IBM Plex Mono';

  /// Headline-weight label set in the industrial-signage face. Always
  /// weight 800 -- the only weight bundled for this pass (see
  /// docs/26-sector-pack-rollout.md's font-subset note).
  static TextStyle displayLabel({
    required Color color,
    double fontSize = 15,
    double letterSpacing = 0.2,
    double height = 1.05,
  }) => TextStyle(
    fontFamily: display,
    fontWeight: FontWeight.w800,
    color: color,
    fontSize: fontSize,
    letterSpacing: letterSpacing,
    height: height,
  );

  static TextStyle bodyRegular({required Color color, double fontSize = 13}) =>
      TextStyle(
        fontFamily: body,
        fontWeight: FontWeight.w400,
        color: color,
        fontSize: fontSize,
      );

  static TextStyle bodySemiBold({required Color color, double fontSize = 13}) =>
      TextStyle(
        fontFamily: body,
        fontWeight: FontWeight.w600,
        color: color,
        fontSize: fontSize,
      );

  static TextStyle bodyBold({required Color color, double fontSize = 14.5}) =>
      TextStyle(
        fontFamily: body,
        fontWeight: FontWeight.w700,
        color: color,
        fontSize: fontSize,
      );

  /// Small, tracked-out labels for tags/status text -- work-order numbers,
  /// bin/index codes, timestamps.
  static TextStyle monoLabel({
    required Color color,
    double fontSize = 10.5,
    double letterSpacing = 0.3,
    FontWeight fontWeight = FontWeight.w500,
  }) => TextStyle(
    fontFamily: mono,
    fontWeight: fontWeight,
    color: color,
    fontSize: fontSize,
    letterSpacing: letterSpacing,
  );
}
