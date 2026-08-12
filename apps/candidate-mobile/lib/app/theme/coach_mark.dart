import 'package:flutter/material.dart';

/// The AI Coach's own identity mark: a small point (where the candidate
/// is) curving up to an arrowhead (where the coach is guiding them).
/// Custom-drawn on purpose -- it replaces `Icons.auto_awesome`, the same
/// sparkle glyph every AI feature in every app already uses, everywhere
/// the app previously referenced `AppIcons.coach` (splash, sign-in,
/// onboarding welcome, the global nav shell's FAB, the dev-tools icon
/// gallery, and every Coach screen). See docs/27-ai-coach-plan.md for the
/// design reference this was built from.
///
/// Deliberately not a `SectorGlyph` -- Coach is global chrome, reachable
/// regardless of the candidate's active sector pack, so this mark must
/// stay outside `sector_pack_icons.dart`'s sector-scoped set (see
/// `docs/adr/0020-sector-pack-abstraction.md`).
class CoachMark extends StatelessWidget {
  const CoachMark({this.size = 20, this.color, super.key});

  final double size;

  /// Defaults to the current [IconTheme] colour (matching how `Icon`
  /// behaves), then falls back to the current text colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor =
        color ??
        IconTheme.of(context).color ??
        DefaultTextStyle.of(context).style.color ??
        Colors.black;
    // `Center` (not just `SizedBox`) is load-bearing: a `SizedBox`'s own
    // width/height are only *preferred* -- an ancestor that hands down a
    // tight constraint (a `Column` with `crossAxisAlignment: stretch`, in
    // particular) overrides them straight through to `CustomPaint`, which
    // then paints this mark's geometry at that stretched width while
    // `paint()`'s `size` still reports the correct 56-ish height, blowing
    // the unclipped path out past the intended box (real-device report: a
    // giant diagonal arrow across the whole sign-in screen). `Center`
    // gives its child loosened constraints regardless of what it itself
    // receives, so the mark always renders at exactly `size`, with any
    // extra stretched space simply left blank around it.
    return ExcludeSemantics(
      child: Center(
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            size: Size.square(size),
            painter: _CoachMarkPainter(resolvedColor),
          ),
        ),
      ),
    );
  }
}

class _CoachMarkPainter extends CustomPainter {
  _CoachMarkPainter(this.color);

  final Color color;

  // 24x24 reference viewBox, same geometry as the published design
  // reference: a filled start-point, a curve, and a two-stroke chevron
  // arrowhead -- kept as simple, hand-legible geometry rather than a long
  // traced path.
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(5.5, 17.5) * scale, 1.6 * scale, dotPaint);

    final curve = Path()
      ..moveTo(7 * scale, 16.3 * scale)
      ..cubicTo(
        9.5 * scale,
        13.8 * scale,
        12.5 * scale,
        8.5 * scale,
        17.5 * scale,
        6 * scale,
      );
    canvas.drawPath(curve, strokePaint);

    final chevron = Path()
      ..moveTo(13.7 * scale, 5.6 * scale)
      ..lineTo(17.8 * scale, 5.4 * scale)
      ..lineTo(18.3 * scale, 9.4 * scale);
    canvas.drawPath(chevron, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _CoachMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}
