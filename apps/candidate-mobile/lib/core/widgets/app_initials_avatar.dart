import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';

/// A colored circle or rounded-square holding a name's initials -- the
/// "initials avatar" Jobs' `_SourceAvatar` (rounded-square, per-employer)
/// and Profile's `_IdentityHeader` (circle, the candidate's own name) each
/// independently hand-rolled with slightly different shapes and derivation
/// call sites. Consolidated here so every screen that needs one (Career
/// Passport's employer rows, Role Readiness, the Persona card, Networking)
/// shares exactly one initials-derivation implementation instead of two
/// that could silently drift.
///
/// Initials: up to the first 2 whitespace-separated words in [name], first
/// letter of each, uppercased -- matches `_SourceAvatar`'s exact rule.
class AppInitialsAvatar extends StatelessWidget {
  const AppInitialsAvatar({
    required this.name,
    this.background,
    this.foreground,
    this.size = 40,
    this.circular = true,
    super.key,
  });

  final String name;
  final Color? background;
  final Color? foreground;
  final double size;

  /// True for a circle (Profile's own identity header), false for a
  /// rounded-square (Jobs' per-employer avatars).
  final bool circular;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0].toUpperCase())
        .join();
    final resolvedBackground = background ?? AppColors.brandSoft;
    final resolvedForeground = foreground ?? AppColors.brand;

    return Semantics(
      label: name,
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: resolvedBackground,
            shape: circular ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: circular ? null : AppRadius.mediumBorder,
          ),
          child: Text(
            initials,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: (size / 3).roundToDouble(),
              color: resolvedForeground,
            ),
          ),
        ),
      ),
    );
  }
}
