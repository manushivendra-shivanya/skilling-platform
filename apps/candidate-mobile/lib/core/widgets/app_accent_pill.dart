import 'package:flutter/material.dart';

import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';

/// A small pill: an icon and a bold label on a colored background. Jobs'
/// `_TopMatchRibbon` (pinned above the #1 For-you card) and Shift's
/// `_UrgencyRibbon` (a full-width "starts soon" banner) each hand-rolled
/// their own version of this -- same shape in spirit (icon, gap, bold
/// text, colored container), genuinely different in scale and tone. This
/// widget shares only the *styling*; each call site keeps its own
/// `Positioned`/inline placement, since where the pill sits on screen is
/// specific to what it's announcing, not something a shared widget should
/// own.
///
/// Every visual knob that the two donor call sites disagreed on
/// ([iconSize], [fontSize], [padding], [borderRadius], [expand]) is a
/// parameter here rather than baked in, so both keep their exact existing
/// look. [fontSize] defaults to null (inherit the ambient text style)
/// because that's what Shift's banner relied on -- pass an explicit value
/// only where the original did, like Jobs' compact ribbon.
class AppAccentPill extends StatelessWidget {
  const AppAccentPill({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    this.iconSize = 14,
    this.fontSize,
    this.fontWeight = FontWeight.w800,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.xs,
      vertical: 4,
    ),
    this.borderRadius = AppRadius.pill,
    this.boxShadow,
    this.expand = false,
    this.semanticLabel,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final double iconSize;
  final double? fontSize;
  final FontWeight fontWeight;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final List<BoxShadow>? boxShadow;

  /// True stretches the pill to fill its parent's width (Shift's banner);
  /// false sizes it to its content (Jobs' compact ribbon).
  final bool expand;

  /// When set, wraps the pill in a [Semantics] node carrying this label --
  /// matching Jobs' ribbon, which announces "Top match for you" as a
  /// standalone fact. Left null reproduces Shift's banner, which relies on
  /// the icon/text's own default semantics instead.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      width: expand ? double.infinity : null,
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: boxShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: foreground),
          const SizedBox(width: AppSpacing.xxs),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: fontWeight,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );

    if (semanticLabel == null) {
      return pill;
    }
    return Semantics(label: semanticLabel, child: pill);
  }
}
