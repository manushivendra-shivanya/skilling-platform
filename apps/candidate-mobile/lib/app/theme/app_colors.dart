import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color brand = Color(0xFF075C42);
  static const Color brandDark = Color(0xFF003D2B);
  static const Color brandSoft = Color(0xFFD9F1E6);
  static const Color accent = Color(0xFFB85C13);
  static const Color accentSoft = Color(0xFFFFE8D2);

  static const Color canvas = Color(0xFFF8F6F0);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF0F3EF);
  static const Color ink = Color(0xFF17231E);
  static const Color inkMuted = Color(0xFF56635D);
  static const Color outline = Color(0xFF738079);

  static const Color success = Color(0xFF176B3A);
  static const Color successSoft = Color(0xFFDDF4E5);
  static const Color warning = Color(0xFF855400);
  static const Color warningSoft = Color(0xFFFFEDC7);
  static const Color error = Color(0xFFB3261E);
  static const Color errorSoft = Color(0xFFFFDAD6);
  static const Color info = Color(0xFF075A83);
  static const Color infoSoft = Color(0xFFD6EFFF);

  // A 7th tile tone for the Home "today services" rail -- distinct from the
  // 6 above (success/info/accent/warning/brand/ink) so every service card
  // reads as its own color, not a repeat.
  static const Color teal = Color(0xFF0F6E6E);
  static const Color tealSoft = Color(0xFFD7F0EE);

  // Bright accent reserved for "this is the active step" indicators on the
  // dark ink background (journey stepper, readiness ring) -- warning/accent
  // are both too close in value to ink to read clearly there.
  static const Color highlight = Color(0xFFFFC933);

  // Fixed dark chrome tone for persistent structural chrome that sits above
  // sector-pack content (e.g. the Lessons/Practise/Certification segmented
  // tab bar) -- deliberately NOT derived from any per-sector colour.
  // Darkening a pack's `primaryAccent` toward black works for a one-off
  // focal object like the credential card (reviewed, kept intentionally),
  // but this bar is persistent chrome visible on every screen in the
  // destination, sitting directly against each screen's light content --
  // darkening warehouse's orange primaryAccent that way produced a muddy
  // brown that read as an error state, not a dark UI chrome tone (caught
  // via real-device dogfooding, see docs/26-sector-pack-rollout.md). Value
  // matches the navy already contrast-verified in the Shift Floor mock.
  static const Color navy = Color(0xFF16233B);
}
