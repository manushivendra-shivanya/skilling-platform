import 'dart:async';

import 'package:flutter/material.dart';

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
class AppLoadingProgressBar extends StatefulWidget {
  const AppLoadingProgressBar({
    required this.label,
    this.slowConnectionLabel,
    this.slowConnectionThreshold = const Duration(seconds: 4),
    super.key,
  });

  final String label;

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

  @override
  void initState() {
    super.initState();
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
    return Semantics(
      label: label,
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: _progress, minHeight: 3),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
