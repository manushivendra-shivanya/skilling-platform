import 'package:flutter/material.dart';

/// Custom stroke icons for the four sector-pack structural widgets, drawn
/// as [CustomPainter]s rather than pulled from a package or Material's
/// bundled icon font -- see docs/26-sector-pack-rollout.md's QC checklist:
/// "Icon set is custom-drawn stroke icons, one consistent weight -- no
/// emoji, no bare stock Material icons dropped in raw." This is a
/// deliberate, documented exception scoped to these widgets only; every
/// other icon in the app keeps using `app/theme/app_icons.dart`'s bare
/// Material icons unchanged.
///
/// Geometry is traced from the published Shift Floor mock's `<symbol>`
/// defs (24x24 viewBox, round caps/joins) -- see the mock's `i-play`,
/// `i-check`, `i-cross`, `i-lock`, `i-download` symbols. [pending],
/// [chevronRight], [truck], and [mic] are traced the same way from the
/// "Full Coverage" mock's `i-hourglass`, `i-arrow`, `i-truck`, and `i-mic`
/// symbols (added while restyling `WarehouseClipsSection` and Practice's
/// Catalogue rows -- see docs/26-sector-pack-rollout.md's dogfooding log).
/// [radioUnselected] / [radioSelected] are traced from the approved
/// "Practice — remaining screens, styled" mock's inline `.demo-glyph` SVGs
/// (added for the inventory-demo selection cards).
enum SectorGlyph {
  play,
  check,
  cross,
  lock,
  download,
  pending,
  chevronRight,
  truck,
  mic,
  radioUnselected,
  radioSelected,
}

/// One consistent stroke weight across the whole set, per the QC
/// checklist above -- do not vary this per icon.
const double sectorIconStrokeWidth = 1.8;

class SectorIcon extends StatelessWidget {
  const SectorIcon({
    required this.glyph,
    required this.color,
    this.size = 18,
    super.key,
  });

  final SectorGlyph glyph;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Decorative only -- every use in the four structural widgets pairs
    // this with adjacent text, matching app_icons.dart's own convention
    // ("Icons ... must never be the only indication of meaning").
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _SectorIconPainter(glyph: glyph, color: color),
        ),
      ),
    );
  }
}

class _SectorIconPainter extends CustomPainter {
  const _SectorIconPainter({required this.glyph, required this.color});

  final SectorGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = sectorIconStrokeWidth / scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.scale(scale);
    switch (glyph) {
      case SectorGlyph.play:
        canvas.drawPath(
          Path()
            ..moveTo(7, 4)
            ..lineTo(21, 12)
            ..lineTo(7, 20)
            ..close(),
          paint,
        );
      case SectorGlyph.check:
        canvas.drawPath(
          Path()
            ..moveTo(4, 12)
            ..lineTo(10, 18)
            ..lineTo(20, 6),
          paint,
        );
      case SectorGlyph.cross:
        canvas
          ..drawLine(const Offset(6, 6), const Offset(18, 18), paint)
          ..drawLine(const Offset(18, 6), const Offset(6, 18), paint);
      case SectorGlyph.lock:
        canvas
          ..drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(5, 11, 14, 9),
              const Radius.circular(1.5),
            ),
            paint,
          )
          ..drawPath(
            Path()
              ..moveTo(8, 11)
              ..lineTo(8, 7)
              ..arcToPoint(
                const Offset(16, 7),
                radius: const Radius.circular(4),
                clockwise: true,
              )
              ..lineTo(16, 11),
            paint,
          );
      case SectorGlyph.download:
        canvas
          ..drawPath(
            Path()
              ..moveTo(12, 4)
              ..lineTo(12, 15),
            paint,
          )
          ..drawPath(
            Path()
              ..moveTo(7, 11)
              ..lineTo(12, 16)
              ..lineTo(17, 11),
            paint,
          )
          ..drawLine(const Offset(4, 19.5), const Offset(20, 19.5), paint);
      case SectorGlyph.pending:
        canvas
          ..drawLine(const Offset(6, 3), const Offset(18, 3), paint)
          ..drawLine(const Offset(6, 21), const Offset(18, 21), paint)
          ..drawPath(
            Path()
              ..moveTo(7, 3)
              ..lineTo(7, 7)
              ..lineTo(12, 12)
              ..lineTo(17, 7)
              ..lineTo(17, 3),
            paint,
          )
          ..drawPath(
            Path()
              ..moveTo(7, 21)
              ..lineTo(7, 17)
              ..lineTo(12, 12)
              ..lineTo(17, 17)
              ..lineTo(17, 21),
            paint,
          );
      case SectorGlyph.chevronRight:
        canvas.drawPath(
          Path()
            ..moveTo(9, 6)
            ..lineTo(15, 12)
            ..lineTo(9, 18),
          paint,
        );
      case SectorGlyph.truck:
        canvas
          ..drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(1, 7, 12, 9),
              const Radius.circular(1),
            ),
            paint,
          )
          ..drawPath(
            Path()
              ..moveTo(13, 10)
              ..lineTo(17, 10)
              ..lineTo(20, 13)
              ..lineTo(20, 16)
              ..lineTo(13, 16)
              ..close(),
            paint,
          )
          ..drawCircle(const Offset(5.5, 18), 1.6, paint)
          ..drawCircle(const Offset(16.5, 18), 1.6, paint);
      case SectorGlyph.mic:
        canvas
          ..drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(9, 3, 6, 11),
              const Radius.circular(3),
            ),
            paint,
          )
          ..drawPath(
            Path()
              ..moveTo(6, 11)
              ..arcToPoint(
                const Offset(18, 11),
                radius: const Radius.circular(6),
                clockwise: false,
                largeArc: true,
              ),
            paint,
          )
          ..drawLine(const Offset(12, 17), const Offset(12, 21), paint)
          ..drawLine(const Offset(9, 21), const Offset(15, 21), paint);
      case SectorGlyph.radioUnselected:
        canvas.drawCircle(const Offset(12, 12), 8, paint);
      case SectorGlyph.radioSelected:
        canvas
          ..drawCircle(const Offset(12, 12), 8, paint)
          ..drawPath(
            Path()
              ..moveTo(8.5, 12.5)
              ..lineTo(10.8, 14.8)
              ..lineTo(16, 9.5),
            paint,
          );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SectorIconPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}
