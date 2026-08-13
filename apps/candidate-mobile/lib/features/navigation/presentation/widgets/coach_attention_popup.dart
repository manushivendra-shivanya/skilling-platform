import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/coach_mark.dart';
import '../../../../core/widgets/reduced_motion.dart';

/// A brief, self-dismissing speech bubble above the AI Coach FAB, shown
/// once the first time Home appears in a session -- so the coach entry
/// point gets noticed once rather than sitting silent under everything
/// else on the dashboard (readiness ring, today's mission, the interview
/// card) that's competing for the same first glance.
///
/// Wraps [child] (the FAB itself) instead of living in `HomeDashboardScreen`
/// or the app bar: that keeps the bubble anchored to the exact button it
/// points at no matter where `floatingActionButtonLocation` puts it, and it
/// disappears for free the moment the FAB does (switching tabs unmounts
/// this widget along with it, cancelling the dismiss timer in [dispose]).
///
/// Fires a light haptic tick when the bubble appears -- the same
/// platform-channel feedback the Coach thread screens already use for "the
/// coach noticed something" moments (`ask_coach_affordance.dart`,
/// `coach_thread_screen.dart`) -- rather than relying on sight alone, which
/// is what actually gets felt with the phone in a pocket or on a noisy
/// factory floor.
class CoachAttentionPopup extends StatefulWidget {
  const CoachAttentionPopup({
    required this.child,
    required this.onTap,
    this.onShown,
    super.key,
  });

  final Widget child;

  /// Called when the candidate taps the bubble itself -- opens the coach
  /// directly, same as tapping the FAB it's pointing at.
  final VoidCallback onTap;

  /// Called once the bubble actually becomes visible, so the caller can log
  /// an impression separately from the FAB's own open event.
  final VoidCallback? onShown;

  @override
  State<CoachAttentionPopup> createState() => _CoachAttentionPopupState();
}

class _CoachAttentionPopupState extends State<CoachAttentionPopup>
    with SingleTickerProviderStateMixin {
  // Module-level (not a field): `StatefulNavigationShell` unmounts this
  // widget every time the candidate leaves Home and remounts a fresh one
  // on return -- see `main_navigation_shell.dart`'s `_buildFab` -- so a
  // plain instance flag would replay the popup on every single visit back
  // to Home within a session. This survives that remount, and only that:
  // it's a static, so a cold app restart clears it and the popup earns its
  // one showing again, same as any other "noticed it once" affordance.
  static bool _shownThisSession = false;

  // "for 2 seconds" per the request -- measured from when the bubble
  // finishes animating in, not from when the timer starts, so reduced-
  // motion (which skips the entrance animation) doesn't shorten how long
  // it's actually legible on screen.
  static const _visibleDuration = Duration(seconds: 2);

  // Waits for Home's own entrance (the gradient header, the mission card)
  // to settle first -- popping this up at frame zero would just be one
  // more thing arriving at once, defeating the point of it standing out.
  static const _entranceDelay = Duration(milliseconds: 700);

  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  Timer? _entranceTimer;
  Timer? _dismissTimer;
  bool _dismissed = false;
  bool _started = false;

  /// Whether *this* instance is the one that won the session-wide
  /// `_shownThisSession` race and should therefore actually render the
  /// bubble. Decided synchronously in [didChangeDependencies], not inside
  /// [_run]'s `await`ed body, so [build] (which can run before that await
  /// resolves) never has to guess whether a bubble is coming.
  bool _active = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `didChangeDependencies` (not `initState`) because reading
    // `prefersReducedMotion` needs an inherited-widget-ready `context`;
    // `_started` guards it to the same "runs exactly once per mount" as a
    // plain `initState` call would give.
    if (_started) return;
    _started = true;
    if (_shownThisSession) return;
    _shownThisSession = true;
    _active = true;
    _run();
  }

  // A stored `Timer` (not `Future.delayed`, which schedules its own Timer
  // with nothing left to hold onto) so `dispose` can actually cancel it --
  // matches the convention `app_loading_progress.dart` documents: Timer-
  // driven, every Timer kept in a field, all of them cancelled together in
  // `dispose`. An untracked delayed Future here was a real bug, not just a
  // style nit: it left a Timer armed in the test binding's fake-async zone
  // past widget disposal, tripping `!timersPending` in any test whose flow
  // happens to reach Home before the 700ms entrance delay elapses.
  void _run() {
    _entranceTimer = Timer(_entranceDelay, () {
      if (!mounted || _dismissed) return;
      unawaited(HapticFeedback.lightImpact());
      widget.onShown?.call();
      if (prefersReducedMotion(context)) {
        _controller.value = 1;
      } else {
        unawaited(_controller.forward());
      }
      _dismissTimer = Timer(_visibleDuration, _dismiss);
    });
  }

  void _dismiss() {
    if (!mounted || _dismissed) return;
    setState(() => _dismissed = true);
    if (prefersReducedMotion(context)) {
      _controller.value = 0;
    } else {
      unawaited(_controller.reverse());
    }
  }

  void _handleTap() {
    _dismissTimer?.cancel();
    _dismiss();
    widget.onTap();
  }

  @override
  void dispose() {
    _entranceTimer?.cancel();
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        widget.child,
        // `_active` is false for every instance except the one that won
        // the session-wide race in `didChangeDependencies` -- everyone
        // else (a later mount, after the session has already shown its
        // one bubble) skips the overlay entirely rather than building and
        // immediately hiding a bubble that was never going to animate.
        // Once fully dismissed, the *active* bubble stays mounted at scale
        // 0 rather than being removed from the tree -- cheap (a few
        // Text/Icon widgets) and avoids the FAB jumping size as a sibling
        // pops out of this Stack.
        if (_active && (!_dismissed || _controller.value > 0))
          Positioned(
            bottom: 68,
            // `ScaleTransition` only affects painting, not layout, so the
            // bubble's hit-test area is full-size even while it's scaled
            // to invisible during the entrance delay -- `IgnorePointer`
            // keeps a stray tap in that dead zone from opening the coach
            // before the candidate has actually seen anything appear.
            child: IgnorePointer(
              ignoring: _dismissTimer == null || _dismissed,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _handleTap,
                child: FadeTransition(
                  key: const Key('coachAttentionPopupBubbleFade'),
                  opacity: _opacity,
                  child: ScaleTransition(
                    scale: _scale,
                    alignment: Alignment.bottomCenter,
                    child: const _Bubble(),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'AI Coach is here. Tap to ask a question.',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        constraints: const BoxConstraints(maxWidth: 220),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.largeBorder,
          border: Border.all(color: AppColors.brand.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CoachMark(size: 16, color: AppColors.brand),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                'Poocho mujhse! · Ask me anything',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
