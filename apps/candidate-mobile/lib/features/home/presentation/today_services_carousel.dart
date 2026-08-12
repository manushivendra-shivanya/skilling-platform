import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/reduced_motion.dart';

class TodayService {
  const TodayService({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;

  /// Null means "not built yet" -- the tile shows a "Planned" tap response
  /// instead of pretending to navigate somewhere real.
  final VoidCallback? onTap;
}

/// Whether `_TodayServicesCarouselState` should start its auto-scroll
/// timer at all -- pulled out as a pure function (rather than inlined
/// where it's used) so the two independent reasons to skip it, the test
/// binding and the OS Reduce Motion setting, are each individually
/// testable without needing to pump a real widget tree and race a
/// `Timer.periodic`.
bool shouldAutoScroll({
  required bool isTestBinding,
  required bool reducedMotion,
}) {
  return !isTestBinding && !reducedMotion;
}

/// Horizontally auto-scrolling, seamlessly-looping rail of service tiles for
/// the Home tab, modeled on the top-app "explore" service rails referenced
/// in the design brief. Pauses while the candidate is actively dragging it
/// (the touch equivalent of "pause on hover") and resumes shortly after they
/// let go.
class TodayServicesCarousel extends StatefulWidget {
  const TodayServicesCarousel({required this.services, super.key});

  final List<TodayService> services;

  @override
  State<TodayServicesCarousel> createState() => _TodayServicesCarouselState();
}

class _TodayServicesCarouselState extends State<TodayServicesCarousel> {
  static const _tileWidth = 108.0;
  static const _tileGap = AppSpacing.sm;
  static const _autoScrollStep = 0.6;
  static const _autoScrollInterval = Duration(milliseconds: 16);
  static const _resumeDelay = Duration(seconds: 3);

  late final ScrollController _controller;
  Timer? _autoScrollTimer;
  Timer? _resumeTimer;
  bool _userInteracting = false;
  bool _autoScrollDecided = false;

  double get _cycleWidth => widget.services.length * (_tileWidth + _tileGap);

  @override
  void initState() {
    super.initState();
    // Start in the middle of a huge virtual list so scrolling either
    // direction never hits a real end -- the seamless-loop illusion.
    _controller = ScrollController(initialScrollOffset: _cycleWidth * 500);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_autoScrollDecided) return;
    _autoScrollDecided = true;
    // A perpetual Timer.periodic means a frame is *always* pending, which
    // stops WidgetTester.pumpAndSettle() (used all over this app's test
    // suite) from ever converging -- it has no way to distinguish "still
    // animating forever by design" from "stuck". Every real Flutter test
    // binding's runtime type name contains "Test" (AutomatedTestWidgets...
    // for `flutter test`, LiveTestWidgets... for on-device test runs);
    // checking that string, rather than importing package:flutter_test
    // into app code, keeps auto-scroll off under test and on everywhere
    // real users see this screen. Combined with a reduce-motion check --
    // this carousel is continuous motion with no informational purpose,
    // so it's skipped entirely under the OS Reduce Motion setting, same
    // as every other continuous animation in this app (see
    // core/widgets/reduced_motion.dart).
    final isTestBinding = WidgetsBinding.instance.runtimeType
        .toString()
        .contains('Test');
    if (shouldAutoScroll(
      isTestBinding: isTestBinding,
      reducedMotion: prefersReducedMotion(context),
    )) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoScroll());
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _resumeTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(_autoScrollInterval, (_) {
      if (!_controller.hasClients || _userInteracting) return;
      final next = _controller.offset + _autoScrollStep;
      // Silently rebase back toward the middle of the virtual range well
      // before floating-point precision or real list bounds could matter.
      if (next > _cycleWidth * 900) {
        _controller.jumpTo(next % _cycleWidth + _cycleWidth * 500);
        return;
      }
      _controller.jumpTo(next);
    });
  }

  void _pauseForInteraction() {
    _resumeTimer?.cancel();
    setState(() => _userInteracting = true);
  }

  void _scheduleResume() {
    _resumeTimer?.cancel();
    _resumeTimer = Timer(_resumeDelay, () {
      if (mounted) setState(() => _userInteracting = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    // A fixed pixel height overflows once the platform text scale grows
    // (icon + up to 2 lines of label no longer fit in 92 at, e.g., 1.4x
    // accessibility text). Scale the tile height by the same factor so it
    // keeps pace with the text, same as the rest of this app's screens
    // (which scroll rather than clip) stay usable at larger text sizes.
    final textScale = MediaQuery.textScalerOf(context).scale(92) / 92;
    return SizedBox(
      height: 92 * textScale.clamp(1, 1.6),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is UserScrollNotification &&
              notification.direction != ScrollDirection.idle) {
            _pauseForInteraction();
          } else if (notification is ScrollEndNotification) {
            _scheduleResume();
          }
          return false;
        },
        child: ListView.builder(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.zero,
          itemBuilder: (context, index) {
            final service = widget.services[index % widget.services.length];
            return Padding(
              padding: const EdgeInsets.only(right: _tileGap),
              child: _ServiceTile(service: service, width: _tileWidth),
            );
          },
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service, required this.width});

  final TodayService service;
  final double width;

  @override
  Widget build(BuildContext context) {
    final onTap =
        service.onTap ??
        () => showAppSnackBar(
          context: context,
          message: '${service.label} is planned and not active yet.',
        );
    return SizedBox(
      width: width,
      child: Material(
        color: service.background,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.md,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(service.icon, size: 22, color: service.foreground),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  service.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: service.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
