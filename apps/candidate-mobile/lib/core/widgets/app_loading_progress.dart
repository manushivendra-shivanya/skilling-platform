import 'dart:async';

import 'package:flutter/material.dart';

import 'reduced_motion.dart';

/// A single, honest loading affordance for screens whose loading state
/// used to stack multiple competing indicators (an indeterminate
/// [LinearProgressIndicator], a separate spinning [CircularProgressIndicator]
/// + status text, and skeleton placeholders, all at once -- the real
/// complaint this widget answers: "user seems clueless when both keep
/// loading").
///
/// This isn't a real determinate progress (a network fetch has no true
/// percentage) -- it's the same *perceived*-progress pattern GitHub/Slack/
/// Vercel use for their page-load bars: ease toward ~92% and hold, so it
/// reads as "genuinely working," then let the screen's own state change
/// (loading -> data/error) replace this widget outright once the real
/// thing finishes, rather than ever faking a 100% this widget can't
/// actually know is true.
///
/// Timer-driven, not AnimationController -- matches the convention already
/// established in backend_warmup_banner.dart (see its doc comment): Timer
/// callbacks advance together with `tester.pump(duration)`'s fake-async
/// clock in widget tests the same way real time would.
///
/// Respects [prefersReducedMotion]: skips the continuous ease and jumps
/// straight to the ceiling once instead -- see the reasoning in
/// [_AppLoadingProgressBarState.didChangeDependencies].
class AppLoadingProgressBar extends StatefulWidget {
  const AppLoadingProgressBar({
    required this.label,
    this.slowConnectionLabel,
    this.slowConnectionThreshold = const Duration(seconds: 4),
    this.showPercent = false,
    super.key,
  });

  final String label;

  /// Shows the running percentage as a plain number next to the bar
  /// instead of just the bar + label. Same underlying easing curve either
  /// way -- this only changes what's displayed, not how progress is
  /// computed. Deliberately plain: a number and a bar, no extra chrome.
  final bool showPercent;

  /// Shown instead of [label] once [slowConnectionThreshold] elapses
  /// without the caller removing this widget (i.e. without the real load
  /// completing) -- pass a `${elapsed}s`-style callback-free static string
  /// if a live counter isn't needed; screens that want one (like Jobs'
  /// existing "this can take a moment (Ns)" copy) can rebuild this widget
  /// with an updated string instead of this class owning that ticker too.
  final String? slowConnectionLabel;
  final Duration slowConnectionThreshold;

  static const _ceiling = 0.92;
  static const _tickInterval = Duration(milliseconds: 120);

  @override
  State<AppLoadingProgressBar> createState() => _AppLoadingProgressBarState();
}

class _AppLoadingProgressBarState extends State<AppLoadingProgressBar> {
  double _progress = 0;
  bool _isSlow = false;
  Timer? _ticker;
  Timer? _slowTimer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (prefersReducedMotion(context)) {
      // No continuous easing under reduce-motion -- jump straight to the
      // ceiling once. Still communicates "this is genuinely working" (the
      // whole reason this widget exists over a bare spinner), just without
      // the ~8s of continuous smooth motion a full ease-in would otherwise
      // produce -- this is authored, decorative easing, not a real
      // determinate progress signal, so it doesn't get the usual "real
      // progress indicators are exempt from reduce-motion" pass.
      setState(() => _progress = AppLoadingProgressBar._ceiling);
    } else {
      _ticker = Timer.periodic(AppLoadingProgressBar._tickInterval, (_) {
        if (!mounted) return;
        setState(() {
          // Exponential ease toward the ceiling: fast while far from it,
          // slowing as it approaches -- the standard perceived-progress
          // curve, not a straight ramp that would either finish too early
          // (looks fake) or crawl the whole time (looks stuck).
          _progress += (AppLoadingProgressBar._ceiling - _progress) * 0.06;
        });
      });
    }
    if (widget.slowConnectionLabel != null) {
      _slowTimer = Timer(widget.slowConnectionThreshold, () {
        if (mounted) setState(() => _isSlow = true);
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _slowTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = _isSlow ? widget.slowConnectionLabel! : widget.label;
    final percent = (_progress * 100).round();
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: label,
      value: widget.showPercent ? '$percent percent' : null,
      liveRegion: true,
      child: widget.showPercent
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    '$percent%',
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: _progress,
                          minHeight: 5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
    );
  }
}
