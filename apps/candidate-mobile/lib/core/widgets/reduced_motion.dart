import 'package:flutter/material.dart';

/// The one place this app reads the OS "reduce motion" accessibility
/// setting (Android: Settings > Accessibility > Remove animations;
/// iOS: Settings > Accessibility > Motion > Reduce Motion) from.
///
/// Always call this instead of `MediaQuery.of(context).disableAnimations`
/// or `MediaQuery.maybeDisableAnimationsOf(context)` directly -- before
/// this helper existed, the app's four custom `AnimationController`
/// sites had each independently spelled the same check three different
/// ways (a straight repo-wide grep confirmed it), which is exactly the
/// kind of drift that leaves the next hand-authored controller with no
/// check at all. `disableAnimationsOf` (not the full `MediaQuery.of`
/// form) is the deliberate choice here: it subscribes only to that one
/// MediaQuery aspect, so a widget using this doesn't rebuild on every
/// unrelated MediaQuery change (keyboard opening, text scale, etc.) the
/// way `MediaQuery.of(context).disableAnimations` would.
bool prefersReducedMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context);

/// Covers the common case: an [AnimationController] that should play
/// once, forward, the first time its owning widget becomes visible
/// (typically called from `didChangeDependencies`, guarded by a
/// `_started` flag so it only runs once -- see
/// `SimulationScreenReveal`/`_MessageEntrance`/`_StaggeredEntrance` for
/// the full pattern) -- unless reduce-motion is on, in which case it
/// should jump straight to its resting value instead of animating there.
extension ReducedMotionAnimationController on AnimationController {
  void forwardUnlessReducedMotion(BuildContext context) {
    if (prefersReducedMotion(context)) {
      value = 1;
    } else {
      forward();
    }
  }
}
